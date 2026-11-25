defmodule Riddler.Screens.UpgradeTest do
  use ExUnit.Case, async: true

  alias Riddler.Corpus
  alias Riddler.Screens
  alias Riddler.Screens.Document
  alias Riddler.Screens.Upgrade

  @after_name "A version 2 document resolves to what its version 1 form resolves to, keeping the version it declared"
  @before_name "A version 1 document, the before of the upgrade pair whose after is the version 2 case below, resolves to the same screens, keeping the version it declared"

  defp corpus_case(path, name), do: Enum.find(Corpus.cases(path), &(&1["name"] == name))

  # Patron registration in its version 1 form, a leaf carrying a `nodes` that
  # admission drops beside the screen's and the variant's that it reads.
  defp version_one do
    %{
      "id" => "patron_registration",
      "metadata" => %{"name" => "Patron registration", "nodes" => "the host's own"},
      "screens" => [
        %{
          "key" => "patron_details",
          "title" => "Get your library card",
          "nodes" => [
            %{
              "type" => "text",
              "key" => "welcome",
              "text" => "Welcome.",
              "nodes" => [%{"type" => "text", "key" => "dropped", "text" => "Never read."}]
            },
            %{
              "type" => "variant",
              "key" => "card_notice",
              "nodes" => [
                %{
                  "type" => "variant",
                  "key" => "card_notice_inner",
                  "condition" => "context.age < 13",
                  "nodes" => [
                    %{
                      "type" => "text",
                      "key" => "card_notice_child",
                      "text" => "A guardian signs."
                    }
                  ]
                },
                %{"type" => "text", "key" => "card_notice_adult", "text" => "Ready today."}
              ]
            },
            %{
              "type" => "choice_question",
              "key" => "branch",
              "label" => "Your branch",
              "select" => "one",
              "answer_options" => [%{"value" => "central", "label" => "Central"}]
            }
          ]
        }
      ]
    }
  end

  describe "upgrade/1 over the corpus pair" do
    # Sabotage: left the variant's `nodes` unrenamed in `rename_container/1`
    # (no container rule); the upgraded document still spelled the variant's
    # candidates `nodes` and this test went red.
    test "the version 1 case upgrades to the version 2 case, and both resolve alike" do
      before_case = corpus_case("corpus/screens/resolve.json", @before_name)
      after_case = corpus_case("corpus/screens/resolve.json", @after_name)

      assert {:ok, after_document} = Screens.upgrade(before_case["input"]["document"])
      assert after_document == after_case["input"]["document"]

      assert Map.put(before_case["expected"], "schema_version", 2) == after_case["expected"]
    end
  end

  describe "upgrade/1 rewrites the key and the version" do
    # Sabotage: wrote `schema_version` 1 back instead of 2; this went red.
    test "an absent version is version 1 and is written 2" do
      assert {:ok, %{"schema_version" => 2}} = Screens.upgrade(version_one())
    end

    # Sabotage: dropped 1 from the version 1 clause of `by_version/2`, so a
    # version 1 written 1.0, admitted as 1, was unsupported; this went red.
    test "a version 1 written 1.0 is upgraded" do
      assert {:ok, %{"schema_version" => 2}} =
               Screens.upgrade(Map.put(version_one(), "schema_version", 1.0))
    end

    # Sabotage: renamed `nodes` on every element, the leaf's included; the
    # leaf's `nodes` came back as `elements` and this test went red.
    test "only a screen's and a variant's nodes are renamed, at every depth, and nothing else changes" do
      {:ok, upgraded} = Screens.upgrade(version_one())

      [screen] = upgraded["screens"]
      [welcome, notice, branch] = screen["elements"]
      [inner, adult] = notice["elements"]

      refute Map.has_key?(screen, "nodes")
      assert welcome == hd(hd(version_one()["screens"])["nodes"])
      assert Map.keys(notice) == ["elements", "key", "type"]

      original_inner =
        get_in(version_one(), [
          "screens",
          Access.at(0),
          "nodes",
          Access.at(1),
          "nodes",
          Access.at(0)
        ])

      assert inner ==
               original_inner
               |> Map.delete("nodes")
               |> Map.put("elements", original_inner["nodes"])

      assert adult["key"] == "card_notice_adult"
      assert branch == List.last(hd(version_one()["screens"])["nodes"])
      assert upgraded["metadata"] == version_one()["metadata"]

      assert Map.delete(upgraded, "screens") ==
               Map.put(Map.delete(version_one(), "screens"), "schema_version", 2)
    end

    # Sabotage: made `container?/1` answer true for a type the registry does
    # not know; its `nodes` came back renamed and this went red.
    test "a version 1 document with findings of its own is upgraded and keeps them" do
      unknown = %{"type" => "carousel", "key" => "pictures", "nodes" => []}
      document = update_in(version_one(), ["screens", Access.at(0), "nodes"], &(&1 ++ [unknown]))

      {:ok, upgraded} = Screens.upgrade(document)

      assert List.last(hd(upgraded["screens"])["elements"]) == unknown
      assert findings(document) == findings(upgraded)
      assert [%{code: "document.unknown_type"}] = findings(upgraded)
    end

    # Sabotage: sent a version 2 document through the rewrite as version 1 is;
    # the document spelling `nodes` came back renamed and this went red.
    test "a version 2 document is answered unchanged, whatever it spells" do
      {:ok, upgraded} = Screens.upgrade(version_one())
      assert Screens.upgrade(upgraded) == {:ok, upgraded}

      spelled_nodes = Map.put(version_one(), "schema_version", 2)
      assert Screens.upgrade(spelled_nodes) == {:ok, spelled_nodes}
    end
  end

  describe "upgrade/1 refuses" do
    # Sabotage: answered `{:ok, raw}` where admission answers nil; this went
    # red.
    test "a document admission answers nil for" do
      assert Screens.upgrade("not a document") == {:error, :not_a_document}
      assert Screens.upgrade(%{"screens" => [%{"key" => "a"}]}) == {:error, :not_a_document}

      assert Screens.upgrade(%{"schema_version" => 2, "screens" => "three"}) ==
               {:error, :not_a_document}
    end

    # Sabotage: made `carries_elements?/1` read only the map's own key, not
    # what is under its `nodes`; the variant and the leaf cases went red.
    test "a version 1 document carrying elements on a screen, a variant or any element" do
      on_screen = put_in(version_one(), ["screens", Access.at(0), "elements"], [])

      on_variant =
        put_in(version_one(), ["screens", Access.at(0), "nodes", Access.at(1), "elements"], [])

      on_leaf =
        put_in(version_one(), ["screens", Access.at(0), "nodes", Access.at(0), "elements"], "x")

      under_leaf =
        put_in(
          version_one(),
          ["screens", Access.at(0), "nodes", Access.at(0), "nodes", Access.at(0), "elements"],
          "x"
        )

      for document <- [on_screen, on_variant, on_leaf, under_leaf] do
        assert Document.admit(document)
        assert Screens.upgrade(document) == {:error, :other_version_spelling}
      end
    end

    # Sabotage: answered every version but 1 and 2 through the rename; version
    # 3 came back rewritten and this went red.
    test "a document of a version neither 1 nor 2" do
      document = Map.put(version_one(), "schema_version", 3)
      assert Document.admit(document)
      assert Screens.upgrade(document) == {:error, :unsupported_version}
    end
  end

  describe "the upgraded document admits as its version 1 form did" do
    # Sabotage: dropped the container rule from `rename_container/1`, so a
    # variant's `nodes` stayed unrenamed; the upgraded variants were admitted
    # without their candidates and this went red. The property is over every
    # version 1 document the corpus admits.
    test "over every version 1 document in the corpus, admitted and validated alike, and the upgrade is idempotent" do
      documents =
        for path <- Corpus.case_files(),
            one <- Corpus.cases(path),
            document = get_in(one, ["input", "document"]),
            is_map(document),
            match?({:ok, _}, Screens.upgrade(document)),
            Map.get(document, "schema_version") in [nil, 1, 1.0],
            do: document

      assert length(documents) > 100

      for document <- documents do
        {:ok, upgraded} = Screens.upgrade(document)
        assert Screens.upgrade(upgraded) == {:ok, upgraded}

        original = Document.admit(document)
        assert Document.admit(upgraded) == %{original | schema_version: 2}
        assert findings(upgraded) == Enum.map(findings(document), &respelled/1)
      end
    end
  end

  describe "rewrite_text/1" do
    @text """
    {
      "id": "patron_registration",
      "screens": [
        {
          "key": "patron_details",
          "title": "Get your library card",
          "nodes": [
            {"type": "text", "key": "welcome", "text": "Welcome.", "nodes": []},
            {"type": "variant", "key": "card_notice", "nodes": [
              {"type": "text", "key": "card_notice_adult", "text": "Ready today."}
            ]}
          ]
        }
      ]
    }
    """

    # Sabotage: inserted the version with no indent of its own; the inserted
    # line no longer matched the first key's and this went red.
    test "edits the key and the version in place and leaves every other byte" do
      assert {:ok, text} = Upgrade.rewrite_text(@text)

      expected =
        @text
        |> String.replace(~s({\n  "id"), ~s({\n  "schema_version": 2,\n  "id"))
        |> String.replace(~s("nodes": [\n        {"type"), ~s("elements": [\n        {"type"))
        |> String.replace(~s("nodes": [\n          {"type"), ~s("elements": [\n          {"type"))

      assert text == expected
      assert {:ok, JSON.decode!(text)} == Screens.upgrade(JSON.decode!(@text))
    end

    # Sabotage: wrote a declared version's span as `2` and a trailing space;
    # the text was no longer the expected bytes and this went red.
    test "replaces a declared version, compact or escaped, and answers a version 2 text as written" do
      compact =
        ~s({"schema_version":1.0,"screens":[{"key":"a","title":"A","node\\u0073":[]}]})

      assert {:ok, upgraded} = Upgrade.rewrite_text(compact)

      assert upgraded ==
               ~s({"schema_version":2,"screens":[{"key":"a","title":"A","elements":[]}]})

      assert Upgrade.rewrite_text(upgraded) == {:ok, upgraded}

      absent = ~s({"screens":[{"key":"a","title":"A","nodes":[]}]})

      assert {:ok, ~s({"schema_version":2,"screens":[{"key":"a","title":"A","elements":[]}]})} =
               Upgrade.rewrite_text(absent)
    end

    # Sabotage: answered a JSON decode error as `:not_a_document`; this went
    # red.
    test "refuses text that is not JSON, and passes the document's refusals through" do
      assert Upgrade.rewrite_text("{") == {:error, :not_json}
      assert Upgrade.rewrite_text(~s({"screens": 3})) == {:error, :not_a_document}

      assert Upgrade.rewrite_text(~s({"schema_version": 3, "screens": []})) ==
               {:error, :unsupported_version}
    end
  end

  # A finding naming the children's key names the key its version spells, so
  # a version 1 finding on `nodes` is the version 2 finding on `elements`.
  defp respelled(%{field: "nodes"} = finding), do: %{finding | field: "elements"}
  defp respelled(finding), do: finding

  defp findings(raw) do
    case Document.validate(Document.admit(raw)) do
      {:ok, _document} -> []
      {:error, findings} -> findings
    end
  end
end
