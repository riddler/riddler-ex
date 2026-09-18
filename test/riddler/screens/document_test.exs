defmodule Riddler.Screens.DocumentTest do
  use ExUnit.Case, async: true

  doctest Riddler.Screens.Document
  doctest Riddler.Screens.Registry
  doctest Riddler.Screens.Type.Button
  doctest Riddler.Screens.Type.Heading
  doctest Riddler.Screens.Type.Text
  doctest Riddler.Screens.Type.TextQuestion
  doctest Riddler.Screens.Type.Variant

  alias Riddler.Screens.Document

  # test/fixtures/signup_screens.json is a verbatim copy of
  # priv/fixtures/signup_screens.json in the statifier_examples repository,
  # read at 9d288c9. It is the signup wizard a host already authors by hand,
  # and it is the worked case the screen document has to admit.
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
  # contributing one leaf per entry rather than one for the map. The
  # envelope's `kind` is decided rather than carried - it defaults to
  # "screens" when the document omits it - so it is a leaf on neither side.
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
    test "answers nil for anything that is not a screen document" do
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

    # The record reserves `answer_options` for the select question types and
    # does not build them in this version, so a question carrying it today is
    # a known type carrying a field this version does not know: admitted, the
    # field dropped, and nothing said about it.
    #
    # Sabotage: add `:answer_options` to the text question type's optional
    # fields and the reserved field is carried onto the admitted node.
    test "does not carry answer_options, the field reserved for question types this version does not build" do
      raw =
        document([
          %{
            "type" => "text_question",
            "key" => "account_plan",
            "label" => "Which plan?",
            "answer_options" => ["monthly", "yearly"]
          }
        ])

      document = Document.admit(raw)

      assert [%{nodes: [node]}] = document.screens
      assert node == %{type: "text_question", key: "account_plan", label: "Which plan?"}
      refute Map.has_key?(node, :answer_options)
      assert {:ok, ^document} = Document.validate(document)
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

  describe "the envelope's kind" do
    # Sabotage: made `admit_kind/1` answer nil for an absent kind; the
    # defaulted document came back with no kind at all and this went red,
    # with every other document that names no kind red beside it.
    test "defaults to screens when the document names none, and the document is admitted" do
      raw = document([%{"type" => "text", "key" => "account_intro", "text" => "Hello"}])
      document = Document.admit(raw)

      refute Map.has_key?(raw, "kind")
      assert document.kind == "screens"
      assert {:ok, ^document} = Document.validate(document)
    end

    # Sabotage: dropped the `kind in @kinds` clause of `kind_findings/1`; the
    # screens kind raised a finding about itself and this went red, with every
    # other clean-validation test red beside it.
    test "is admitted with no finding when the document names the screens kind" do
      document =
        Document.admit(
          Map.put(
            document([%{"type" => "text", "key" => "account_intro", "text" => "Hello"}]),
            "kind",
            "screens"
          )
        )

      assert document.kind == "screens"
      assert {:ok, ^document} = Document.validate(document)
    end

    # Sabotage: made `kind_findings/1` return `[]` for every kind and a
    # document declaring a kind with no runtime validated clean, so this went
    # red.
    test "a kind this package has no runtime for is a finding naming the value and no node" do
      raw =
        Map.put(
          document([%{"type" => "text", "key" => "account_intro", "text" => "Hello"}]),
          "kind",
          "emails"
        )

      document = Document.admit(raw)

      assert document.kind == "emails"
      assert [finding] = findings(raw)
      assert finding.code == "document.unknown_kind"
      assert finding.field == "kind"
      assert finding.node_key == nil
      assert finding.message =~ "emails"
    end

    # Sabotage: dropped `kind: document.kind` from the resolved envelope and
    # the resolved document came back with a nil kind, so this went red.
    test "is carried through to the resolved document" do
      document =
        Document.admit(
          Map.put(
            document([%{"type" => "text", "key" => "account_intro", "text" => "Hello"}]),
            "kind",
            "screens"
          )
        )

      assert {:ok, resolved} = Riddler.Screens.resolve(document, %{})
      assert resolved.kind == "screens"
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

    # Sabotage: delete the non-string clause of `key_findings/2` and the
    # integer key falls through to the absent-key clause, which tells the
    # author the node carries no key when it carries one of the wrong form.
    test "a key that is there and is not a string" do
      [finding] = findings(document([%{"type" => "text", "key" => 7, "text" => "Hi"}]))

      assert finding.code == "document.invalid_key"
      assert finding.field == "key"
      assert finding.node_key == nil
      assert finding.message =~ "7"
      assert finding.message =~ "string"
      refute finding.message =~ "carries no key"
    end

    # Sabotage: drop the `is_binary/1` filter from `every_key/1` and the two
    # nodes keyed 7 are reported as a duplicate key as well as an invalid one,
    # which says the document uses one key twice when it has no usable key.
    test "a non-string key used twice is not a duplicate" do
      raw = %{
        "screens" => [
          screen([
            %{"type" => "text", "key" => 7, "text" => "One"},
            %{"type" => "text", "key" => 7, "text" => "Two"}
          ])
        ]
      }

      assert codes(raw) == ["document.invalid_key", "document.invalid_key"]
      refute "document.duplicate_key" in codes(raw)
    end

    # Sabotage: write `node_key: node[:key]` back into any one raise site and
    # that finding carries the integer key, which the Finding typespec does not
    # admit and a host reading the key cannot use.
    test "no finding carries a non-string node key" do
      raw = %{
        "screens" => [
          %{
            "key" => 1,
            "title" => 2,
            "nodes" => [
              %{"type" => "carousel", "key" => 7},
              %{
                "type" => "heading",
                "key" => 8,
                "level" => 9,
                "text" => "Hi",
                "condition" => "&&"
              },
              %{
                "type" => "button",
                "key" => 9,
                "label" => "{% include \"x\" %}",
                "outcome" => "went_back",
                "style" => 3,
                "validates" => 4,
                "writes" => "not a map"
              },
              %{"type" => "text_question", "key" => 10, "label" => "Name", "required" => 5},
              %{"type" => "variant", "key" => 11, "nodes" => []}
            ]
          }
        ]
      }

      raised = findings(raw)

      # Every branch that puts a key on a finding is exercised here: the
      # unknown type, the invalid key itself, the screen title, a condition
      # that does not parse, a heading level, a refused template, a button's
      # writes, style and validates, a question's required, and an empty
      # variant.
      assert length(raised) >= 10

      for finding <- raised do
        assert is_binary(finding.node_key) or is_nil(finding.node_key),
               "#{finding.code} carries node_key #{inspect(finding.node_key)}"
      end
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

    # Sabotage: restore the `meta[:line] - 1` arithmetic in Riddler.Template
    # by calling `Solid.parse/2` straight from compile/1 - validate/1 raises
    # out of the parser on a document admit/1 has already accepted, and the
    # match in findings/1 never runs.
    test "a template field the parser refuses without a place is a finding, not a raise" do
      raw = %{
        "schema_version" => 1,
        "screens" => [
          %{
            "key" => "a",
            "title" => "t",
            "nodes" => [
              %{"type" => "heading", "key" => "h", "level" => 1, "text" => "{% render %}"}
            ]
          }
        ]
      }

      assert %Document{} = Document.admit(raw)
      assert [finding] = findings(raw)
      assert finding.code == "document.invalid_template"
      assert finding.node_key == "h"
      assert finding.position == nil
      assert finding.message =~ "could not be parsed"
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

    # A `pattern` is an expression the author wrote and this package compiles,
    # exactly as a template field is, so one it cannot compile is a defect in
    # the document rather than something a visitor could be wrong about.
    #
    # Sabotage: dropped `pattern_findings/1` from `TextQuestion.validate/1` and
    # a question holding a response to "[0-9" validated clean, so this went red.
    test "a question's pattern that is not a regular expression this package can use" do
      [finding] =
        findings(
          document([
            %{
              "type" => "text_question",
              "key" => "card_last_four",
              "label" => "Last four digits",
              "format" => "pattern",
              "pattern" => "[0-9"
            }
          ])
        )

      assert finding.code == "document.invalid_pattern"
      assert finding.field == "pattern"
      assert finding.node_key == "card_last_four"
      assert finding.message =~ "[0-9"
    end

    # Not a string is not a regular expression either, and it is the same
    # defect under the same code: the question declares an expression nothing
    # can read.
    #
    # Sabotage: matched `pattern_findings/1` on `is_binary(pattern)` only, so a
    # pattern declared as the number 4 validated clean, and this went red.
    test "a question's pattern that is not a string at all is the same finding" do
      [finding] =
        findings(
          document([
            %{
              "type" => "text_question",
              "key" => "card_last_four",
              "label" => "Last four digits",
              "format" => "pattern",
              "pattern" => 4
            }
          ])
        )

      assert finding.code == "document.invalid_pattern"
      assert finding.field == "pattern"
      assert finding.node_key == "card_last_four"
      assert finding.message =~ "4"
    end

    # The control for the two above: a pattern that compiles is a question this
    # package can hold a response to, and it validates clean.
    #
    # Sabotage: made `pattern_findings/1` raise for every declared pattern; the
    # four-digit question carried a finding and this test went red.
    test "a question's pattern that compiles validates clean" do
      clean =
        document([
          %{
            "type" => "text_question",
            "key" => "card_last_four",
            "label" => "Last four digits",
            "format" => "pattern",
            "pattern" => "[0-9]{4}"
          }
        ])
        |> Document.admit()

      assert {:ok, ^clean} = Document.validate(clean)
    end

    # The narrowing, pinned so that it is not widened back by accident. The
    # check follows the format that reads the field, not the field: a question
    # that does not ask for the `pattern` format declares, in this record's
    # words, something nothing consults, and this version says nothing about
    # it. Both shapes are here because they fail differently if the guard goes:
    # no format at all, and another format that does not read a pattern.
    #
    # Sabotage: dropped the `format == "pattern"` guard from
    # `pattern_findings/1`, so the check keyed on the field alone; both
    # questions carried `document.invalid_pattern` and this test went red.
    test "an uncompilable pattern on a question that does not ask for that format is not a finding" do
      for format <- [%{}, %{"format" => "email"}] do
        raw =
          document([
            Map.merge(
              %{
                "type" => "text_question",
                "key" => "card_last_four",
                "label" => "Last four digits",
                "pattern" => "[0-9"
              },
              format
            )
          ])

        admitted = Document.admit(raw)

        assert {:ok, ^admitted} = Document.validate(admitted)
      end
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

    # The envelope and boolean shapes the record states. Each is checked only
    # where the document carries the field: the schema requires `screens` and
    # nothing else, so requiredness is not what these checks answer.

    # Sabotage: dropped the `schema_version_findings(@schema_version)` clause
    # and every document in the suite raised a finding about its own version,
    # so this went red with most of the file red beside it; then widened the
    # remaining clause to `when is_integer(version)` and a document declaring
    # version 2 validated clean, so this went red alone.
    test "a schema_version this package is not the runtime for" do
      raw =
        Map.put(
          document([%{"type" => "text", "key" => "account_intro", "text" => "Hi"}]),
          "schema_version",
          2
        )

      [finding] = findings(raw)

      assert finding.code == "document.invalid_schema_version"
      assert finding.field == "schema_version"
      assert finding.node_key == nil
      assert finding.message =~ "2"
    end

    # Sabotage: widened `id_findings/1`'s second clause to `when not is_nil(id)`
    # and an id of 7 validated clean, so this went red.
    test "an id that is there and is not a string" do
      raw =
        Map.put(
          document([%{"type" => "text", "key" => "account_intro", "text" => "Hi"}]),
          "id",
          7
        )

      [finding] = findings(raw)

      assert finding.code == "document.invalid_id"
      assert finding.field == "id"
      assert finding.node_key == nil
      assert finding.message =~ "7"
    end

    # Sabotage: dropped `title_findings/1` from `screen_findings/1` and a
    # screen titled with a number validated clean, so this went red.
    test "a screen title that is there and is not a string" do
      raw =
        document([%{"type" => "text", "key" => "account_intro", "text" => "Hi"}], %{"title" => 3})

      [finding] = findings(raw)

      assert finding.code == "document.invalid_title"
      assert finding.field == "title"
      assert finding.node_key == "account"
      assert finding.message =~ "3"
    end

    # Sabotage: widened `required_findings/1`'s match to `when not is_nil(required)`
    # and a question required by the string "yes" validated clean, so this went
    # red.
    test "a question's required that is not a boolean" do
      raw =
        document([
          %{
            "type" => "text_question",
            "key" => "email",
            "label" => "Work email",
            "required" => "yes"
          }
        ])

      [finding] = findings(raw)

      assert finding.code == "document.invalid_required"
      assert finding.field == "required"
      assert finding.node_key == "email"
      assert finding.message =~ "yes"
    end

    # Sabotage: dropped `validates_findings/1` from `Type.Button.validate/1`
    # and a button validating by the string "always" validated clean, so this
    # went red.
    test "a button's validates that is not a boolean" do
      raw =
        document([
          %{
            "type" => "button",
            "key" => "account_continue",
            "label" => "Continue",
            "outcome" => "account_submitted",
            "validates" => "always"
          }
        ])

      [finding] = findings(raw)

      assert finding.code == "document.invalid_validates"
      assert finding.field == "validates"
      assert finding.node_key == "account_continue"
      assert finding.message =~ "always"
    end

    # Sabotage: dropped `style_findings/1` from `Type.Button.validate/1` and a
    # button styled `1` validated clean, so this went red.
    test "a button's style that is not a string" do
      raw =
        document([
          %{
            "type" => "button",
            "key" => "account_continue",
            "label" => "Continue",
            "outcome" => "account_submitted",
            "style" => 1
          }
        ])

      [finding] = findings(raw)

      assert finding.code == "document.invalid_style"
      assert finding.field == "style"
      assert finding.node_key == "account_continue"
      assert finding.message =~ "1"
    end

    # Sabotage: dropped the `nil` clause of `schema_version_findings/1`,
    # `id_findings/1` and `title_findings/1`, so an absent field was refused
    # as a wrong one; the document that declares none of the three came back
    # with three findings and this went red, with the duplicate-key test red
    # beside it because its document declares none of them either. It is the
    # guard that keeps these checks about shape rather than about
    # requiredness, which the schema decides and this version leaves where it
    # found it.
    test "and refuses none of them for a document that declares them not at all" do
      raw = %{
        "screens" => [
          %{
            "key" => "account",
            "nodes" => [
              %{"type" => "text_question", "key" => "email", "label" => "Work email"},
              %{
                "type" => "button",
                "key" => "account_continue",
                "label" => "Continue",
                "outcome" => "account_submitted"
              }
            ]
          }
        ]
      }

      document = Document.admit(raw)

      assert document.schema_version == nil
      assert document.id == nil
      assert hd(document.screens).title == nil
      assert {:ok, ^document} = Document.validate(document)
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

    # Mutation: give Riddler.Finding a default position other than nil, or set
    # one on a document check - a refusal about the document itself, here a
    # heading level out of range and a key of the wrong form, is about data
    # rather than source text, so a position on it is a span pointing at
    # nothing.
    test "and gives a finding that is not about a template no source position" do
      findings =
        findings(
          document([
            %{"type" => "heading", "key" => "Account_Heading", "level" => 9, "text" => "Hi"}
          ])
        )

      assert findings != []
      assert Enum.all?(findings, &is_nil(&1.position))
    end

    # Mutation: drop `position: finding.position` from the re-wrap in
    # `refusals/3` - the document finding then names the line and the column
    # in its sentence and carries them nowhere, which is the whole thing the
    # field exists to stop. This goes through `admit/1` and then `validate/1`,
    # the door a host with a document comes through, rather than through
    # `Riddler.Template.compile/1`.
    test "and carries the position of a refused template through to the document finding" do
      [finding] =
        findings(
          document([
            %{
              "type" => "heading",
              "key" => "greeting",
              "level" => 1,
              "text" => "abc{% include 'footer' %}"
            }
          ])
        )

      assert finding.code == "document.invalid_template"
      assert finding.node_key == "greeting"
      assert finding.position == %{line: 1, column: 4}
      assert finding.message =~ "(line 1, column 4)"
    end
  end
end
