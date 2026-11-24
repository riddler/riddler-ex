defmodule Riddler.Screens.ContextOptionsTest do
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

  defp plan(overrides) do
    Map.merge(
      %{
        "type" => "choice_question",
        "key" => "plan",
        "label" => "Which plan?",
        "select" => "one",
        "answer_options_from" => "context.account.plans"
      },
      overrides
    )
  end

  defp authored, do: [%{"value" => "personal", "label" => "Personal"}]

  @plans [
    %{"value" => "personal", "label" => "Personal", "price" => 0},
    %{"value" => "business", "label" => "Business"}
  ]

  defp root(plans, responses \\ %{}),
    do: %{"context" => %{"account" => %{"plans" => plans}}, "responses" => responses}

  defp resolved(nodes, root) do
    {:ok, screen, diagnostics} = Screens.resolve_screen(document(nodes), "account", root)
    {screen.elements, diagnostics}
  end

  describe "admission" do
    # Sabotage: dropped answer_options_from from the choice question's
    # fields; admission dropped the path, the question was missing its
    # options and this test went red.
    test "a choice question naming a context path for its options in place of answer_options is admitted" do
      assert findings([plan(%{})]) == []

      assert [%{answer_options_from: "context.account.plans"}] =
               hd(document([plan(%{})]).screens).elements
    end

    # Sabotage: made the document's required-field check skip answer_options
    # on every choice question; the question carrying neither field raised
    # nothing and this test went red.
    test "a choice question carrying neither is still missing answer_options" do
      assert findings([Map.delete(plan(%{}), "answer_options_from")]) == [
               {"document.missing_field", "plan", "answer_options"}
             ]
    end

    # Sabotage: removed the conflict check; the question carrying both raised
    # nothing and this test went red.
    test "a choice question carrying both is refused as conflicting options, and only so" do
      assert findings([plan(%{"answer_options" => authored()})]) == [
               {"document.conflicting_options", "plan", "answer_options_from"}
             ]
    end

    # Sabotage: dropped the path check from the choice question; the bare
    # context path raised nothing and this test went red.
    test "an answer_options_from is a dotted path of key-shaped segments under context" do
      for path <- [
            "account.plans",
            "context",
            "context.Account",
            "context.plans\n",
            ["context"],
            nil
          ] do
        assert findings([plan(%{"answer_options_from" => path})]) ==
                 [{"document.invalid_context_path", "plan", "answer_options_from"}],
               "path #{inspect(path)}"
      end
    end

    # Sabotage: dropped the context-options test from the default check; the
    # empty list under many fit the no authored options and raised nothing,
    # and this test went red.
    test "a default on a choice question that reads its options from context is refused" do
      assert findings([plan(%{"default" => "personal"})]) == [
               {"document.invalid_default", "plan", "default"}
             ]

      assert findings([plan(%{"select" => "many", "default" => []})]) == [
               {"document.invalid_default", "plan", "default"}
             ]
    end

    # Sabotage: compared the selection bounds with a count of zero options
    # where the question carries no answer_options; the bound of two raised
    # a finding and this test went red.
    test "selection bounds are not compared with a number of options at admit" do
      assert findings([plan(%{"select" => "many", "min_selections" => 1, "max_selections" => 2})]) ==
               []
    end

    # Sabotage: added answer_options_from to the text question's fields; the
    # admitted text question carried the path and this test went red.
    test "an answer_options_from on a question type that does not name it is dropped with no finding" do
      text = %{
        "type" => "text_question",
        "key" => "work_email",
        "label" => "Work email",
        "answer_options_from" => "context.account.plans"
      }

      assert findings([text]) == []
      refute Map.has_key?(hd(hd(document([text]).screens).elements), :answer_options_from)
    end
  end

  describe "resolution" do
    # Sabotage: kept every key of an option read from context; the price
    # rode on the resolved option and this test went red.
    test "the options are read from context, each its value and its label, in the list's order" do
      assert {[node], %{missing_variables: []}} = resolved([plan(%{})], root(@plans))

      assert node.answer_options == [
               %{value: "personal", label: "Personal"},
               %{value: "business", label: "Business"}
             ]

      refute Map.has_key?(node, :answer_options_from)
    end

    # Sabotage: read the options before the node's templates were rendered;
    # the host's label was rendered as a template and this test went red.
    test "an option's label read from context is the host's text and is not rendered" do
      plans = [%{"value" => "business", "label" => "Business for {{ context.company }}"}]
      root = put_in(root(plans), ["context", "company"], "Acme")

      assert {[node], %{missing_variables: []}} = resolved([plan(%{})], root)

      assert node.answer_options == [
               %{value: "business", label: "Business for {{ context.company }}"}
             ]
    end

    # Sabotage: resolved a path that read no list of options to no options
    # without reporting it; the diagnostics came back empty and this test
    # went red.
    test "a path reaching no list of options resolves to none and is reported, the path as written" do
      for context <- [
            %{},
            %{"account" => "personal"},
            %{"account" => %{"plans" => "personal"}},
            %{"account" => %{"plans" => [%{"value" => "personal"}]}},
            %{"account" => %{"plans" => [%{"value" => "Personal", "label" => "Personal"}]}},
            %{"account" => %{"plans" => [%{"value" => 1, "label" => "Personal"}]}},
            %{"account" => %{"plans" => ["personal"]}},
            %{"account" => %{"plans" => @plans ++ [hd(@plans)]}}
          ] do
        assert {[node], diagnostics} = resolved([plan(%{})], %{"context" => context})
        assert node.answer_options == [], inspect(context)

        assert diagnostics.missing_variables == [
                 %{key: "plan", variable: "context.account.plans"}
               ],
               inspect(context)
      end
    end

    # Sabotage: reported an empty list at the path as a path reaching
    # nothing; the diagnostics carried the path and this test went red.
    test "an empty list at the path is a question with no options, and is not reported" do
      assert {[node], %{missing_variables: []}} = resolved([plan(%{})], root([]))
      assert node.answer_options == []
    end

    # Sabotage: let the path win over the authored options; the question
    # carrying both showed the context's options and this test went red.
    test "a question carrying both, which no one validated, keeps its authored options" do
      assert {[node], %{missing_variables: []}} =
               resolved([plan(%{"answer_options" => authored()})], root(@plans))

      assert node.answer_options == [%{value: "personal", label: "Personal"}]
      refute Map.has_key?(node, :answer_options_from)
    end

    # Sabotage: let the path be read where the authored list is nil; the
    # options came from the context, not nil, and this test went red.
    test "a nil authored list beside a path, on a document no one validated, stays nil and reads nothing" do
      validated = document([plan(%{"answer_options" => authored()})])
      [screen] = validated.screens
      [node] = screen.elements

      unvalidated = %{
        validated
        | screens: [%{screen | elements: [%{node | answer_options: nil}]}]
      }

      assert {:ok, resolved, %{missing_variables: []}} =
               Screens.resolve_screen(unvalidated, "account", root(@plans))

      assert [%{answer_options: nil} = presented] = resolved.elements
      refute Map.has_key?(presented, :answer_options_from)
    end

    # Sabotage: presented the node before its options were read from context;
    # the prefill among the context's options was not presented and this test
    # went red.
    test "a prefill is presented where it is among the options the context holds" do
      node = plan(%{"prefill" => "context.account.plan"})
      prefilled = fn plan -> put_in(root(@plans), ["context", "account", "plan"], plan) end

      assert {[%{value: "business"}], _diagnostics} = resolved([node], prefilled.("business"))
      assert {[presented], _diagnostics} = resolved([node], prefilled.("team"))
      refute Map.has_key?(presented, :value)
    end

    # Sabotage: made the context read a no-op; the presented node carried the
    # path and no options, and this test went red.
    test "a journey's presented question carries the options as data" do
      {:ok, %{"screen" => %{"nodes" => [node]}}} =
        Journey.present(document([plan(%{})]), {:screen, "account"}, root(@plans))

      assert node["answer_options"] == [
               %{"value" => "personal", "label" => "Personal"},
               %{"value" => "business", "label" => "Business"}
             ]

      refute Map.has_key?(node, "answer_options_from")
    end
  end

  describe "response validation" do
    # Sabotage: made the context read a no-op, so the question was validated
    # against no options; the response the context offers was refused and
    # this test went red.
    test "a response is checked against the options the context holds at submit" do
      nodes = [plan(%{"required" => true})]

      assert Screens.validate_screen(
               document(nodes),
               "account",
               root(@plans, %{"plan" => "business"})
             ) ==
               :ok

      assert {:error, [finding]} =
               Screens.validate_screen(
                 document(nodes),
                 "account",
                 root([hd(@plans)], %{"plan" => "business"})
               )

      assert {finding.code, finding.element_key, finding.field} ==
               {"response.not_an_option", "plan", "answer_options"}
    end

    # Sabotage: let response validation accept any value on a choice question
    # whose options are empty; the stray value was accepted and this test went
    # red.
    test "a question whose path reached no options refuses any value as not an option" do
      assert {:error, [finding]} =
               Screens.validate_screen(document([plan(%{})]), "account", %{
                 "responses" => %{"plan" => "personal"}
               })

      assert finding.code == "response.not_an_option"
    end
  end
end
