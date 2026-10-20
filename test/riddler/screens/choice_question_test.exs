defmodule Riddler.Screens.ChoiceQuestionTest do
  use ExUnit.Case, async: true

  doctest Riddler.Screens.Type.ChoiceQuestion
  doctest Riddler.Screens.Type.BooleanQuestion

  alias Riddler.Screens
  alias Riddler.Screens.Document

  @schema "priv/schemas/screen-document.schema.json"

  defp document(nodes) do
    %{
      "schema_version" => 1,
      "id" => "edoc_signup_screens",
      "screens" => [%{"key" => "plan", "title" => "Pick a plan", "nodes" => nodes}]
    }
  end

  defp plan_choice(overrides \\ %{}) do
    Map.merge(
      %{
        "type" => "choice_question",
        "key" => "plan_choice",
        "label" => "Which plan?",
        "select" => "one",
        "answer_options" => [
          %{"value" => "personal", "label" => "Personal"},
          %{"value" => "business", "label" => "Business"}
        ]
      },
      overrides
    )
  end

  defp heard_from(overrides) do
    Map.merge(
      %{
        "type" => "choice_question",
        "key" => "plan_heard_from",
        "label" => "Where did you hear about us?",
        "select" => "many",
        "answer_options" => [
          %{"value" => "search", "label" => "A search engine"},
          %{"value" => "referral", "label" => "A friend or colleague"},
          %{"value" => "advert", "label" => "An advertisement"}
        ]
      },
      overrides
    )
  end

  defp terms(overrides) do
    Map.merge(
      %{
        "type" => "boolean_question",
        "key" => "plan_terms",
        "label" => "I agree to the terms of service.",
        "required" => true
      },
      overrides
    )
  end

  defp only_node(raw) do
    assert %Document{screens: [%{nodes: [node]}]} = Document.admit(raw)
    node
  end

  defp findings(raw) do
    case raw |> Document.admit() |> Document.validate() do
      {:ok, _document} -> []
      {:error, findings} -> findings
    end
  end

  defp tuples(raw), do: raw |> findings() |> Enum.map(&{&1.code, &1.field, &1.node_key})

  defp schema, do: @schema |> File.read!() |> Jason.decode!() |> ExJsonSchema.Schema.resolve()

  describe "admit/1" do
    # Sabotage: made `admit_option/1` keep the option as the document wrote it;
    # the options came back string-keyed, carrying the extra field, and this
    # went red.
    test "admits a choice question's options atom-keyed, value and label only, in order" do
      options = [
        %{"value" => "personal", "label" => "Personal", "description" => "For one person"},
        %{"value" => "business", "label" => "Business"}
      ]

      node =
        only_node(document([plan_choice(%{"answer_options" => options, "style" => "radio"})]))

      assert node == %{
               type: "choice_question",
               key: "plan_choice",
               label: "Which plan?",
               select: "one",
               style: "radio",
               answer_options: [
                 %{value: "personal", label: "Personal"},
                 %{value: "business", label: "Business"}
               ]
             }
    end

    # Sabotage: added `:style` to the boolean question type's optional fields;
    # the style was carried onto the admitted node and this went red.
    test "admits a boolean question and drops a style written on it" do
      node = only_node(document([terms(%{"style" => "toggle", "format" => "checkbox"})]))

      assert node == %{
               type: "boolean_question",
               key: "plan_terms",
               label: "I agree to the terms of service.",
               required: true,
               format: "checkbox"
             }
    end

    # An integral float bound is admitted as its integer, as the record says
    # of a number with no fractional part; a bound with one is carried as
    # written and refused by `validate/1`.
    #
    # Sabotage: dropped the reduce over the bounds from `admit_choice/1`; the
    # bounds came back as 1.0 and 2.0 and this went red.
    test "admits a selection bound with no fractional part as its integer" do
      node =
        only_node(document([heard_from(%{"min_selections" => 1.0, "max_selections" => 2.0})]))

      assert node.min_selections === 1
      assert node.max_selections === 2

      node = only_node(document([heard_from(%{"min_selections" => 1.5})]))
      assert node.min_selections === 1.5
    end

    # Sabotage: made `admit_options/1` answer `{:ok, typed}` for options that
    # are not a list; the string of options was admitted and this went red.
    # Again with `admit_option/1` admitting any value: the list of strings was
    # admitted and this went red.
    test "answers nil for a choice question whose options are not a list of options" do
      for options <- [
            "personal, business",
            nil,
            ["personal", "business"],
            [%{"value" => 1, "label" => "Personal"}],
            [%{"value" => "personal", "label" => nil}]
          ] do
        assert Document.admit(document([plan_choice(%{"answer_options" => options})])) == nil,
               "admitted #{inspect(options)}"
      end
    end

    # On every node but a choice question, answer_options is a field the type
    # does not name: admitted and dropped whatever it holds, a node naming no
    # type included.
    #
    # Sabotage: made `admit_node/1` hold the answer_options of every node to
    # the choice question's shape; a text question carrying a string of
    # options was not a document and this went red.
    test "drops answer_options of any shape on a node that is not a choice question" do
      for options <- ["monthly", nil, ["monthly"], [%{"value" => 1}]],
          carrier <- [
            %{"type" => "text_question", "key" => "plan_choice", "label" => "Which plan?"},
            %{"key" => "plan_choice", "label" => "Which plan?"}
          ] do
        node = only_node(document([Map.put(carrier, "answer_options", options)]))
        refute Map.has_key?(node, :answer_options)
      end
    end
  end

  describe "the document schema" do
    # Both directions over the shapes above, checked against the schema the
    # package ships: a value admission refuses is one the schema refuses, and
    # a node naming no type, or a type that is not a choice question, is not
    # held to the conditional.
    #
    # Sabotage: dropped the `required` clause from the schema's conditional; a
    # node naming no type and carrying a list of strings under answer_options
    # failed the schema while admission admitted it, and this went red. Again
    # with the conditional dropped altogether: the choice question whose
    # options are a string passed the schema and this went red.
    test "types a choice question's answer_options and nothing else, agreeing with admission" do
      schema = schema()

      raws = [
        document([plan_choice()]),
        document([plan_choice(%{"answer_options" => "personal, business"})]),
        document([plan_choice(%{"answer_options" => nil})]),
        document([plan_choice(%{"answer_options" => ["personal"]})]),
        document([plan_choice(%{"answer_options" => [%{"value" => 1, "label" => "Personal"}]})]),
        document([plan_choice(%{"answer_options" => [%{"value" => "personal", "label" => 1}]})]),
        document([plan_choice(%{"answer_options" => [%{"label" => "Personal"}]})]),
        document([plan_choice(%{"answer_options" => []})]),
        document([%{"key" => "plan_choice", "answer_options" => ["personal"]}]),
        document([
          %{"type" => "text_question", "key" => "plan_choice", "answer_options" => "personal"}
        ])
      ]

      disagreements =
        for raw <- raws,
            schema_valid <- [ExJsonSchema.Validator.valid?(schema, raw)],
            admitted <- [Document.admit(raw) != nil],
            schema_valid != admitted,
            do: {raw, schema_valid, admitted}

      assert disagreements == []
      assert Enum.count(raws, &(Document.admit(&1) == nil)) == 5
    end
  end

  describe "validate/1" do
    # Sabotage: made `select_findings/2` answer `[]`; "several" validated
    # clean and this went red.
    test "refuses a select that is neither one nor many, and a choice question missing its fields" do
      assert tuples(document([plan_choice(%{"select" => "several"})])) ==
               [{"document.invalid_select", "select", "plan_choice"}]

      bare = %{"type" => "choice_question", "key" => "plan_choice", "label" => "Which plan?"}

      assert tuples(document([bare])) == [
               {"document.missing_field", "select", "plan_choice"},
               {"document.missing_field", "answer_options", "plan_choice"}
             ]

      assert tuples(document([%{"type" => "boolean_question", "key" => "plan_terms"}])) ==
               [{"document.missing_field", "label", "plan_terms"}]
    end

    # Sabotage: made the empty-list clause of `options_findings/2` answer
    # `[]`; a question offering nothing validated clean and this went red.
    test "refuses a choice question offering no option" do
      assert tuples(document([plan_choice(%{"answer_options" => []})])) ==
               [{"document.empty_answer_options", "answer_options", "plan_choice"}]
    end

    # Sabotage: dropped the key-shape match from `value_findings/3`; the
    # value "Business plan" validated clean and this went red. Again with
    # `label_findings/3` answering `[]`: the option with no label validated
    # clean and this went red.
    test "refuses an option with no value, a value not in the key shape, or no label" do
      options = [
        %{"label" => "Personal"},
        %{"value" => "Business plan", "label" => "Business"},
        %{"value" => "team"}
      ]

      found = findings(document([plan_choice(%{"answer_options" => options})]))

      assert Enum.map(found, &{&1.code, &1.field, &1.node_key}) ==
               List.duplicate({"document.invalid_option", "answer_options", "plan_choice"}, 3)

      assert [no_value, bad_value, no_label] = Enum.map(found, & &1.message)
      assert no_value =~ "option 1 carries no value"
      assert bad_value =~ ~s("Business plan")
      assert no_label =~ "option 3 carries no label"
    end

    # Sabotage: anchored the value shape with ^ and $; "personal" followed by
    # a newline validated clean and this went red.
    test "refuses an option value carrying a trailing newline" do
      options = [
        %{"value" => "personal\n", "label" => "Personal"},
        %{"value" => "business", "label" => "Business"}
      ]

      assert tuples(document([plan_choice(%{"answer_options" => options})])) ==
               [{"document.invalid_option", "answer_options", "plan_choice"}]
    end

    # Sabotage: made `duplicate_findings/2` answer `[]`; the second
    # "personal" validated clean and this went red. Option values are not
    # keys: two questions offering the same value raise nothing.
    test "refuses a value two options of one question carry, and not one two questions share" do
      options = [
        %{"value" => "personal", "label" => "Personal"},
        %{"value" => "business", "label" => "Business"},
        %{"value" => "personal", "label" => "Personal (yearly)"}
      ]

      assert tuples(document([plan_choice(%{"answer_options" => options})])) ==
               [{"document.duplicate_option_value", "answer_options", "plan_choice"}]

      assert tuples(document([plan_choice(), plan_choice(%{"key" => "plan_upgrade_to"})])) == []
    end

    # Sabotage: dropped `option_template_findings/2` from
    # `template_findings/2`; the include in an option label validated clean
    # and this went red.
    test "refuses an option label holding a construct outside the template subset" do
      options = [
        %{"value" => "personal", "label" => "Personal"},
        %{"value" => "business", "label" => "{% include 'business' %}"}
      ]

      assert [finding] = findings(document([plan_choice(%{"answer_options" => options})]))

      assert {finding.code, finding.field, finding.node_key} ==
               {"document.invalid_template", "include", "plan_choice"}

      assert finding.message =~ "option 2"
      assert finding.position == %{line: 1, column: 1}
    end

    # Sabotage: made `bounds_findings/2` read every question as select many;
    # the bound under select one validated clean and this went red. Again with the
    # `count?/1` check dropped: 1.5 validated clean. Again with the
    # option-count check dropped: 4 of three options validated clean. Again
    # with `order_findings/3` answering `[]`: 3 above 2 validated clean.
    test "refuses selection bounds nothing reads, of the wrong kind, above the options or out of order" do
      assert tuples(document([plan_choice(%{"max_selections" => 1})])) ==
               [{"document.invalid_selection_bounds", "max_selections", "plan_choice"}]

      assert tuples(document([heard_from(%{"min_selections" => 1.5, "max_selections" => 4})])) ==
               [
                 {"document.invalid_selection_bounds", "min_selections", "plan_heard_from"},
                 {"document.invalid_selection_bounds", "max_selections", "plan_heard_from"}
               ]

      assert tuples(document([heard_from(%{"min_selections" => -1})])) ==
               [{"document.invalid_selection_bounds", "min_selections", "plan_heard_from"}]

      assert tuples(document([heard_from(%{"min_selections" => 3, "max_selections" => 2})])) ==
               [{"document.invalid_selection_bounds", "min_selections", "plan_heard_from"}]

      assert tuples(document([heard_from(%{"min_selections" => 0, "max_selections" => 3.0})])) ==
               []
    end

    # Sabotage: made `required_findings/2` in the choice question type answer
    # `[]`; its required of "yes" validated clean and this went red. Again in
    # the boolean question type.
    test "refuses a required that is not a boolean on either type" do
      raw = document([plan_choice(%{"required" => "yes"}), terms(%{"required" => "yes"})])

      assert tuples(raw) == [
               {"document.invalid_required", "required", "plan_choice"},
               {"document.invalid_required", "required", "plan_terms"}
             ]
    end

    # Sabotage: made `style_findings/2` in the choice question type answer
    # `[]`; a style of 1 validated clean and this went red.
    test "refuses a choice question's style that is not a string, and passes any string through" do
      assert tuples(document([plan_choice(%{"style" => 1})])) ==
               [{"document.invalid_style", "style", "plan_choice"}]

      assert tuples(document([plan_choice(%{"style" => "checkboxes"})])) == []
    end

    # Sabotage: added `document.unknown_format` to the choice question type
    # for a format outside the package's list; "e-mail" was refused and this
    # went red.
    test "raises nothing for a format on either type, whatever it names" do
      raw = document([plan_choice(%{"format" => "e-mail"}), terms(%{"format" => "checkbox"})])

      assert tuples(raw) == []
    end

    # A struct a host builds by hand rather than admits can hold what
    # admission refuses; validation answers it rather than raising.
    #
    # Sabotage: made the non-map clause of `option_findings/3` answer `[]`;
    # the string option raised nothing and this went red.
    test "answers a hand-built choice question whose options admission would refuse" do
      node = %{
        type: "choice_question",
        key: "plan_choice",
        label: "Which plan?",
        select: "one",
        answer_options: ["personal", %{value: 7, label: "Business"}]
      }

      document = %Document{screens: [%{key: "plan", title: "Pick a plan", nodes: [node]}]}

      assert {:error, found} = Document.validate(document)
      assert Enum.map(found, & &1.code) == ["document.invalid_option", "document.invalid_option"]
    end
  end

  describe "resolution" do
    defp choice_document(options) do
      [
        plan_choice(%{
          "label" => "Which plan suits {{ context.tenant_name }}?",
          "answer_options" => options,
          "style" => "radio"
        }),
        plan_choice(%{
          "key" => "plan_hidden",
          "condition" => "context.seats > 1",
          "answer_options" => [%{"value" => "team", "label" => "{{ responses.team_name }}"}]
        })
      ]
      |> document()
      |> Document.admit()
    end

    # Sabotage: dropped `render_options/3` from `render/3`; the option labels
    # came back as their template source and this went red.
    test "renders each option label, leaves each value as written, and reports a missing variable under the question's key" do
      options = [
        %{"value" => "personal", "label" => "Personal, for {{ responses.first_name }}"},
        %{"value" => "business", "label" => "Business, for {{ context.tenant_name }}"}
      ]

      root = %{"context" => %{"tenant_name" => "Acme", "seats" => 1}}

      {:ok, screen, diagnostics} = Screens.resolve_screen(choice_document(options), "plan", root)

      assert [node] = screen.nodes

      assert node.answer_options == [
               %{value: "personal", label: "Personal, for "},
               %{value: "business", label: "Business, for Acme"}
             ]

      assert node.label == "Which plan suits Acme?"
      assert node.style == "radio"

      assert diagnostics.missing_variables == [
               %{key: "plan_choice", variable: "responses.first_name"}
             ]
    end

    # A refused option label is the document's finding; resolution leaves the
    # source standing, as for any template field.
    #
    # Sabotage: made `render_field/5` put an empty string for a template that
    # does not compile; the refused label came back empty and this went red.
    test "leaves an option label that does not compile as written" do
      options = [%{"value" => "personal", "label" => "{% include 'personal' %}"}]

      {:ok, screen, _diagnostics} =
        Screens.resolve_screen(choice_document(options), "plan", %{"context" => %{"seats" => 1}})

      assert [%{answer_options: [%{value: "personal", label: "{% include 'personal' %}"}]}] =
               screen.nodes
    end
  end
end
