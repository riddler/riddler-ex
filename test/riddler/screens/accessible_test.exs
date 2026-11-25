defmodule Riddler.Screens.AccessibleTest do
  use ExUnit.Case, async: true

  alias Riddler.Journey
  alias Riddler.Screens
  alias Riddler.Screens.Document
  alias Riddler.Screens.Registry

  @pair %{
    "accessible_label" => "Create your {{ context.tenant_name }} account",
    "accessible_description" => "The first of three steps."
  }

  defp raw(elements) do
    %{
      "schema_version" => 2,
      "id" => "edoc_signup_screens",
      "screens" => [
        %{"key" => "account", "title" => "Create your account", "elements" => elements}
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

  defp root(context), do: %{"context" => context, "responses" => %{}}

  # One element of each type the registry names, each valid on its own.
  defp every_type do
    [
      %{"type" => "heading", "key" => "account_heading", "level" => 1, "text" => "Welcome"},
      %{"type" => "text", "key" => "account_intro", "text" => "It takes a minute."},
      %{"type" => "image", "key" => "acme_logo", "src" => "/images/acme.png", "alt" => ""},
      %{"type" => "divider", "key" => "account_rule"},
      %{
        "type" => "link",
        "key" => "billing_terms",
        "label" => "Read the billing terms",
        "href" => "https://acme.example/terms"
      },
      %{"type" => "text_question", "key" => "work_email", "label" => "Work email"},
      %{
        "type" => "choice_question",
        "key" => "plan_choice",
        "label" => "Which plan?",
        "select" => "one",
        "answer_options" => [%{"value" => "personal", "label" => "Personal"}]
      },
      %{"type" => "boolean_question", "key" => "accepts_terms", "label" => "I accept"},
      %{"type" => "secret_question", "key" => "account_pin", "label" => "Choose a PIN"},
      %{
        "type" => "variant",
        "key" => "welcome_variant",
        "elements" => [%{"type" => "text", "key" => "welcome_a", "text" => "Welcome."}]
      },
      %{
        "type" => "button",
        "key" => "account_next",
        "label" => "Continue",
        "outcome" => "account_created"
      }
    ]
  end

  describe "at admit" do
    # Sabotage: removed the accessible fields from the fields every element
    # carries; the admitted elements carried neither and this test went red.
    test "every type carries the pair, and the list covers every registered type" do
      elements = Enum.map(every_type(), &Map.merge(&1, @pair))

      assert Enum.sort(Enum.map(elements, & &1["type"])) == Enum.sort(Registry.types())
      assert findings(elements) == []

      for element <- hd(document(elements).screens).elements do
        assert %{
                 accessible_label: "Create your {{ context.tenant_name }} account",
                 accessible_description: "The first of three steps."
               } = element,
               element.type
      end
    end

    # Sabotage: removed the accessible fields from the template list; a value
    # that is not a string and a refused construct were each admitted with no
    # finding and this test went red.
    test "each is a template: a value that is not a string, or a construct outside the subset, is refused" do
      for field <- ["accessible_label", "accessible_description"], bad <- [3, nil, ["a"]] do
        element = %{"type" => "divider", "key" => "account_rule", field => bad}

        assert findings([element]) == [{"document.invalid_template", "account_rule", field}],
               inspect({field, bad})
      end

      element = %{
        "type" => "text",
        "key" => "account_intro",
        "text" => "Hello.",
        "accessible_description" => "{% include 'footer' %}"
      }

      assert findings([element]) == [{"document.invalid_template", "account_intro", "include"}]
    end

    # Sabotage: same mutation as above; the template naming the secret
    # question's response raised no secret reference and this test went red.
    test "a template naming a secret question's response is refused" do
      elements = [
        %{"type" => "secret_question", "key" => "account_pin", "label" => "Choose a PIN"},
        %{
          "type" => "text",
          "key" => "pin_note",
          "text" => "Keep it safe.",
          "accessible_label" => "Your PIN is {{ responses.account_pin }}"
        }
      ]

      assert findings(elements) == [{"document.secret_reference", "pin_note", "accessible_label"}]
    end
  end

  describe "at resolve and present" do
    # Sabotage: removed the accessible fields from the template list; the
    # resolved pair kept its template source and this test went red.
    test "the pair is rendered on every type that resolves, a variant carrying its winner's" do
      elements =
        Enum.map(every_type(), fn
          %{"type" => "variant"} = variant ->
            update_in(variant, ["elements"], fn [winner] -> [Map.merge(winner, @pair)] end)
            |> Map.put("accessible_label", "Not carried")

          element ->
            Map.merge(element, @pair)
        end)

      {:ok, screen, diagnostics} =
        Screens.resolve_screen(document(elements), "account", root(%{"tenant_name" => "Acme"}))

      assert diagnostics.missing_variables == []
      assert length(screen.elements) == length(elements)

      for element <- screen.elements do
        assert %{
                 accessible_label: "Create your Acme account",
                 accessible_description: "The first of three steps."
               } = element,
               element.type
      end
    end

    # Sabotage: made the variant's winner take the variant's accessible fields
    # under its own; the winner carried the variant's description and this
    # test went red.
    test "a variant's own pair is carried nowhere" do
      variant = %{
        "type" => "variant",
        "key" => "welcome_variant",
        "accessible_label" => "Not carried",
        "accessible_description" => "Not carried either",
        "elements" => [%{"type" => "text", "key" => "welcome_a", "text" => "Welcome."}]
      }

      {:ok, screen, _diagnostics} =
        Screens.resolve_screen(document([variant]), "account", root(%{}))

      assert [%{type: "text", key: "welcome_a"} = winner] = screen.elements
      refute Map.has_key?(winner, :accessible_label)
      refute Map.has_key?(winner, :accessible_description)
    end

    # Sabotage: made resolution put an empty accessible_label on every
    # element; the elements that wrote none carried one and this test went red.
    test "a document that uses neither presents as before, every element without the pair" do
      {:ok, answer} =
        Journey.present(document(every_type()), {:screen, "account"}, root(%{}))

      for element <- answer["screen"]["elements"] do
        refute Map.has_key?(element, "accessible_label"), element["type"]
        refute Map.has_key?(element, "accessible_description"), element["type"]
      end
    end

    # Sabotage: typed accessible_label as an integer on the heading in the
    # presented-answer schema; the presented heading failed validation and
    # this test went red. And again with the divider's pair left untyped; the
    # divider carrying a number validated.
    test "a presented pair validates against the presented-answer schema, and a pair that is not a string does not" do
      schema =
        "priv/schemas/presented-answer.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()

      elements = Enum.map(every_type(), &Map.merge(&1, @pair))

      {:ok, answer} =
        Journey.present(
          document(elements),
          {:screen, "account"},
          root(%{"tenant_name" => "Acme"})
        )

      assert ExJsonSchema.Validator.valid?(schema, answer)

      presented = answer["screen"]["elements"]

      for {element, at} <- Enum.with_index(presented),
          field <- ["accessible_label", "accessible_description"] do
        broken = List.replace_at(presented, at, Map.put(element, field, 3))

        refute ExJsonSchema.Validator.valid?(
                 schema,
                 put_in(answer, ["screen", "elements"], broken)
               ),
               inspect({element["type"], field})
      end
    end
  end
end
