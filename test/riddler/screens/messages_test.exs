defmodule Riddler.Screens.MessagesTest do
  use ExUnit.Case, async: true

  alias Riddler.Finding
  alias Riddler.Screens
  alias Riddler.Screens.Document

  # A question's `messages` maps a finding code its type raises on a response
  # to the text its author shows for it: admitted on the four question types
  # and held to those codes, and read by response validation, which sets a
  # finding's `author_message` beside the package's own `message`.

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
      {:error, findings} -> findings
    end
  end

  defp email(overrides) do
    Map.merge(
      %{
        "type" => "text_question",
        "key" => "work_email",
        "label" => "Work email",
        "format" => "email",
        "required" => true
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
        "label" => "Send me product news",
        "required" => true
      },
      overrides
    )
  end

  defp pin(overrides) do
    Map.merge(
      %{
        "type" => "secret_question",
        "key" => "account_pin",
        "label" => "Choose a PIN",
        "required" => true
      },
      overrides
    )
  end

  @format_text "That does not look like an email address."

  describe "admission" do
    # Sabotage: dropped `Messages.fields()` from the text question's optional
    # fields; admission dropped `messages` and this test went red. And again
    # from each of the other three types.
    test "keeps a question's messages string-keyed, as written, on every question type" do
      messages = %{"response.required" => "Answer this one."}

      for node <- [email(%{}), plan(%{}), newsletter(%{}), pin(%{})] do
        %Document{screens: [%{nodes: [admitted]}]} =
          document([Map.put(node, "messages", messages)])

        assert admitted.messages == messages, node["type"]
      end
    end

    # Sabotage: answered [] from `Messages.findings/1` for a messages that is
    # not a map; the string was admitted silently and this test went red.
    test "refuses a messages that is not an object" do
      assert [
               %Finding{
                 code: "document.invalid_messages",
                 field: "messages",
                 node_key: "work_email"
               }
             ] =
               findings([email(%{"messages" => @format_text})])
    end

    # Sabotage: dropped the `not is_binary(text)` filter from the value check;
    # every string value raised a finding and this test went red. And again
    # with the value check answering []; the number went unreported.
    test "refuses each value in messages that is not a string, and only those" do
      assert [
               %Finding{code: "document.invalid_messages", field: "messages", node_key: "plan"} =
                 finding
             ] =
               findings([
                 plan(%{
                   "messages" => %{
                     "response.required" => 3,
                     "response.not_an_option" => "Pick one of the plans listed."
                   }
                 })
               ])

      assert finding.message =~ "response.required"
    end

    # Sabotage: made `Messages.codes/1` answer the choice question's codes for
    # every type; the text question keying `response.not_an_option` was
    # admitted and this test went red.
    test "refuses a key its type does not raise, naming the key, one finding per key" do
      assert [
               %Finding{code: "document.unknown_message_code", field: "messages"} = first,
               %Finding{code: "document.unknown_message_code", field: "messages"} = second
             ] =
               findings([
                 email(%{
                   "messages" => %{
                     "response.not_an_option" => "Pick one.",
                     "response.undecidable" => "Something went wrong.",
                     "response.format" => @format_text
                   }
                 })
               ])

      assert first.node_key == "work_email"
      assert first.message =~ ~s("response.not_an_option")
      assert second.message =~ ~s("response.undecidable")
    end

    # Sabotage: removed "response.out_of_range" from the text question's codes;
    # the question keying it was refused and this test went red. And again with
    # "response.invalid_shape" removed from the secret question's.
    test "admits every code the table gives each type" do
      assert findings([
               email(%{
                 "messages" => %{
                   "response.required" => "a",
                   "response.format" => "b",
                   "response.out_of_range" => "c"
                 }
               }),
               plan(%{
                 "messages" => %{
                   "response.required" => "a",
                   "response.invalid_shape" => "b",
                   "response.not_an_option" => "c",
                   "response.out_of_range" => "d"
                 }
               }),
               newsletter(%{
                 "messages" => %{"response.required" => "a", "response.invalid_shape" => "b"}
               }),
               pin(%{
                 "messages" => %{"response.required" => "a", "response.invalid_shape" => "b"}
               })
             ]) == []
    end

    # Sabotage: added "response.format" to the secret question's codes; the
    # secret question keying it was admitted and this test went red.
    test "refuses a format message on a secret question, which is held to no format" do
      assert [%Finding{code: "document.unknown_message_code", node_key: "account_pin"}] =
               findings([pin(%{"messages" => %{"response.format" => "Not a PIN."}})])
    end
  end

  describe "response validation" do
    # Sabotage: made `Messages.author/2` answer the findings unchanged; the
    # finding carried nil and this test went red. And again setting
    # `message` in place of `author_message`; the package's sentence was
    # replaced and the message assertion went red.
    test "sets author_message on a finding whose code the question keys, its message unchanged" do
      document = document([email(%{"messages" => %{"response.format" => @format_text}})])
      plain = document([email(%{})])
      root = %{"responses" => %{"work_email" => "ada-at-example"}}

      assert {:error, [finding]} = Screens.validate_screen(document, "account", root)
      assert {:error, [unkeyed]} = Screens.validate_screen(plain, "account", root)

      assert finding.code == "response.format"
      assert finding.author_message == @format_text
      assert finding.message == unkeyed.message
      assert unkeyed.author_message == nil
    end

    # Sabotage: looked the text up under "response.required" whatever the
    # finding's code; the format finding carried the required text and this
    # test went red.
    test "leaves author_message nil on a finding whose code the question does not key" do
      document = document([email(%{"messages" => %{"response.required" => "Tell us an email."}})])
      root = %{"responses" => %{"work_email" => "ada-at-example"}}

      assert {:error, [%Finding{code: "response.format", author_message: nil}]} =
               Screens.validate_screen(document, "account", root)
    end

    # Sabotage: dropped the `authored_findings/2` wrapper and called
    # `node_findings/2` directly; every finding carried nil and this test went
    # red.
    test "reads each question's own messages, on every question type, through the arity-4 form too" do
      document =
        document([
          email(%{"messages" => %{"response.required" => "email text"}}),
          plan(%{"required" => true, "messages" => %{"response.not_an_option" => "plan text"}}),
          newsletter(%{"messages" => %{"response.required" => "newsletter text"}}),
          pin(%{"messages" => %{"response.invalid_shape" => "pin text"}}),
          %{
            "type" => "button",
            "key" => "account_next",
            "label" => "Continue",
            "outcome" => "account_submitted"
          }
        ])

      root = %{
        "responses" => %{"plan" => "team", "newsletter" => false, "account_pin" => 1234}
      }

      expected = [
        {"work_email", "response.required", "email text"},
        {"plan", "response.not_an_option", "plan text"},
        {"newsletter", "response.required", "newsletter text"},
        {"account_pin", "response.invalid_shape", "pin text"}
      ]

      for answer <- [
            Screens.validate_screen(document, "account", root),
            Screens.validate_screen(document, "account", root, "account_next")
          ] do
        assert {:error, findings} = answer
        assert Enum.map(findings, &{&1.node_key, &1.code, &1.author_message}) == expected
      end
    end

    # Sabotage: set an author_message on every undecidable finding in
    # `Validation.validate/5`; the condition finding carried it and this test
    # went red.
    test "never sets author_message on a finding about a node's condition" do
      document =
        document([
          email(%{
            "condition" => "context.plan_tier == 'pro'",
            "messages" => %{"response.required" => "Tell us an email."}
          })
        ])

      assert {:error, [%Finding{code: "response.undecidable", author_message: nil}]} =
               Screens.validate_screen(document, "account", %{"responses" => %{}})
    end

    # Sabotage: set author_message to the inspected response in
    # `authored_findings/2`; the secret's sentinel reached the finding and this
    # test went red.
    test "carries the author's text and nothing of a secret question's response" do
      sentinel = "SENTINEL-NOT-A-REAL-PIN"
      document = document([pin(%{"messages" => %{"response.invalid_shape" => "Type it again."}})])
      root = %{"responses" => %{"account_pin" => %{"typed" => sentinel}}}

      assert {:error, [finding]} = Screens.validate_screen(document, "account", root)
      assert finding.author_message == "Type it again."
      refute inspect(finding) =~ sentinel
    end

    # Sabotage: dropped the `is_binary(text)` guard in `Messages.author/2`; the
    # number reached author_message and this test went red.
    test "passes on no value that is not a string from a document no one validated" do
      document = document([email(%{"messages" => %{"response.format" => 3}})])
      root = %{"responses" => %{"work_email" => "ada-at-example"}}

      assert {:error, [%Finding{author_message: nil}]} =
               Screens.validate_screen(document, "account", root)
    end
  end
end
