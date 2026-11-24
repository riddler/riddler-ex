defmodule Riddler.Screens.SchemaVersionTwoTest do
  use ExUnit.Case, async: true

  alias Riddler.Screens
  alias Riddler.Screens.Document

  # Patron registration, the document of the record's worked examples, in its
  # version 2 form: the screen's and the variant's children under `elements`.
  defp version_two do
    %{
      "schema_version" => 2,
      "id" => "patron_registration",
      "screens" => [
        %{
          "key" => "patron_details",
          "title" => "Get your library card",
          "elements" => [
            %{
              "type" => "text",
              "key" => "welcome_back",
              "condition" => "context.returning == 'yes'",
              "text" => "Welcome back, {{ context.first_name }}."
            },
            %{
              "type" => "variant",
              "key" => "card_notice",
              "elements" => [
                %{
                  "type" => "text",
                  "key" => "card_notice_child",
                  "condition" => "context.age < 13",
                  "text" => "A parent or guardian signs for a child card."
                },
                %{
                  "type" => "text",
                  "key" => "card_notice_adult",
                  "text" => "Your card is ready the same day."
                }
              ]
            },
            %{
              "type" => "button",
              "key" => "details_next",
              "label" => "Continue",
              "outcome" => "details_submitted"
            }
          ]
        }
      ]
    }
  end

  # The same document's version 1 form: the version, and both keys spelled
  # `nodes`.
  defp version_one do
    version_two()
    |> Map.put("schema_version", 1)
    |> update_variant(&respell(&1, "elements", "nodes"))
    |> update_screen(&respell(&1, "elements", "nodes"))
  end

  defp update_screen(document, fun), do: Map.update!(document, "screens", &Enum.map(&1, fun))

  defp update_variant(document, fun) do
    update_screen(document, fn screen ->
      key = if Map.has_key?(screen, "elements"), do: "elements", else: "nodes"
      Map.update!(screen, key, &Enum.map(&1, fn element -> variant_only(element, fun) end))
    end)
  end

  defp variant_only(%{"type" => "variant"} = variant, fun), do: fun.(variant)
  defp variant_only(element, _fun), do: element

  defp respell(map, from, to) do
    {value, map} = Map.pop(map, from)
    Map.put(map, to, value)
  end

  defp root, do: %{"context" => %{"returning" => "yes", "first_name" => "Ada", "age" => 34}}

  describe "a version 2 document" do
    # Sabotage: made `spelling/2` answer version 1's spelling for version 2;
    # the screen's children were read from its absent nodes key, it came back
    # with no elements and refused for carrying elements, and this went red.
    test "is admitted with its screen's and its variant's children as elements" do
      document = Document.admit(version_two())

      assert %Document{schema_version: 2, screens: [screen]} = document
      assert {:ok, ^document} = Document.validate(document)

      assert Enum.map(screen.elements, & &1.key) == [
               "welcome_back",
               "card_notice",
               "details_next"
             ]

      assert [_variant = %{elements: [_child, _adult]}] =
               Enum.filter(screen.elements, &(&1.type == "variant"))
    end

    # The pin for the one-spelling rule. Mutation: let admission read either
    # spelling for version 2 (`spelled/2` reading the other version's key
    # where its own is absent, and `refused/2` refusing nothing); the nodes
    # were admitted as the screen's elements with no finding, and this went
    # red.
    test "that spells a screen's children nodes is refused by name, and nothing under nodes is read" do
      raw =
        update_screen(version_two(), fn screen ->
          screen
          |> respell("elements", "nodes")
          |> Map.update!("nodes", &[%{"type" => "carousel", "key" => "Pictures"} | &1])
        end)

      document = Document.admit(raw)

      assert %Document{screens: [%{elements: []}]} = document
      assert {:error, [finding]} = Document.validate(document)
      assert finding.code == "document.other_version_spelling"
      assert finding.field == "nodes"
      assert finding.element_key == "patron_details"
      assert finding.message =~ ~s("elements")
    end

    # Sabotage: dropped the `refused?/2` filter from `missing_findings/3`; the
    # variant raised document.missing_field on elements beside the refusal and
    # this went red.
    test "whose variant spells its candidates nodes raises that finding alone" do
      raw = update_variant(version_two(), &respell(&1, "elements", "nodes"))

      assert {:error, [finding]} = raw |> Document.admit() |> Document.validate()
      assert finding.code == "document.other_version_spelling"
      assert finding.field == "nodes"
      assert finding.element_key == "card_notice"
    end

    # Sabotage: made `admit_screen/2` refuse nothing where the screen carries
    # its own version's key; the screen carrying both keys validated clean and
    # this went red.
    test "that carries nodes beside elements is refused by name, its elements admitted" do
      raw = update_screen(version_two(), &Map.put(&1, "nodes", []))
      document = Document.admit(raw)

      assert [%{elements: [_, _, _]}] = document.screens
      assert {:error, [finding]} = Document.validate(document)
      assert {finding.code, finding.field} == {"document.other_version_spelling", "nodes"}
    end

    # Sabotage: dropped `spelled_fields/2` from the variant's own findings; the
    # empty variant's field came back as elements in the version 1 document
    # and this went red.
    test "names elements in a variant's findings where version 1 names nodes" do
      empty_two = update_variant(version_two(), &Map.put(&1, "elements", []))
      empty_one = update_variant(version_one(), &Map.put(&1, "nodes", []))

      assert [%{code: "document.empty_variant", field: "elements"}] =
               empty_two |> Document.admit() |> Document.validate() |> elem(1)

      assert [%{code: "document.empty_variant", field: "nodes"}] =
               empty_one |> Document.admit() |> Document.validate() |> elem(1)
    end

    # Sabotage: made `unread_nodes/2` hold nothing to its shape; a version 2
    # leaf's elements that was not a list was admitted and this went red.
    test "drops either key on an element whose type has no candidates, once each holds a list" do
      lists = %{"elements" => [], "nodes" => []}

      raw =
        update_screen(version_two(), fn s ->
          Map.update!(s, "elements", fn [h | t] -> [Map.merge(h, lists) | t] end)
        end)

      document = Document.admit(raw)

      assert {:ok, ^document} = Document.validate(document)
      refute Map.has_key?(hd(hd(document.screens).elements), :elements)

      for key <- ["elements", "nodes"] do
        bad =
          update_screen(version_two(), fn s ->
            Map.update!(s, "elements", fn [h | t] -> [Map.put(h, key, "x") | t] end)
          end)

        assert Document.admit(bad) == nil, key
      end
    end

    # Sabotage: removed the `Map.delete/2` of the refusal mark from
    # `resolve_leaf/4`; the variant resolved as a leaf carrying the mark and
    # this went red.
    test "resolves a variant refused for its key without carrying the refusal" do
      raw = update_variant(version_two(), &respell(&1, "elements", "nodes"))
      {:ok, resolved} = Screens.resolve(Document.admit(raw), root())

      assert [%{elements: elements}] = resolved.screens
      variant = Enum.find(elements, &(&1.key == "card_notice"))
      assert variant == %{type: "variant", key: "card_notice"}
    end
  end

  describe "a version 1 document" do
    # Sabotage: made `refused/2` answer nil for version 1; the screen carrying
    # elements was not a document and this went red.
    test "that spells a screen's children elements is refused by name" do
      raw = update_screen(version_one(), &respell(&1, "nodes", "elements"))

      assert %Document{screens: [%{elements: []}]} = document = Document.admit(raw)
      assert {:error, [finding]} = Document.validate(document)
      assert finding.code == "document.other_version_spelling"
      assert finding.field == "elements"
      assert finding.element_key == "patron_details"
    end

    # Sabotage: made `spelling(nil)` answer version 2's spelling; the document
    # declaring no version was refused for its nodes and this went red.
    test "that declares no version is version 1, and is admitted as its version 2 form is" do
      unversioned = Map.delete(version_one(), "schema_version")

      one = Document.admit(unversioned)
      two = Document.admit(version_two())

      assert {:ok, _} = Document.validate(one)
      assert %{one | schema_version: 2} == two

      assert {:ok, resolved_one} = Screens.resolve(one, root())
      assert {:ok, resolved_two} = Screens.resolve(two, root())
      assert resolved_one.screens == resolved_two.screens
    end

    # riddler 0.7.0 admitted this document and found nothing wrong with it:
    # on an element whose type has no candidates, `elements` was a field the
    # type does not name, of any value. Version 1 still reads it so.
    #
    # Sabotage: made `held?/3` hold an element's `elements` to its shape at
    # every version; the leaf's string was refused and this went red.
    test "drops elements of any value on an element whose type has no candidates, unread" do
      raw =
        update_screen(version_one(), fn screen ->
          Map.update!(screen, "nodes", fn [h | t] -> [Map.put(h, "elements", "x") | t] end)
        end)

      assert %Document{} = document = Document.admit(raw)
      assert {:ok, ^document} = Document.validate(document)
      refute Map.has_key?(hd(hd(document.screens).elements), :elements)
    end
  end

  describe "a version this package does not implement" do
    # Sabotage: made `refused/2` refuse the other key whatever the version, so
    # an unknown version refused the key it did not read its children from;
    # the version 3 screen carrying both keys raised the spelling finding
    # beside the version's and this went red.
    test "raises its version finding alone, in either form and with both keys" do
      both = update_screen(version_two(), &Map.put(&1, "nodes", []))

      for raw <- [version_two(), version_one(), both] do
        raw = Map.put(raw, "schema_version", 3)

        assert %Document{} = document = Document.admit(raw)
        assert {:error, [finding]} = Document.validate(document)
        assert {finding.code, finding.element_key} == {"document.invalid_schema_version", nil}
      end
    end

    # riddler 0.7.0 named an empty variant's field `nodes` whatever the
    # version, and a document at a version it does not implement still does.
    #
    # Sabotage: made `own_spelling/1` name `elements` for an unknown version;
    # the field came back elements and this went red.
    test "names an empty variant's field nodes, as before" do
      raw =
        version_one() |> Map.put("schema_version", 3) |> update_variant(&Map.put(&1, "nodes", []))

      assert %Document{} = document = Document.admit(raw)
      assert {:error, [version, empty]} = Document.validate(document)
      assert version.code == "document.invalid_schema_version"
      assert {empty.code, empty.field} == {"document.empty_variant", "nodes"}
    end

    # A document spelled with nodes is read from nodes, as riddler 0.7.0 read
    # it, so a variant carrying only elements is missing its nodes.
    #
    # Sabotage: made `spelling/2` read every unknown version from elements;
    # the variant's elements were read as its candidates, the missing field
    # was not raised, and this went red.
    test "reads a document spelled with nodes from nodes, a variant's elements unread" do
      raw =
        version_one()
        |> Map.put("schema_version", 3)
        |> update_variant(&respell(&1, "nodes", "elements"))

      assert %Document{} = document = Document.admit(raw)
      assert {:error, [version, missing]} = Document.validate(document)
      assert version.code == "document.invalid_schema_version"

      assert {missing.code, missing.field, missing.element_key} ==
               {"document.missing_field", "nodes", "card_notice"}
    end

    # Sabotage: made `held?/3` hold a screen's `elements` to its shape at
    # every version; the version 3 screen's string was refused and this went
    # red.
    test "reads a screen carrying nodes and elements from nodes, elements unread" do
      raw =
        version_one()
        |> Map.put("schema_version", 3)
        |> update_screen(&Map.put(&1, "elements", "x"))

      assert %Document{screens: [screen]} = document = Document.admit(raw)

      assert Enum.map(screen.elements, & &1.key) == [
               "welcome_back",
               "card_notice",
               "details_next"
             ]

      assert {:error, [%{code: "document.invalid_schema_version"}]} = Document.validate(document)
    end
  end
end
