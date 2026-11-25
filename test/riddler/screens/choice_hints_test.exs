defmodule Riddler.Screens.ChoiceHintsTest do
  use ExUnit.Case, async: true

  alias Riddler.Journey
  alias Riddler.Screens
  alias Riddler.Screens.Document

  defp raw(elements) do
    %{
      "schema_version" => 2,
      "id" => "edoc_signup_screens",
      "screens" => [%{"key" => "plan", "title" => "Pick a plan", "elements" => elements}]
    }
  end

  defp document(elements), do: Document.admit(raw(elements))

  defp findings(elements) do
    case Document.validate(document(elements)) do
      {:ok, _document} -> []
      {:error, findings} -> Enum.map(findings, &{&1.code, &1.element_key, &1.field})
    end
  end

  defp plan_choice(overrides) do
    Map.merge(
      %{
        "type" => "choice_question",
        "key" => "plan_choice",
        "label" => "Which plan?",
        "select" => "one",
        "answer_options" => [
          %{"value" => "personal", "label" => "Personal", "description" => "One seat."},
          %{
            "value" => "business",
            "label" => "Business",
            "description" => "Up to 50 seats for {{ context.tenant_name }}."
          }
        ]
      },
      overrides
    )
  end

  defp plain_choice do
    plan_choice(%{
      "answer_options" => [
        %{"value" => "personal", "label" => "Personal"},
        %{"value" => "business", "label" => "Business"}
      ]
    })
  end

  defp next_button do
    %{"type" => "button", "key" => "plan_next", "label" => "Continue", "outcome" => "plan_chosen"}
  end

  defp root(context), do: %{"context" => context, "responses" => %{}}

  defp admitted_element(elements), do: hd(hd(document(elements).screens).elements)

  defp resolved(elements, root) do
    {:ok, screen, diagnostics} = Screens.resolve_screen(document(elements), "plan", root)
    {screen.elements, diagnostics}
  end

  describe "the hints at admit" do
    # Sabotage: removed :searchable from the choice question's optional
    # fields; searchable was dropped at admit and this test went red. The
    # chips half pins that the style stays an open string: chips is a name
    # offered, not a name the package checks.
    test "chips, for one and for many, and searchable are admitted and carried" do
      for select <- ["one", "many"], searchable <- [true, false] do
        element =
          plan_choice(%{"select" => select, "style" => "chips", "searchable" => searchable})

        assert findings([element]) == [], select
        assert %{style: "chips", searchable: ^searchable} = admitted_element([element])
      end
    end

    # Sabotage: made the choice question's searchable check answer []; the
    # string and the number raised nothing and this test went red.
    test "a searchable that is not a boolean is an invalid hint" do
      for searchable <- ["yes", 1, nil, ["true"]] do
        assert findings([plan_choice(%{"searchable" => searchable})]) ==
                 [{"document.invalid_hint", "plan_choice", "searchable"}],
               inspect(searchable)
      end
    end
  end

  describe "an option's description at admit" do
    # Sabotage: took :description out of the option fields admission keeps;
    # the description was dropped and this test went red.
    test "is kept beside value and label, and any other option field is dropped" do
      element =
        plan_choice(%{
          "answer_options" => [
            %{
              "value" => "personal",
              "label" => "Personal",
              "description" => "One seat.",
              "price" => 0
            }
          ]
        })

      assert findings([element]) == []

      assert %{
               answer_options: [
                 %{value: "personal", label: "Personal", description: "One seat."} = option
               ]
             } =
               admitted_element([element])

      refute Map.has_key?(option, :price)
    end

    # Sabotage: read only the option's label as a template at admit; neither
    # description was refused and this test went red.
    test "that is not a string, or holds a construct outside the subset, is an invalid template" do
      for {description, field} <- [
            {3, "description"},
            {nil, "description"},
            {"{% include 'footer' %}", "include"}
          ] do
        element =
          plan_choice(%{
            "answer_options" => [
              %{"value" => "personal", "label" => "Personal", "description" => description}
            ]
          })

        assert findings([element]) == [{"document.invalid_template", "plan_choice", field}],
               inspect(description)
      end
    end

    # Sabotage: named only the option's label among the paths a secret
    # reference is looked for in; the description raised nothing and this
    # test went red.
    test "naming a secret question's response is a secret reference" do
      pin = %{"type" => "secret_question", "key" => "account_pin", "label" => "Choose a PIN"}

      element =
        plan_choice(%{
          "answer_options" => [
            %{"value" => "personal", "label" => "Personal", "description" => "One seat."},
            %{
              "value" => "business",
              "label" => "Business",
              "description" => "PIN {{ responses.account_pin }}"
            }
          ]
        })

      assert findings([pin, element]) ==
               [{"document.secret_reference", "plan_choice", "description"}]
    end
  end

  describe "resolution and presentation" do
    # Sabotage: rendered only the option's label at resolve; the description
    # kept its template source and this test went red. A false searchable is
    # carried as a true one is, and each option reports its label's missing
    # variable before its description's.
    test "each authored option's description is rendered, a missing variable reported under the question" do
      element =
        plan_choice(%{
          "searchable" => false,
          "answer_options" => [
            %{"value" => "personal", "label" => "Personal", "description" => "One seat."},
            %{
              "value" => "business",
              "label" => "Business for {{ context.company }}",
              "description" => "Up to 50 seats for {{ context.tenant_name }}."
            }
          ]
        })

      {[question], diagnostics} = resolved([element], root(%{}))

      assert question.searchable == false

      assert [
               %{value: "personal", label: "Personal", description: "One seat."},
               %{value: "business", label: "Business for ", description: "Up to 50 seats for ."}
             ] = question.answer_options

      assert diagnostics.missing_variables == [
               %{key: "plan_choice", variable: "context.company"},
               %{key: "plan_choice", variable: "context.tenant_name"}
             ]
    end

    # Sabotage: made a context option carry the host's "description"; the
    # resolved option carried it and this test went red.
    test "an option read from context carries no description the host's list holds" do
      element =
        plan_choice(%{"answer_options_from" => "context.plans"})
        |> Map.delete("answer_options")

      plans = [%{"value" => "personal", "label" => "Personal", "description" => "One seat."}]

      {[question], _diagnostics} = resolved([element], root(%{"plans" => plans}))

      assert question.answer_options == [%{value: "personal", label: "Personal"}]
    end

    # Sabotage: made admission put an empty description on every option; the
    # plain question's options carried it and this test went red.
    test "a question that uses none of them presents as before" do
      {:ok, answer} =
        Journey.present(document([plain_choice(), next_button()]), {:screen, "plan"}, root(%{}))

      [question, _button] = answer["screen"]["elements"]

      refute Map.has_key?(question, "searchable")

      assert Enum.map(question["answer_options"], &Enum.sort(Map.keys(&1))) == [
               ["label", "value"],
               ["label", "value"]
             ]
    end

    # Sabotage: typed searchable as a string in the presented-answer schema;
    # the presented boolean failed validation and this test went red.
    test "a presented searchable and option description validate against the presented-answer schema" do
      schema =
        "priv/schemas/presented-answer.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()

      elements = [plan_choice(%{"style" => "chips", "searchable" => true}), next_button()]

      {:ok, answer} =
        Journey.present(document(elements), {:screen, "plan"}, root(%{"tenant_name" => "Acme"}))

      [question, button] = answer["screen"]["elements"]

      assert ExJsonSchema.Validator.valid?(schema, answer)

      [first | rest] = question["answer_options"]

      for broken <- [
            Map.put(question, "searchable", "yes"),
            Map.put(question, "answer_options", [Map.put(first, "description", 3) | rest])
          ] do
        refute ExJsonSchema.Validator.valid?(
                 schema,
                 put_in(answer, ["screen", "elements"], [broken, button])
               ),
               inspect(broken)
      end
    end
  end
end
