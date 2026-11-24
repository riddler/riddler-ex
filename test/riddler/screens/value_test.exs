defmodule Riddler.Screens.ValueTest do
  use ExUnit.Case, async: true

  alias Riddler.Journey
  alias Riddler.Screens
  alias Riddler.Screens.Document

  defp document(nodes) do
    Document.admit(%{
      "schema_version" => 1,
      "id" => "edoc_signup_screens",
      "screens" => [%{"key" => "account", "title" => "Create your account", "nodes" => nodes}]
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
      %{"type" => "text_question", "key" => "work_email", "label" => "Work email"},
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

  defp addons(overrides) do
    plan(
      Map.merge(%{"key" => "addons", "label" => "Which add-ons?", "select" => "many"}, overrides)
    )
  end

  defp newsletter(overrides) do
    Map.merge(
      %{"type" => "boolean_question", "key" => "newsletter", "label" => "Send me product news"},
      overrides
    )
  end

  defp resolved(nodes, root) do
    {:ok, screen, diagnostics} = Screens.resolve_screen(document(nodes), "account", root)
    {screen.elements, diagnostics}
  end

  defp values(nodes, root) do
    {resolved, _diagnostics} = resolved(nodes, root)
    Enum.map(resolved, &Map.fetch(&1, :value))
  end

  describe "admission" do
    # Sabotage: made a text question's default fit whatever its shape; the
    # number default raised no finding and this test went red.
    test "a default of the question's response shape is admitted, and another is refused" do
      assert findings([
               email(%{"default" => ""}),
               plan(%{"default" => "business"}),
               newsletter(%{"default" => false})
             ]) == []

      assert findings([
               email(%{"default" => 2}),
               plan(%{"default" => ["business"]}),
               newsletter(%{"default" => "yes"})
             ]) == [
               {"document.invalid_default", "work_email", "default"},
               {"document.invalid_default", "plan", "default"},
               {"document.invalid_default", "newsletter", "default"}
             ]
    end

    # Sabotage: dropped the authored-options test from a choice default's
    # fit; the default naming no option raised nothing and this test went
    # red.
    test "a choice question's default names its own options, each once under many" do
      assert findings([addons(%{"default" => ["personal", "business"]})]) == []
      assert findings([addons(%{"default" => []})]) == []

      assert findings([
               plan(%{"default" => "enterprise"}),
               addons(%{"default" => ["personal", "personal"]})
             ]) == [
               {"document.invalid_default", "plan", "default"},
               {"document.invalid_default", "addons", "default"}
             ]
    end

    # Sabotage: removed the readable-shape test from the default check; the
    # unreadable select's default was refused as well and this test went red.
    test "a choice question's default is not checked where its select is neither one nor many" do
      assert findings([plan(%{"select" => "several", "default" => 7})]) == [
               {"document.invalid_select", "plan", "select"}
             ]
    end

    # Sabotage: let a path naming context alone through as a path under it;
    # the bare context prefill raised no finding and this test went red.
    test "a prefill is a dotted path of key-shaped segments under context" do
      assert findings([email(%{"prefill" => "context.account.invited_email"})]) == []

      for prefill <- [
            "responses.work_email",
            "context",
            "context.",
            "context.Account.email",
            "context.account.email\n",
            ["context", "email"],
            nil
          ] do
        assert findings([email(%{"prefill" => prefill})]) ==
                 [{"document.invalid_context_path", "work_email", "prefill"}],
               "prefill #{inspect(prefill)}"
      end
    end

    # Sabotage: made the secret question's validate/1 raise the shared default
    # and prefill findings too; its default came back with a second finding
    # and this test went red.
    test "a secret question's default or prefill is still refused as an initial value, and only so" do
      secret = %{
        "type" => "secret_question",
        "key" => "account_pin",
        "label" => "Choose a PIN",
        "default" => 7,
        "prefill" => "nowhere"
      }

      assert findings([secret]) == [
               {"document.secret_initial_value", "account_pin", "default"},
               {"document.secret_initial_value", "account_pin", "prefill"}
             ]
    end
  end

  describe "the presented value" do
    @context %{"invited_email" => "ada@example.com", "account" => %{"seats" => 3}}
    defp full, do: email(%{"prefill" => "context.invited_email", "default" => "team@example.com"})

    # Sabotage: tried the prefill before the response the root holds; the
    # held response lost to the prefill and this test went red.
    test "a response the root holds wins, then the prefill, then the default" do
      root = fn responses -> %{"context" => @context, "responses" => responses} end

      assert values([full()], root.(%{"work_email" => "grace@example.com"})) ==
               [{:ok, "grace@example.com"}]

      assert values([full()], root.(%{"work_email" => nil})) == [{:ok, "ada@example.com"}]
      assert values([full()], root.(%{})) == [{:ok, "ada@example.com"}]
      assert values([full()], %{}) == [{:ok, "team@example.com"}]
      assert values([full()], root.(%{"work_email" => 42})) == [{:ok, 42}]
    end

    # Sabotage: presented the prefill's value without putting it to the
    # question's shape; the seat count was presented as the email and this
    # test went red.
    test "a prefill that reaches nothing, passes a non-object or reaches the wrong shape yields nothing, and is reported nowhere" do
      for prefill <- [
            "context.account.work_email",
            "context.invited_email.domain",
            "context.account.seats"
          ] do
        nodes = [
          email(%{"prefill" => prefill, "default" => "team@example.com"}),
          email(%{"key" => "billing_email", "prefill" => prefill})
        ]

        assert {[first, second], %{missing_variables: [], undecidable_conditions: []}} =
                 resolved(nodes, %{"context" => @context})

        assert first.value == "team@example.com"
        refute Map.has_key?(second, :value)
      end
    end

    # Sabotage: left default and prefill on the presented node; the resolved
    # question carried both and this test went red.
    test "a resolved question carries no default and no prefill" do
      {[node], _diagnostics} = resolved([full()], %{})

      refute Map.has_key?(node, :default)
      refute Map.has_key?(node, :prefill)
    end

    # Sabotage: dropped the authored-options test from the presented value's
    # fit; the prefill naming no option was presented and this test went red.
    test "a choice question presents a prefill or a default only among its options" do
      context = %{"account" => %{"plan" => "enterprise", "addons" => ["business"]}}

      assert values(
               [
                 plan(%{"prefill" => "context.account.plan", "default" => "personal"}),
                 addons(%{"prefill" => "context.account.addons", "default" => ["personal"]}),
                 addons(%{"key" => "extras", "prefill" => "context.account.plan"})
               ],
               %{"context" => context}
             ) == [{:ok, "personal"}, {:ok, ["business"]}, :error]
    end

    # Sabotage: presented a boolean question's default without putting it to
    # the question's shape; the string default was presented and this test
    # went red.
    test "a boolean question presents true or false, and a default of another shape not at all" do
      assert values(
               [
                 newsletter(%{"default" => false}),
                 newsletter(%{"key" => "reminders", "default" => "yes"})
               ],
               %{}
             ) == [{:ok, false}, :error]
    end

    # Sabotage: skipped the presented value for every question type; the
    # journey's question node came back without "value" and this test went
    # red.
    test "a journey's presented question node carries the value as data" do
      {:ok, %{"screen" => %{"nodes" => [node]}}} =
        Journey.present(document([full()]), {:screen, "account"}, %{"context" => @context})

      assert node["value"] == "ada@example.com"
      refute Map.has_key?(node, "prefill")
    end

    # Sabotage: made response validation read a question's presented value
    # when the root holds no response for it; the required question showing
    # its default validated and this test went red.
    test "a presented value is not a response: a required question showing one is unanswered" do
      nodes = [Map.put(full(), "required", true)]

      assert {:error, [finding]} =
               Screens.validate_screen(document(nodes), "account", %{"context" => @context})

      assert {finding.code, finding.element_key} == {"response.required", "work_email"}
    end
  end
end
