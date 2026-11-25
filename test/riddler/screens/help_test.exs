defmodule Riddler.Screens.HelpTest do
  use ExUnit.Case, async: true

  alias Riddler.Journey
  alias Riddler.Screens
  alias Riddler.Screens.Document

  # `help` is a line of guidance beside a question, a template on every
  # question type: admitted where the type names it, refused as any template
  # field is, and rendered leniently at resolve with each variable the root
  # does not carry reported under the question's key.

  defp document(nodes) do
    Document.admit(%{
      "schema_version" => 1,
      "id" => "edoc_signup_screens",
      "screens" => [
        %{"key" => "account", "title" => "Create your account", "nodes" => nodes}
      ]
    })
  end

  defp findings(nodes) do
    case Document.validate(document(nodes)) do
      {:ok, _document} -> []
      {:error, findings} -> Enum.map(findings, &{&1.code, &1.element_key, &1.field})
    end
  end

  defp email(overrides) do
    Map.merge(
      %{
        "type" => "text_question",
        "key" => "work_email",
        "label" => "Work email"
      },
      overrides
    )
  end

  defp plan(overrides) do
    Map.merge(
      %{
        "type" => "choice_question",
        "key" => "plan",
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

  defp newsletter(overrides) do
    Map.merge(
      %{
        "type" => "boolean_question",
        "key" => "newsletter",
        "label" => "Send me product news"
      },
      overrides
    )
  end

  defp questions(help) do
    [
      email(%{"help" => help}),
      plan(%{"help" => help}),
      newsletter(%{"help" => help})
    ]
  end

  describe "admission" do
    # Sabotage: removed :help from the text question's optional fields;
    # admission dropped it and this test went red. And again from the choice
    # question's and from the boolean question's.
    test "a text, choice or boolean question keeps its help as the document wrote it" do
      help = "We send it to {{ context.company_name }}."
      %Document{screens: [%{elements: nodes}]} = document(questions(help))

      assert Enum.map(nodes, &Map.fetch(&1, :help)) == [{:ok, help}, {:ok, help}, {:ok, help}]
      assert findings(questions(help)) == []
    end

    # The refusal's field names the construct, as any template field's does.
    #
    # Sabotage: removed :help from the document's template fields; no help
    # was refused and this test went red.
    test "a help holding a construct outside the template subset is document.invalid_template" do
      assert findings(questions("{{ context.first_name | strip_html }}")) == [
               {"document.invalid_template", "work_email", "strip_html"},
               {"document.invalid_template", "plan", "strip_html"},
               {"document.invalid_template", "newsletter", "strip_html"}
             ]
    end

    # Sabotage: removed :help from the boolean question's optional fields;
    # admission dropped the number and the boolean question's finding went
    # missing, and this test went red.
    test "a help that is not a string is document.invalid_template" do
      assert findings(questions(3)) == [
               {"document.invalid_template", "work_email", "help"},
               {"document.invalid_template", "plan", "help"},
               {"document.invalid_template", "newsletter", "help"}
             ]
    end
  end

  describe "resolution" do
    # Sabotage: removed :help from the choice question's optional fields;
    # the choice question resolved with no help and no missing variable, and
    # this test went red.
    test "help renders on every question type, and a variable the root lacks is reported under the question's key" do
      nodes = questions("Billed to {{ context.company_name }}{{ context.cost_center }}.")

      {:ok, screen, diagnostics} =
        Screens.resolve_screen(document(nodes), "account", %{
          "context" => %{"company_name" => "Acme"}
        })

      assert Enum.map(screen.elements, &Map.get(&1, :help)) ==
               List.duplicate("Billed to Acme.", 3)

      assert diagnostics.missing_variables == [
               %{key: "work_email", variable: "context.cost_center"},
               %{key: "plan", variable: "context.cost_center"},
               %{key: "newsletter", variable: "context.cost_center"}
             ]
    end

    # Sabotage: removed :help from the boolean question's optional fields;
    # the presented element carried no "help" and this test went red.
    test "a journey's presented question element carries its help rendered" do
      {:ok, %{"screen" => %{"elements" => nodes}}} =
        Journey.present(
          document(questions("Hello, {{ context.first_name }}.")),
          {:screen, "account"},
          %{"context" => %{"first_name" => "Ada"}}
        )

      assert Enum.map(nodes, & &1["help"]) == List.duplicate("Hello, Ada.", 3)
    end
  end
end
