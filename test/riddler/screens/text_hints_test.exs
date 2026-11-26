defmodule Riddler.Screens.TextHintsTest do
  use ExUnit.Case, async: true

  alias Riddler.Journey
  alias Riddler.Screens
  alias Riddler.Screens.Document

  defp raw(elements) do
    %{
      "schema_version" => 2,
      "id" => "edoc_signup_screens",
      "screens" => [
        %{"key" => "plan", "title" => "Pick a plan", "elements" => elements}
      ]
    }
  end

  defp document(elements), do: Document.admit(raw(elements))

  defp findings(elements) do
    case Document.validate(document(elements)) do
      {:ok, _document} -> []
      {:error, findings} -> Enum.map(findings, &{&1.code, &1.element_key, &1.field})
    end
  end

  defp seats_question(overrides) do
    Map.merge(
      %{
        "type" => "text_question",
        "key" => "seat_count",
        "label" => "How many seats?"
      },
      overrides
    )
  end

  defp next_button do
    %{
      "type" => "button",
      "key" => "plan_next",
      "label" => "Continue",
      "outcome" => "plan_chosen"
    }
  end

  defp root(responses), do: %{"context" => %{}, "responses" => responses}

  defp admitted_element(elements), do: hd(hd(document(elements).screens).elements)

  describe "style at admit" do
    # Sabotage: removed :style from the text question's optional fields; the
    # style was dropped at admit and this test went red. The names offered and
    # one no renderer is offered pass alike: the hint stays an open string.
    test "multiline, slider, stepper and any other string are admitted and carried" do
      for style <- ["multiline", "slider", "stepper", "dial"],
          format <- [nil, "integer", "number", "email"] do
        element =
          seats_question(%{"style" => style})
          |> then(&if(format, do: Map.put(&1, "format", format), else: &1))

        assert findings([element]) == [], inspect({style, format})
        assert %{style: ^style} = admitted_element([element])
      end
    end

    # Sabotage: made the text question's style check accept any value; the
    # number and the null raised nothing and this test went red.
    test "a style that is not a string is an invalid style" do
      for style <- [2, nil, true, ["slider"]] do
        assert findings([seats_question(%{"style" => style})]) ==
                 [{"document.invalid_style", "seat_count", "style"}],
               inspect(style)
      end
    end
  end

  describe "step at admit" do
    # Sabotage: removed :step from the text question's optional fields; the
    # step was dropped at admit and this test went red.
    test "a positive step with a numeric format is admitted and carried as written" do
      for {format, step} <- [
            {"integer", 1},
            {"integer", 5},
            {"integer", 2.0},
            {"number", 0.5},
            {"number", 3}
          ] do
        element = seats_question(%{"format" => format, "step" => step})

        assert findings([element]) == [], inspect({format, step})
        assert %{step: ^step} = admitted_element([element])
      end
    end

    # Sabotage: made the step check accept a step of zero; the zeros raised
    # nothing and this test went red.
    test "a step with a numeric format that is not a number above zero is an invalid step" do
      for {format, step} <- [
            {"integer", 0},
            {"integer", -1},
            {"integer", 0.5},
            {"integer", 1.5},
            {"integer", "1"},
            {"number", 0},
            {"number", 0.0},
            {"number", -0.25},
            {"number", "0.5"},
            {"number", nil},
            {"number", true}
          ] do
        assert findings([seats_question(%{"format" => format, "step" => step})]) ==
                 [{"document.invalid_step", "seat_count", "step"}],
               inspect({format, step})
      end
    end

    # Sabotage: read the step as the number format's whatever the format; the
    # zero and the negative step on the email, date and formatless questions
    # were refused and this test went red.
    test "with any other format, or none, a number step raises nothing and is carried" do
      for format <- [nil, "email", "phone", "date", "pattern"], step <- [0, -2, 0.5, 3] do
        element = non_numeric_question(format, step)

        assert findings([element]) == [], inspect({format, step})
        assert %{step: ^step} = admitted_element([element])
      end
    end

    # Sabotage: restored the step check to the numeric formats alone; the
    # string, boolean and null steps on the email, date and formatless
    # questions raised nothing and this test went red.
    test "with any other format, or none, a step that is not a number is an invalid step" do
      for format <- [nil, "email", "phone", "date", "pattern"],
          step <- ["fast", "1", true, nil] do
        assert findings([non_numeric_question(format, step)]) ==
                 [{"document.invalid_step", "seat_count", "step"}],
               inspect({format, step})
      end
    end
  end

  defp non_numeric_question(format, step) do
    seats_question(%{"step" => step})
    |> then(&if(format, do: Map.put(&1, "format", format), else: &1))
    |> then(&if(format == "pattern", do: Map.put(&1, "pattern", "[0-9]+"), else: &1))
  end

  describe "resolution, response validation and presentation" do
    # Sabotage: made validation refuse a response off the step; 7 with a step
    # of 5 was refused and this test went red.
    test "response validation does not read step: a response between the bounds is admitted whatever the step" do
      element =
        seats_question(%{
          "format" => "integer",
          "min" => 0,
          "max" => 20,
          "step" => 5,
          "style" => "slider"
        })

      doc = document([element])

      assert Screens.validate_screen(doc, "plan", root(%{"seat_count" => "7"})) ==
               :ok

      assert {:error, [finding]} =
               Screens.validate_screen(doc, "plan", root(%{"seat_count" => "25"}))

      assert {finding.code, finding.field} == {"response.out_of_range", "max"}
    end

    # Sabotage: dropped style and step from the resolved element; the resolved
    # question carried neither and this test went red.
    test "the resolved and presented question carry style and step where written" do
      element =
        seats_question(%{"format" => "integer", "step" => 1, "style" => "stepper"})

      {:ok, screen, _diagnostics} =
        Screens.resolve_screen(document([element]), "plan", root(%{}))

      assert [%{style: "stepper", step: 1}] = screen.elements

      {:ok, answer} =
        Journey.present(
          document([element, next_button()]),
          {:screen, "plan"},
          root(%{})
        )

      assert [%{"style" => "stepper", "step" => 1}, _button] = answer["screen"]["elements"]
    end

    # Sabotage: made resolution put a default style on every question that
    # presents a value; the plain question carried it and this test went red.
    test "a question that uses neither presents as before" do
      {:ok, answer} =
        Journey.present(
          document([seats_question(%{"format" => "integer"}), next_button()]),
          {:screen, "plan"},
          root(%{})
        )

      [question, _button] = answer["screen"]["elements"]

      assert Enum.sort(Map.keys(question)) == ["format", "key", "label", "type"]
    end

    # Sabotage: typed step as a string in the presented-answer schema; the
    # presented number failed validation and this test went red.
    test "a presented style and step validate against the presented-answer schema" do
      schema =
        "priv/schemas/presented-answer.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()

      elements = [
        seats_question(%{"format" => "number", "step" => 0.5, "style" => "slider"}),
        next_button()
      ]

      {:ok, answer} =
        Journey.present(document(elements), {:screen, "plan"}, root(%{}))

      [question, button] = answer["screen"]["elements"]

      assert ExJsonSchema.Validator.valid?(schema, answer)

      for broken <- [Map.put(question, "style", 2), Map.put(question, "step", "0.5")] do
        refute ExJsonSchema.Validator.valid?(
                 schema,
                 put_in(answer, ["screen", "elements"], [broken, button])
               ),
               inspect(broken)
      end
    end

    # A step under a format that does not read it is carried to the presented
    # question as written, and the presented-answer schema types it a number
    # whatever the format, so admission refusing a step that is not a number is
    # what keeps every presented answer valid against that schema.
    # Sabotage: typed step as a string in the presented-answer schema; the
    # presented email and formatless questions failed validation and this
    # test went red.
    test "a number step under a non-numeric format presents an answer the schema accepts" do
      schema =
        "priv/schemas/presented-answer.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()

      for {format, step} <- [{"email", 2}, {"date", 0.5}, {nil, -1}] do
        elements = [non_numeric_question(format, step), next_button()]

        {:ok, answer} = Journey.present(document(elements), {:screen, "plan"}, root(%{}))

        [question, _button] = answer["screen"]["elements"]
        assert %{"step" => ^step} = question
        assert ExJsonSchema.Validator.valid?(schema, answer), inspect({format, step})
      end
    end

    # A question's checks are read at validation and never cross the wire; a
    # question that writes them beside style and step keeps all three apart.
    # Sabotage: dropped `:style` and `:step` from the text question's optional
    # fields; admission dropped both and this test went red.
    test "a question with checks, style and step admits, validates its checks and presents its hints" do
      check = %{
        "condition" => "responses.seat_count::integer <= 10",
        "code" => "check.too_many_seats",
        "message" => "This plan takes ten seats at most."
      }

      element =
        seats_question(%{
          "format" => "integer",
          "step" => 1,
          "style" => "stepper",
          "checks" => [check]
        })

      elements = [element, next_button()]

      assert findings(elements) == []

      assert Screens.validate_screen(document(elements), "plan", root(%{"seat_count" => "3"})) ==
               :ok

      assert {:error, [%{code: "check.too_many_seats", element_key: "seat_count"}]} =
               Screens.validate_screen(document(elements), "plan", root(%{"seat_count" => "12"}))

      {:ok, screen, _diagnostics} =
        Screens.resolve_screen(document(elements), "plan", root(%{}))

      [resolved, _button] = screen.elements
      assert %{style: "stepper", step: 1} = resolved
      refute Map.has_key?(resolved, :checks)

      {:ok, answer} = Journey.present(document(elements), {:screen, "plan"}, root(%{}))

      [question, _button] = answer["screen"]["elements"]
      assert %{"style" => "stepper", "step" => 1} = question
      refute Map.has_key?(question, "checks")

      schema =
        "priv/schemas/presented-answer.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()

      assert ExJsonSchema.Validator.valid?(schema, answer)
    end
  end
end
