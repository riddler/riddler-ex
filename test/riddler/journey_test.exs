defmodule Riddler.JourneyTest do
  use ExUnit.Case, async: true

  doctest Riddler.Journey

  alias Riddler.Journey
  alias Riddler.Screens.Document

  # Patron registration: a details screen whose greeting reads a response,
  # and a pickup screen whose hint reads the host's context and whose button
  # writes.
  @document %{
    "schema_version" => 1,
    "id" => "patron_registration",
    "screens" => [
      %{
        "key" => "patron_details",
        "title" => "Get your library card",
        "nodes" => [
          %{
            "type" => "text",
            "key" => "details_greeting",
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
        "key" => "card_pickup",
        "title" => "Pick up your card",
        "nodes" => [
          %{
            "type" => "text",
            "key" => "pickup_hint",
            "text" => "Collect your card at {{ context.branch_name }}."
          },
          %{
            "type" => "button",
            "key" => "card_adult",
            "label" => "Adult card",
            "outcome" => "card_chosen",
            "writes" => %{"responses.card_type" => ["const", "adult"]}
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
                  "key" => "patron_details",
                  "title" => "Get your library card",
                  "nodes" => [
                    %{
                      "type" => "text",
                      "key" => "details_greeting",
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
              }} = Journey.present(document, {:screen, "patron_details"}, root)
    end

    # Sabotage: answered the screen without its diagnostics, as the corpus
    # runner's single-screen path for resolution does; the answer carried no
    # "diagnostics" key and this test went red.
    test "carries the diagnostics of resolving that screen inside it", %{document: document} do
      assert {:ok, %{"screen" => screen}} =
               Journey.present(document, {:screen, "patron_details"}, %{})

      assert screen["nodes"] |> Enum.map(& &1["key"]) == ["first_name"]

      assert screen["diagnostics"] == %{
               "missing_variables" => [],
               "undecidable_conditions" => [
                 %{"key" => "details_greeting", "condition" => "responses.first_name != ''"}
               ]
             }

      assert {:ok, %{"screen" => screen}} =
               Journey.present(document, {:screen, "card_pickup"}, %{})

      assert screen["diagnostics"]["missing_variables"] == [
               %{"key" => "pickup_hint", "variable" => "context.branch_name"}
             ]
    end

    # Sabotage: dropped the writes from the encoded node; the button came back
    # without them and this test went red.
    test "carries a button's writes through untouched", %{document: document} do
      root = %{"context" => %{"branch_name" => "Central"}}

      assert {:ok, %{"screen" => %{"nodes" => [hint, button]}}} =
               Journey.present(document, {:screen, "card_pickup"}, root)

      assert hint["text"] == "Collect your card at Central."
      assert button["writes"] == %{"responses.card_type" => ["const", "adult"]}
      refute Map.has_key?(button, "condition")
    end

    # Sabotage: answered an undeclared key with a screen state and an empty
    # screen; the error was not returned and this test went red.
    test "refuses a key the document does not declare", %{document: document} do
      assert Journey.present(document, {:screen, "card_renewal"}, %{}) ==
               {:error, :no_such_screen}

      assert Journey.present(document, {:screen, nil}, %{}) == {:error, :no_such_screen}
    end

    # Sabotage: folded the root's other keys into its context before
    # resolving; the third root key reached the template and this test went
    # red.
    test "reads the root for context and responses and nothing else", %{document: document} do
      root = %{"context" => %{}, "branch_name" => "Central"}

      assert {:ok, %{"screen" => %{"nodes" => [hint, _button]}}} =
               Journey.present(document, {:screen, "card_pickup"}, root)

      assert hint["text"] == "Collect your card at ."
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
        Document.admit(%{
          "schema_version" => 1,
          "id" => "patron_registration_empty",
          "screens" => []
        })

      assert Journey.present(empty, :waiting, %{}) == {:ok, %{"state" => "waiting"}}
      assert Journey.present(empty, :done, %{}) == {:ok, %{"state" => "done"}}
    end
  end

  describe "present/3 for waiting with info" do
    # Sabotage: made the waiting info clause drop "retry_after_ms" from the
    # answer; the first answer came back with the reason alone and this test
    # went red.
    test "answers the reason and the retry hint beside the state, each only where supplied",
         %{document: document} do
      assert Journey.present(
               document,
               {:waiting, %{"reason" => "card_number_pending", "retry_after_ms" => 5000}},
               %{}
             ) ==
               {:ok,
                %{
                  "state" => "waiting",
                  "reason" => "card_number_pending",
                  "retry_after_ms" => 5000
                }}

      assert Journey.present(document, {:waiting, %{"reason" => "card_number_pending"}}, %{}) ==
               {:ok, %{"state" => "waiting", "reason" => "card_number_pending"}}

      assert Journey.present(document, {:waiting, %{"retry_after_ms" => 0}}, %{}) ==
               {:ok, %{"state" => "waiting", "retry_after_ms" => 0}}
    end

    # Sabotage: made the waiting info clause carry every key of the info onto
    # the answer; the unread key reached it and this test went red.
    test "answers an info carrying neither key exactly as the bare waiting status",
         %{document: document} do
      bare = Journey.present(document, :waiting, %{})

      assert Journey.present(document, {:waiting, %{}}, %{}) == bare
      assert Journey.present(document, {:waiting, %{"queue_position" => 3}}, %{}) == bare

      assert Journey.present(document, {:waiting, %{reason: "card_number_pending"}}, %{}) == bare
    end

    # Sabotage: made `retry_after_ms` accept any integer, below zero included;
    # the -1 hint came back as an answer and this test went red. And again
    # with the reason check accepting any value; the integer reason came back
    # as an answer and this test went red. And again with the map guard
    # dropping `not is_struct/1`; the struct came back as an answer and this
    # test went red.
    test "refuses an info that is not a map or carries a named key of the wrong type",
         %{document: document} do
      for info <- [
            "card_number_pending",
            nil,
            [{"reason", "card_number_pending"}],
            %{"reason" => 42},
            %{"reason" => nil},
            %{"reason" => :card_number_pending},
            %{"retry_after_ms" => -1},
            %{"retry_after_ms" => 1.5},
            %{"retry_after_ms" => "5000"},
            %{"reason" => "card_number_pending", "retry_after_ms" => -1},
            URI.parse("https://example.com")
          ] do
        assert Journey.present(document, {:waiting, info}, %{}) == {:error, :unknown_status},
               "expected #{inspect(info)} to be refused"
      end
    end

    # Sabotage: made the waiting info clause match only a document declaring
    # a screen; the document declaring none fell through to
    # {:error, :unknown_status} and this test went red.
    test "does not read the document" do
      empty =
        Document.admit(%{
          "schema_version" => 1,
          "id" => "patron_registration_empty",
          "screens" => []
        })

      assert Journey.present(empty, {:waiting, %{"reason" => "card_number_pending"}}, %{}) ==
               {:ok, %{"state" => "waiting", "reason" => "card_number_pending"}}
    end
  end

  describe "present/3 for done with a result" do
    # Sabotage: made the done result clause answer the done state alone; the
    # result was missing from the answer and this test went red.
    test "answers the result whole beside the state", %{document: document} do
      result = %{
        "card_number" => "EXAMPLE-CARD-0001",
        "pickup" => %{"branch_name" => "Central Library", "ready" => true},
        "reminders" => ["email", "post"],
        "guardian" => nil
      }

      assert Journey.present(document, {:done, result}, %{}) ==
               {:ok, %{"state" => "done", "result" => result}}
    end

    # Sabotage: made the done result clause carry the result as the host
    # passed it, without the data form; the atom key and the atom value came
    # back as atoms and this test went red. And again with the struct inside
    # left as a struct; it came back as a struct and this test went red. And
    # again with only the top level encoded; the nested atom and struct came
    # back as they were and this test went red.
    test "carries the result in the answer's data form", %{document: document} do
      result = %{
        "status" => :issued,
        "pickup_url" => URI.parse("https://example.com/pickup"),
        "pickup" => %{branch: :central, links: [URI.parse("https://example.com/hours")]},
        card_number: "EXAMPLE-CARD-0001"
      }

      assert {:ok, %{"state" => "done", "result" => carried}} =
               Journey.present(document, {:done, result}, %{})

      assert carried["card_number"] == "EXAMPLE-CARD-0001"
      assert carried["status"] == "issued"
      assert %{"host" => "example.com", "path" => "/pickup"} = carried["pickup_url"]
      refute is_struct(carried["pickup_url"])
      assert %{"branch" => "central", "links" => [link]} = carried["pickup"]
      assert %{"host" => "example.com", "path" => "/hours"} = link
      refute is_struct(link)
    end

    # Sabotage: made the done result clause drop an empty result to the bare
    # done answer; the "result" key was missing and this test went red.
    test "answers an empty result as an empty map, and the bare done form unchanged",
         %{document: document} do
      assert Journey.present(document, {:done, %{}}, %{}) ==
               {:ok, %{"state" => "done", "result" => %{}}}

      assert Journey.present(document, :done, %{}) == {:ok, %{"state" => "done"}}
    end

    # Sabotage: made the done result clause's guard accept any term; the
    # string result came back as an answer and this test went red. And again
    # with the guard dropping `not is_struct/1`; the struct came back as an
    # answer and this test went red.
    test "refuses a result that is not a map", %{document: document} do
      for result <- [
            "EXAMPLE-CARD-0001",
            nil,
            12,
            ["EXAMPLE-CARD-0001"],
            [{"card_number", "EXAMPLE-CARD-0001"}],
            :issued,
            URI.parse("https://example.com")
          ] do
        assert Journey.present(document, {:done, result}, %{}) == {:error, :unknown_status},
               "expected #{inspect(result)} to be refused"
      end
    end

    # Sabotage: made the done result clause match only a document declaring
    # a screen; the document declaring none fell through to
    # {:error, :unknown_status} and this test went red.
    test "does not read the document" do
      empty =
        Document.admit(%{
          "schema_version" => 1,
          "id" => "patron_registration_empty",
          "screens" => []
        })

      assert Journey.present(empty, {:done, %{"card_number" => "EXAMPLE-CARD-0001"}}, %{}) ==
               {:ok, %{"state" => "done", "result" => %{"card_number" => "EXAMPLE-CARD-0001"}}}
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
            {:screen, "patron_details", "extra"},
            {:waiting, "reason"},
            nil,
            %{"state" => "done"}
          ] do
        assert Journey.present(document, status, %{}) == {:error, :unknown_status},
               "expected #{inspect(status)} to be an unknown status"
      end
    end
  end

  describe "decode_submit/1" do
    @submit %{
      "screen" => "account",
      "outcome" => "account_created",
      "responses" => %{"email" => "sam@example.com"}
    }

    # Sabotage: answered {:ok, submit} with the map as sent rather than
    # taking the three keys; the further key was carried and this test went
    # red.
    test "answers the three keys as sent and drops a key beside them" do
      assert Journey.decode_submit(Map.put(@submit, "variant", "b")) == {:ok, @submit}

      assert Journey.decode_submit(%{@submit | "responses" => %{}}) ==
               {:ok, %{@submit | "responses" => %{}}}
    end

    # Sabotage: dropped the is_struct guard from the map clause; the URI was
    # checked key by key and came back with three missing-field findings, and
    # this test went red.
    test "refuses a value that is not a map, a struct included, with one finding" do
      for submit <- [nil, "account", 1, ["account"], {:account}, URI.parse("https://example.com")] do
        assert {:error, [finding]} = Journey.decode_submit(submit)

        assert %Riddler.Finding{code: "submit.not_an_object", field: nil, node_key: nil} =
                 finding

        assert is_binary(finding.message)
      end
    end

    # Sabotage: checked the keys in the order responses, outcome, screen; the
    # findings came back reversed and this test went red.
    test "reports every missing key, in the order screen, outcome, responses" do
      assert {:error, findings} = Journey.decode_submit(%{"variant" => "b"})

      assert Enum.map(findings, &{&1.code, &1.field, &1.node_key, &1.position}) == [
               {"submit.missing_field", "screen", nil, nil},
               {"submit.missing_field", "outcome", nil, nil},
               {"submit.missing_field", "responses", nil, nil}
             ]
    end

    # Sabotage: made the responses check is_map/1 alone; the struct passed as
    # responses was accepted and this test went red. And again with the check
    # letting nil through; the null responses were accepted and it went red.
    test "reports a screen or outcome that is not a string and responses that are not a map" do
      for {key, value} <- [
            {"screen", nil},
            {"screen", :account},
            {"outcome", 3},
            {"outcome", ["account_created"]},
            {"responses", ["sam@example.com"]},
            {"responses", nil},
            {"responses", "sam@example.com"},
            {"responses", URI.parse("https://example.com")}
          ] do
        assert {:error, [finding]} = Journey.decode_submit(Map.put(@submit, key, value))

        assert {finding.code, finding.field} == {"submit.invalid_field", key}
        assert finding.message =~ key
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
