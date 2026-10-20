defmodule Riddler.JourneyTest do
  use ExUnit.Case, async: true

  doctest Riddler.Journey

  alias Riddler.Journey
  alias Riddler.Screens.Document

  # The signup wizard: an account screen whose greeting reads a response, a
  # plan screen whose hint reads the host's context, and a plan button that
  # writes.
  @document %{
    "schema_version" => 1,
    "id" => "edoc_signup_journey",
    "screens" => [
      %{
        "key" => "account",
        "title" => "Create your account",
        "nodes" => [
          %{
            "type" => "text",
            "key" => "account_greeting",
            "condition" => "responses.first_name != ''",
            "text" => "Nice to meet you, {{ responses.first_name }}."
          },
          %{
            "type" => "text_question",
            "key" => "first_name",
            "label" => "First name",
            "required" => true
          }
        ]
      },
      %{
        "key" => "plan",
        "title" => "Pick a plan",
        "nodes" => [
          %{
            "type" => "text",
            "key" => "plan_hint",
            "text" => "Billed to {{ context.company }}."
          },
          %{
            "type" => "button",
            "key" => "plan_business",
            "label" => "Business",
            "outcome" => "plan_chosen",
            "writes" => %{"plan" => "business"}
          }
        ]
      }
    ]
  }

  setup do
    %{document: Document.admit(@document)}
  end

  describe "present/3 for a screen" do
    # Sabotage: answered the screen without putting it through the encoder,
    # so its keys stayed atoms; the string-keyed match failed and this test
    # went red.
    test "answers the resolved screen in data form, every key a string", %{document: document} do
      root = %{"responses" => %{"first_name" => "Ada"}}

      assert {:ok,
              %{
                "state" => "screen",
                "screen" => %{
                  "key" => "account",
                  "title" => "Create your account",
                  "nodes" => [
                    %{
                      "type" => "text",
                      "key" => "account_greeting",
                      "text" => "Nice to meet you, Ada."
                    },
                    %{
                      "type" => "text_question",
                      "key" => "first_name",
                      "label" => "First name",
                      "required" => true
                    }
                  ],
                  "diagnostics" => %{"missing_variables" => [], "undecidable_conditions" => []}
                }
              }} = Journey.present(document, {:screen, "account"}, root)
    end

    # Sabotage: answered the screen without its diagnostics, as the corpus
    # runner's single-screen path for resolution does; the answer carried no
    # "diagnostics" key and this test went red.
    test "carries the diagnostics of resolving that screen inside it", %{document: document} do
      assert {:ok, %{"screen" => screen}} = Journey.present(document, {:screen, "account"}, %{})

      assert screen["nodes"] |> Enum.map(& &1["key"]) == ["first_name"]

      assert screen["diagnostics"] == %{
               "missing_variables" => [],
               "undecidable_conditions" => [
                 %{"key" => "account_greeting", "condition" => "responses.first_name != ''"}
               ]
             }

      assert {:ok, %{"screen" => screen}} = Journey.present(document, {:screen, "plan"}, %{})

      assert screen["diagnostics"]["missing_variables"] == [
               %{"key" => "plan_hint", "variable" => "context.company"}
             ]
    end

    # Sabotage: dropped the writes from the encoded node; the button came back
    # without them and this test went red.
    test "carries a button's writes through untouched", %{document: document} do
      root = %{"context" => %{"company" => "Acme"}}

      assert {:ok, %{"screen" => %{"nodes" => [hint, button]}}} =
               Journey.present(document, {:screen, "plan"}, root)

      assert hint["text"] == "Billed to Acme."
      assert button["writes"] == %{"plan" => "business"}
      refute Map.has_key?(button, "condition")
    end

    # Sabotage: answered an undeclared key with a screen state and an empty
    # screen; the error was not returned and this test went red.
    test "refuses a key the document does not declare", %{document: document} do
      assert Journey.present(document, {:screen, "confirm"}, %{}) == {:error, :no_such_screen}
      assert Journey.present(document, {:screen, nil}, %{}) == {:error, :no_such_screen}
    end

    # Sabotage: folded the root's other keys into its context before
    # resolving; the third root key reached the template and this test went
    # red.
    test "reads the root for context and responses and nothing else", %{document: document} do
      root = %{"context" => %{}, "company" => "Acme"}

      assert {:ok, %{"screen" => %{"nodes" => [hint, _button]}}} =
               Journey.present(document, {:screen, "plan"}, root)

      assert hint["text"] == "Billed to ."
    end
  end

  describe "present/3 for waiting and done" do
    # Sabotage: made the waiting clause answer "done"; the state no longer
    # matched and this test went red.
    test "answers the state alone, with nothing beside it", %{document: document} do
      assert Journey.present(document, :waiting, %{}) == {:ok, %{"state" => "waiting"}}
      assert Journey.present(document, :done, %{}) == {:ok, %{"state" => "done"}}
    end

    # Sabotage: made the waiting clause answer {:error, :no_such_screen} for a
    # document declaring no screen; the empty document came back as an error
    # rather than the state and this test went red.
    test "does not read the document" do
      empty =
        Document.admit(%{"schema_version" => 1, "id" => "edoc_signup_empty", "screens" => []})

      assert Journey.present(empty, :waiting, %{}) == {:ok, %{"state" => "waiting"}}
      assert Journey.present(empty, :done, %{}) == {:ok, %{"state" => "done"}}
    end
  end

  describe "present/3 for a status outside the three" do
    # Sabotage: made the catch-all clause answer the waiting state; the first
    # status came back {:ok, %{"state" => "waiting"}} and this test went red.
    test "refuses it rather than raising", %{document: document} do
      for status <- [
            :card_issued,
            "waiting",
            {:screen},
            {:screen, "account", "extra"},
            {:waiting, "reason"},
            nil,
            %{"state" => "done"}
          ] do
        assert Journey.present(document, status, %{}) == {:error, :unknown_status},
               "expected #{inspect(status)} to be an unknown status"
      end
    end
  end

  describe "put_context/2" do
    # Sabotage: merged the new context into the old with Map.merge/2; the
    # withdrawn key survived and this test went red.
    test "replaces the context whole, so a key left out is gone" do
      root = %{"context" => %{"returning" => "yes", "card_pending" => true}}

      assert Journey.put_context(root, %{"returning" => "yes"}) ==
               {:ok, %{"context" => %{"returning" => "yes"}}}
    end

    # Sabotage: rebuilt the root as context and responses only; the third key
    # was dropped and this test went red.
    test "leaves the responses and every other key of the root as they were" do
      root = %{
        "context" => %{"returning" => "yes"},
        "responses" => %{"first_name" => "Ada"},
        "journey_note" => "kept"
      }

      assert {:ok, put} = Journey.put_context(root, %{})

      assert put == %{
               "context" => %{},
               "responses" => %{"first_name" => "Ada"},
               "journey_note" => "kept"
             }
    end

    # Sabotage: answered {:ok, root} unchanged when the root had no context;
    # the context was not added and this test went red.
    test "gives a root with no context one" do
      assert Journey.put_context(%{}, %{"returning" => "no"}) ==
               {:ok, %{"context" => %{"returning" => "no"}}}
    end

    # Sabotage: dropped the is_struct guard; a struct was put as the context
    # and this test went red.
    test "refuses a context that is not a plain map" do
      root = %{"context" => %{"returning" => "yes"}}

      for context <- [nil, "returning", ["returning", "yes"], 1, URI.parse("https://example.com")] do
        assert Journey.put_context(root, context) == {:error, :context_not_a_map},
               "expected #{inspect(context)} to be refused"
      end
    end
  end
end
