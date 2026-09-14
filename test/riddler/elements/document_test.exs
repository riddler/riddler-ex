defmodule Riddler.Elements.DocumentTest do
  use ExUnit.Case, async: true

  doctest Riddler.Elements.Document
  doctest Riddler.Elements.Registry
  doctest Riddler.Elements.Type.Button
  doctest Riddler.Elements.Type.Heading
  doctest Riddler.Elements.Type.Text
  doctest Riddler.Elements.Type.TextQuestion
  doctest Riddler.Elements.Type.Variant

  alias Riddler.Elements.Document

  # test/fixtures/signup_screens.json is a verbatim copy of
  # priv/fixtures/signup_screens.json in the statifier_examples repository,
  # read at 9d288c9. It is the signup wizard a host already authors by hand,
  # and it is the worked case the element document has to admit.
  @fixture "test/fixtures/signup_screens.json"

  defp fixture_json, do: @fixture |> File.read!() |> Jason.decode!()

  defp screen(nodes, overrides \\ %{}) do
    Map.merge(
      %{"key" => "account", "title" => "Create your account", "nodes" => nodes},
      overrides
    )
  end

  defp document(nodes, overrides \\ %{}) do
    %{
      "schema_version" => 1,
      "id" => "edoc_signup_screens",
      "screens" => [screen(nodes, overrides)]
    }
  end

  defp findings(raw) do
    {:error, findings} = raw |> Document.admit() |> Document.validate()
    findings
  end

  defp codes(raw), do: raw |> findings() |> Enum.map(& &1.code)

  # The counting rule, applied to the raw JSON and to the admitted struct so
  # that the two can be compared. A leaf field is: each of the two envelope
  # fields the document carries, each entry of `metadata`, each screen's
  # `key` and `title`, and each field of each node - with a `writes` map
  # contributing one leaf per entry rather than one for the map.
  defp raw_leaves(raw) do
    envelope = Enum.count(["schema_version", "id"], &Map.has_key?(raw, &1))
    metadata = map_size(Map.get(raw, "metadata", %{}))

    screens =
      Enum.sum_by(raw["screens"], fn screen ->
        2 + Enum.sum_by(screen["nodes"], &raw_node_leaves/1)
      end)

    envelope + metadata + screens
  end

  defp raw_node_leaves(node) do
    Enum.sum_by(Map.to_list(node), fn
      {"writes", writes} -> map_size(writes)
      {"nodes", candidates} -> Enum.sum_by(candidates, &raw_node_leaves/1)
      {_field, _value} -> 1
    end)
  end

  defp struct_leaves(%Document{} = document) do
    envelope = Enum.count([document.schema_version, document.id], &(&1 != nil))
    metadata = map_size(document.metadata)

    screens =
      Enum.sum_by(document.screens, fn screen ->
        2 + Enum.sum_by(screen.nodes, &struct_node_leaves/1)
      end)

    envelope + metadata + screens
  end

  defp struct_node_leaves(node) do
    Enum.sum_by(Map.to_list(node), fn
      {:writes, writes} -> map_size(writes)
      {:nodes, candidates} -> Enum.sum_by(candidates, &struct_node_leaves/1)
      {_field, _value} -> 1
    end)
  end

  describe "the signup wizard fixture" do
    # Sabotage: make `validate/1` return `{:error, findings}` unconditionally
    # (drop the `[] -> {:ok, document}` clause) and this goes red.
    test "admits and validates with zero findings" do
      document = Document.admit(fixture_json())

      assert %Document{schema_version: 1, id: "edoc_signup_screens"} = document
      assert {:ok, ^document} = Document.validate(document)
    end

    # Sabotage: drop `:condition` from the document's common fields and the
    # admitted struct loses six leaves, so the two counts stop agreeing.
    test "round-trips 91 leaf fields: envelope, metadata entries, each screen key and title, each node field, one leaf per writes entry" do
      raw = fixture_json()
      document = Document.admit(raw)

      assert raw_leaves(raw) == 91
      assert struct_leaves(document) == 91
    end

    # Sabotage: return the accumulator unreversed from `admit_each/2` and the
    # screens and nodes come back in reverse order.
    test "keeps every screen and node, in order, with its key" do
      raw = fixture_json()
      document = Document.admit(raw)

      assert Enum.map(document.screens, & &1.key) == ["account", "plan", "confirm"]

      assert Enum.map(document.screens, fn screen -> Enum.map(screen.nodes, & &1.key) end) ==
               Enum.map(raw["screens"], fn screen ->
                 Enum.map(screen["nodes"], & &1["key"])
               end)
    end
  end

  describe "admit/1" do
    # Sabotage: remove the `admit(_raw), do: nil` catch-all and admitting a
    # binary raises instead of answering nil.
    test "answers nil for anything that is not an element document" do
      assert Document.admit(nil) == nil
      assert Document.admit("not a document") == nil
      assert Document.admit([%{"key" => "account"}]) == nil
      assert Document.admit(%{}) == nil
      assert Document.admit(%{"screens" => "three of them"}) == nil
      assert Document.admit(%{"screens" => ["account"]}) == nil
      assert Document.admit(%{"screens" => [%{"key" => "account"}]}) == nil
      assert Document.admit(%{"screens" => [%{"nodes" => ["a heading"]}]}) == nil
      assert Document.admit(%{"screens" => [], "metadata" => "signup"}) == nil

      assert Document.admit(document([%{"type" => "variant", "key" => "v", "nodes" => "two"}])) ==
               nil
    end

    # Sabotage: admit the type-declared fields under their string keys and the
    # struct's atom-keyed reads go nil.
    test "builds an atom-keyed struct from the string-keyed decoded map, keeping metadata open" do
      document =
        Document.admit(%{
          "schema_version" => 1,
          "id" => "edoc_signup_screens",
          "metadata" => %{"name" => "Signup screens", "tenant" => "acme"},
          "screens" => [
            screen([
              %{"type" => "heading", "key" => "account_heading", "level" => 1, "text" => "Hi"}
            ])
          ]
        })

      assert document.metadata == %{"name" => "Signup screens", "tenant" => "acme"}
      assert [%{key: "account", title: "Create your account", nodes: [node]}] = document.screens
      assert node == %{type: "heading", key: "account_heading", level: 1, text: "Hi"}
    end

    # Sabotage: add `:colour` to the text type's optional fields and the
    # unknown field is carried onto the admitted node.
    test "does not carry a field this version does not know" do
      document =
        Document.admit(
          document([
            %{"type" => "text", "key" => "account_intro", "text" => "Hello", "colour" => "red"}
          ])
        )

      assert [%{nodes: [node]}] = document.screens
      assert node == %{type: "text", key: "account_intro", text: "Hello"}
    end

    # Sabotage: stop recursing into a variant's candidates and the inner node
    # keeps its string keys.
    test "admits a variant's candidates as nodes" do
      document =
        Document.admit(
          document([
            %{
              "type" => "variant",
              "key" => "account_notice",
              "nodes" => [
                %{"type" => "text", "key" => "account_notice_default", "text" => "Welcome"}
              ]
            }
          ])
        )

      assert [%{nodes: [variant]}] = document.screens
      assert variant.nodes == [%{type: "text", key: "account_notice_default", text: "Welcome"}]
    end
  end

  describe "validate/1 refuses" do
    # Sabotage: make `Registry.fetch/1` answer `{:ok, Type.Text}` for an
    # unknown name and the unknown type is silently admitted.
    test "a type the registry does not know" do
      [finding] = findings(document([%{"type" => "carousel", "key" => "pictures"}]))

      assert finding.code == "document.unknown_type"
      assert finding.field == "type"
      assert finding.node_key == "pictures"
      assert finding.message =~ "carousel"
    end

    # Sabotage: report only keys used more than twice and the key used twice,
    # once on each screen, goes unreported.
    test "a key used twice anywhere in the document" do
      raw = %{
        "screens" => [
          screen([%{"type" => "text", "key" => "intro", "text" => "One"}]),
          screen([%{"type" => "text", "key" => "intro", "text" => "Two"}], %{"key" => "plan"})
        ]
      }

      [finding] = findings(raw)

      assert finding.code == "document.duplicate_key"
      assert finding.node_key == "intro"
      assert finding.message =~ "2 times"
    end

    # Sabotage: widen the key shape to `[a-zA-Z0-9_]+` and the camel-cased key
    # is admitted.
    test "a key that is missing or not lower snake case" do
      assert ["document.invalid_key"] =
               codes(document([%{"type" => "text", "key" => "AccountIntro", "text" => "Hi"}]))

      assert ["document.invalid_key"] =
               codes(document([%{"type" => "text", "key" => "_intro", "text" => "Hi"}]))

      assert ["document.invalid_key"] =
               codes(document([%{"type" => "text", "key" => "intro-1", "text" => "Hi"}]))

      [missing] = findings(document([%{"type" => "text", "text" => "Hi"}]))
      assert missing.code == "document.invalid_key"
      assert missing.node_key == nil
    end

    # Sabotage: return `[]` from `missing_findings/3` and a button with no
    # outcome is admitted.
    test "a field the node's type requires" do
      [finding] =
        findings(document([%{"type" => "button", "key" => "account_continue", "label" => "Go"}]))

      assert finding.code == "document.missing_field"
      assert finding.field == "outcome"
      assert finding.node_key == "account_continue"
    end

    # Sabotage: widen the heading level guard to `level >= 1` and a level of 9
    # is admitted.
    test "a heading level outside 1 to 6" do
      [finding] =
        findings(
          document([
            %{"type" => "heading", "key" => "account_heading", "level" => 9, "text" => "Hi"}
          ])
        )

      assert finding.code == "document.level_out_of_range"
      assert finding.field == "level"
      assert finding.node_key == "account_heading"
    end

    # Sabotage: treat `Predicator.compile/1`'s `{:error, _}` as success and a
    # condition that does not parse is admitted.
    test "a condition that does not parse" do
      [finding] =
        findings(
          document([
            %{
              "type" => "text",
              "key" => "account_greeting",
              "condition" => "responses.first_name &&& ",
              "text" => "Hi"
            }
          ])
        )

      assert finding.code == "document.invalid_condition"
      assert finding.field == "condition"
      assert finding.node_key == "account_greeting"
      assert finding.message =~ "does not parse"
    end

    # Sabotage: drop `:label` from the document's template fields and a label
    # holding a refused construct compiles as literal text.
    test "a template field holding a construct outside the subset" do
      [finding] =
        findings(
          document([
            %{
              "type" => "text_question",
              "key" => "first_name",
              "label" => "{% include 'footer' %}"
            }
          ])
        )

      assert finding.code == "document.invalid_template"
      assert finding.field == "include"
      assert finding.node_key == "first_name"
      assert finding.message =~ "the label template is refused"
    end

    # Sabotage: drop the `responses.` anchor from the write path and a write
    # addressing a bare `plan` is admitted.
    test "a write that does not address a response or is not the constant form" do
      assert ["document.invalid_writes"] =
               codes(
                 document([
                   %{
                     "type" => "button",
                     "key" => "plan_business",
                     "label" => "Go",
                     "outcome" => "business_chosen",
                     "writes" => %{"plan" => ["const", "business"]}
                   }
                 ])
               )

      [finding] =
        findings(
          document([
            %{
              "type" => "button",
              "key" => "plan_business",
              "label" => "Go",
              "outcome" => "business_chosen",
              "writes" => %{"responses.plan" => "business"}
            }
          ])
        )

      assert finding.code == "document.invalid_writes"
      assert finding.field == "writes"
      assert finding.node_key == "plan_business"
    end

    # Sabotage: drop the membership check in `TextQuestion.validate/1` and a
    # misspelled format is admitted.
    test "a format name the package does not know" do
      [finding] =
        findings(
          document([
            %{
              "type" => "text_question",
              "key" => "email",
              "label" => "Work email",
              "format" => "e-mail"
            }
          ])
        )

      assert finding.code == "document.unknown_format"
      assert finding.field == "format"
      assert finding.node_key == "email"
    end

    # Sabotage: treat `{:ok, []}` as a variant with candidates and an empty
    # container is admitted.
    test "a variant with no candidates" do
      [finding] = findings(document([%{"type" => "variant", "key" => "notice", "nodes" => []}]))

      assert finding.code == "document.empty_variant"
      assert finding.field == "nodes"
      assert finding.node_key == "notice"
    end

    # Sabotage: drop the FIRST candidate instead of the last before the
    # unconditional check and the buried default goes unreported.
    test "an unconditional variant candidate that is not last" do
      [finding] =
        findings(
          document([
            %{
              "type" => "variant",
              "key" => "notice",
              "nodes" => [
                %{
                  "type" => "text",
                  "key" => "notice_default",
                  "text" => "We will charge the card on file."
                },
                %{
                  "type" => "text",
                  "key" => "notice_declined",
                  "condition" => "context.last_charge_status == 'declined'",
                  "text" => "Try another card."
                }
              ]
            }
          ])
        )

      assert finding.code == "document.unreachable_variant_candidate"
      assert finding.node_key == "notice"
      assert finding.message =~ "notice_default"
    end

    # Sabotage: stop recursing into a variant's candidates in
    # `node_findings/1` and a broken candidate is never checked.
    test "a candidate inside a variant, on the candidate's own key" do
      [finding] =
        findings(
          document([
            %{
              "type" => "variant",
              "key" => "notice",
              "nodes" => [
                %{"type" => "heading", "key" => "notice_default", "level" => 9, "text" => "Hi"}
              ]
            }
          ])
        )

      assert finding.code == "document.level_out_of_range"
      assert finding.node_key == "notice_default"
    end

    # Sabotage: return only the first finding and the second reason is lost.
    test "and reports every reason at once" do
      codes =
        codes(
          document([
            %{"type" => "heading", "key" => "Account_Heading", "level" => 9, "text" => "Hi"}
          ])
        )

      assert "document.invalid_key" in codes
      assert "document.level_out_of_range" in codes
    end
  end
end
