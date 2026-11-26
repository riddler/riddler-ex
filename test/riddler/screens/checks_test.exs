defmodule Riddler.Screens.ChecksTest do
  use ExUnit.Case, async: true

  alias Riddler.Finding
  alias Riddler.Journey
  alias Riddler.Screens
  alias Riddler.Screens.Document

  # A question's `checks`, as the amendment to docs/adr/0002-element-document.md
  # headed "a question's `checks`, conditions its author writes and the host's
  # validation evaluates" decides, and its companion in
  # docs/adr/0005-journey-presented-as-data.md for what crosses the wire.

  @emails_differ %{
    "condition" => "responses.work_email_again == responses.work_email",
    "code" => "check.emails_differ",
    "message" => "The two email addresses do not match."
  }

  @too_many_seats %{
    "condition" => "responses.seats::integer <= context.plan.max_seats",
    "code" => "check.too_many_seats",
    "message" => "This plan takes fewer seats."
  }

  @referral_known %{
    "condition" => "responses.referral == 'friend'",
    "code" => "check.unknown_referral",
    "message" => "Tell us who referred you."
  }

  defp elements do
    [
      %{
        "type" => "text_question",
        "key" => "work_email",
        "label" => "Work email",
        "format" => "email",
        "required" => true
      },
      %{
        "type" => "text_question",
        "key" => "work_email_again",
        "label" => "Type the email again",
        "required" => true,
        "checks" => [@emails_differ]
      },
      %{
        "type" => "text_question",
        "key" => "seats",
        "label" => "How many seats?",
        "format" => "integer",
        "min" => 1,
        "checks" => [@too_many_seats]
      },
      %{
        "type" => "text_question",
        "key" => "referral",
        "label" => "Who referred you?",
        "condition" => "context.show_referral == true",
        "checks" => [@referral_known]
      },
      %{
        "type" => "button",
        "key" => "account_back",
        "label" => "Back",
        "outcome" => "went_back",
        "validates" => false
      },
      %{
        "type" => "button",
        "key" => "account_next",
        "label" => "Continue",
        "outcome" => "account_created"
      }
    ]
  end

  defp raw(elements) do
    %{
      "schema_version" => 2,
      "id" => "edoc_signup_screens",
      "screens" => [
        %{"key" => "account", "title" => "Create your account", "elements" => elements}
      ]
    }
  end

  defp document(elements \\ elements()), do: elements |> raw() |> Document.admit()

  defp root(responses, context \\ %{"plan" => %{"max_seats" => 5}, "show_referral" => false}),
    do: %{"context" => context, "responses" => responses}

  defp good do
    %{"work_email" => "ada@example.com", "work_email_again" => "ada@example.com", "seats" => "3"}
  end

  defp codes(findings), do: Enum.map(findings, &{&1.code, &1.element_key})

  defp admit_findings(elements) do
    case Document.validate(document(elements)) do
      {:ok, _document} -> []
      {:error, findings} -> findings
    end
  end

  defp question(extra) do
    Map.merge(%{"type" => "text_question", "key" => "work_email", "label" => "Work email"}, extra)
  end

  describe "admission" do
    # Sabotage: dropped `:checks` from the common fields; admission carried no
    # check and this went red.
    test "a question's checks are admitted atom-keyed, with the three fields and nothing else" do
      extra = Map.put(@emails_differ, "severity", "warning")

      %Document{screens: [%{elements: [node]}]} =
        document([question(%{"checks" => [extra]})])

      assert node[:checks] == [
               %{
                 condition: @emails_differ["condition"],
                 code: "check.emails_differ",
                 message: "The two email addresses do not match."
               }
             ]

      assert {:ok, _document} = Document.validate(document())
    end

    # Sabotage: took the question-type clause out of `check_findings/3`; the
    # button's well-formed checks raised nothing and this went red.
    test "checks on an element that is not a question are refused, not dropped" do
      button = %{
        "type" => "button",
        "key" => "account_next",
        "label" => "Continue",
        "outcome" => "account_created",
        "checks" => [@emails_differ]
      }

      variant = %{
        "type" => "variant",
        "key" => "plan_notice",
        "checks" => [],
        "elements" => [%{"type" => "text", "key" => "plan_notice_text", "text" => "Hello."}]
      }

      assert [
               %Finding{
                 code: "document.invalid_check",
                 field: "checks",
                 element_key: "account_next"
               }
             ] =
               admit_findings([button])

      assert [%Finding{code: "document.invalid_check", element_key: "plan_notice"}] =
               admit_findings([variant])
    end

    # Sabotage: dropped `secret_question` from the question types; its checks
    # were refused and this went red.
    test "every question type takes checks, and an empty list checks nothing" do
      questions = [
        question(%{"checks" => []}),
        %{
          "type" => "boolean_question",
          "key" => "terms",
          "label" => "I agree",
          "checks" => [@emails_differ |> Map.put("code", "check.a")]
        },
        %{
          "type" => "choice_question",
          "key" => "plan",
          "label" => "Plan",
          "select" => "one",
          "answer_options" => [%{"value" => "team", "label" => "Team"}],
          "checks" => [Map.put(@emails_differ, "code", "check.b")]
        },
        %{
          "type" => "secret_question",
          "key" => "card_pin",
          "label" => "PIN",
          "checks" => [Map.put(@too_many_seats, "code", "check.c")]
        }
      ]

      assert admit_findings(questions) == []
    end

    # Sabotage: widened the code shape to `check`, `response` or `document`
    # first; `response.format` was admitted and this went red.
    test "an author's code is in the check. namespace and never one of the package's" do
      for code <- [
            "emails_differ",
            "response.format",
            "document.invalid_check",
            "check",
            "check.",
            "check.Emails",
            7
          ] do
        findings =
          admit_findings([question(%{"checks" => [Map.put(@emails_differ, "code", code)]})])

        assert [
                 %Finding{
                   code: "document.invalid_check",
                   field: "checks",
                   element_key: "work_email"
                 }
               ] =
                 findings,
               "expected #{inspect(code)} refused"
      end

      assert admit_findings([
               question(%{
                 "checks" => [Map.put(@emails_differ, "code", "check.birth_date.future")]
               })
             ]) ==
               []
    end

    # Sabotage: made the repeated-code clause never fire; the second entry
    # raised nothing and this went red.
    test "two checks on one question may not carry one code, and two questions may" do
      twice =
        question(%{
          "checks" => [@emails_differ, Map.put(@too_many_seats, "code", "check.emails_differ")]
        })

      assert [%Finding{code: "document.invalid_check", message: message}] =
               admit_findings([twice])

      assert message =~ "check 2"

      other = %{
        "type" => "text_question",
        "key" => "seats",
        "label" => "Seats",
        "checks" => [@emails_differ]
      }

      assert admit_findings([question(%{"checks" => [@emails_differ]}), other]) == []
    end

    # Sabotage: reported an entry's missing fields in the order condition,
    # message, code; the third finding named the message and this went red.
    test "each malformed entry is refused, in list order and within an entry in the record's order" do
      checks = [
        "not an object",
        %{"code" => "check.no_condition", "message" => "x"},
        %{"condition" => "true"},
        %{"condition" => "true", "code" => "check.blank_message", "message" => ""},
        %{"condition" => 7, "code" => "check.number", "message" => "x"},
        %{"condition" => "responses.work_email ==", "code" => "check.unparsed", "message" => "x"}
      ]

      findings = admit_findings([question(%{"checks" => checks})])

      assert Enum.map(findings, & &1.code) == [
               "document.invalid_check",
               "document.invalid_check",
               "document.invalid_check",
               "document.invalid_check",
               "document.invalid_check",
               "document.invalid_condition",
               "document.invalid_condition"
             ]

      assert Enum.all?(findings, &(&1.field == "checks" and &1.element_key == "work_email"))
      [_object, _no_condition, no_code, no_message | _rest] = findings
      assert no_code.message =~ "carries no code"
      assert no_message.message =~ "carries no message"

      unparsed = List.last(findings)
      assert unparsed.message =~ "check 6 (\"check.unparsed\")"
      assert %{line: 1, column: _} = unparsed.position
      assert Enum.at(findings, -2).position == nil

      assert [%Finding{code: "document.invalid_check"}] =
               admit_findings([question(%{"checks" => "all of them"})])
    end

    # Sabotage: ran the secret-reference pass over no secret keys; the check
    # reading the PIN was admitted and this went red.
    test "a check naming a secret question's response is refused" do
      pin = %{"type" => "secret_question", "key" => "card_pin", "label" => "PIN"}

      reads_pin =
        question(%{
          "checks" => [
            %{
              "condition" => "responses.card_pin != '' and responses.card_pin != '0000'",
              "code" => "check.pin_length",
              "message" => "x"
            }
          ]
        })

      assert [
               %Finding{
                 code: "document.secret_reference",
                 field: "checks",
                 element_key: "work_email",
                 message: message
               }
             ] =
               admit_findings([pin, reads_pin])

      assert message =~ "card_pin"
      assert message =~ "check.pin_length"
    end
  end

  describe "response validation" do
    # Sabotage: negated what `Checks.decide/2` answers for a decided condition;
    # the passing checks raised findings and this went red.
    test "a screen whose checks all pass is :ok" do
      assert Screens.validate_screen(document(), "account", root(good())) == :ok
    end

    # Sabotage: made `Checks.findings/3` answer nothing for a failing check; no
    # check finding came back and this went red.
    test "a check the root decides false raises the author's code, with no response in it" do
      responses = Map.put(good(), "work_email_again", "ada@exmaple.com")

      assert {:error, [finding]} = Screens.validate_screen(document(), "account", root(responses))

      assert %Finding{
               code: "check.emails_differ",
               field: "checks",
               element_key: "work_email_again",
               position: nil,
               author_message: "The two email addresses do not match."
             } = finding

      assert finding.message =~ "Type the email again"
      assert finding.message =~ "check.emails_differ"
      refute finding.message =~ "exmaple"
      refute finding.message =~ "=="
    end

    # Sabotage: appended the check findings to a question's built-in findings;
    # the out-of-range seats answered two findings and this went red.
    test "a question the built-in checks refuse has none of its checks evaluated" do
      always_false = %{"condition" => "false", "code" => "check.never", "message" => "x"}

      seats = %{
        "type" => "text_question",
        "key" => "seats",
        "label" => "How many seats?",
        "format" => "integer",
        "min" => 1,
        "checks" => [always_false]
      }

      for {response, code} <- [{"0", "response.out_of_range"}, {"nine", "response.format"}] do
        assert {:error, [%Finding{code: ^code, element_key: "seats"}]} =
                 Screens.validate_screen(
                   document([seats]),
                   "account",
                   root(%{"seats" => response})
                 )
      end

      assert {:error, [%Finding{code: "check.never"}]} =
               Screens.validate_screen(document([seats]), "account", root(%{"seats" => "3"}))
    end

    # Sabotage: evaluated the checks whatever the response; the always-false
    # checks of the unanswered questions raised findings and this went red.
    test "a question whose response is nothing answered has none of its checks evaluated" do
      always_false = %{"condition" => "false", "code" => "check.never", "message" => "x"}

      elements = [
        question(%{"checks" => [always_false]}),
        %{
          "type" => "choice_question",
          "key" => "plan",
          "label" => "Plan",
          "select" => "many",
          "answer_options" => [%{"value" => "team", "label" => "Team"}],
          "checks" => [Map.put(always_false, "code", "check.never_plan")]
        },
        %{
          "type" => "boolean_question",
          "key" => "terms",
          "label" => "Terms",
          "checks" => [Map.put(always_false, "code", "check.never_terms")]
        }
      ]

      for responses <- [%{}, %{"work_email" => "  ", "plan" => [], "terms" => nil}] do
        assert Screens.validate_screen(document(elements), "account", root(responses)) == :ok
      end

      assert {:error, found} =
               Screens.validate_screen(
                 document(elements),
                 "account",
                 root(%{"work_email" => "a", "plan" => ["team"], "terms" => false})
               )

      assert codes(found) == [
               {"check.never", "work_email"},
               {"check.never_plan", "plan"},
               {"check.never_terms", "terms"}
             ]
    end

    # Sabotage: validated every question of the document's screen, hidden ones
    # included, rather than the resolved screen; the hidden referral question
    # raised check.unknown_referral and this went red.
    test "a failing check on a hidden question raises nothing" do
      responses = Map.put(good(), "referral", "colleague")

      assert Screens.validate_screen(document(), "account", root(responses)) == :ok

      shown = %{"plan" => %{"max_seats" => 5}, "show_referral" => true}

      assert {:error, [%Finding{code: "check.unknown_referral", element_key: "referral"}]} =
               Screens.validate_screen(document(), "account", root(responses, shown))
    end

    # Sabotage: made a check fail wherever the root does not decide it true; the
    # seats check against a context with no plan raised a finding and this went
    # red.
    test "an undecidable check raises nothing, and the next check is evaluated" do
      no_plan = %{"show_referral" => false}

      assert Screens.validate_screen(document(), "account", root(good(), no_plan)) == :ok

      checks = [
        %{
          "condition" => "responses.work_email == context.missing",
          "code" => "check.undecided",
          "message" => "x"
        },
        %{"condition" => "false", "code" => "check.second", "message" => "y"},
        %{"condition" => "false", "code" => "check.third", "message" => "z"}
      ]

      assert {:error, [%Finding{code: "check.second", author_message: "y"}]} =
               Screens.validate_screen(
                 document([question(%{"checks" => checks})]),
                 "account",
                 root(%{"work_email" => "a"})
               )
    end

    # Sabotage: walked the screen's questions in reverse, and, run apart, put the
    # undecidable-condition findings last; each time this went red.
    test "the findings come one per failing question, in document order" do
      responses = %{"work_email" => "nope", "work_email_again" => "x@example.com", "seats" => "9"}

      assert {:error, found} = Screens.validate_screen(document(), "account", root(responses))

      assert codes(found) == [
               {"response.format", "work_email"},
               {"check.emails_differ", "work_email_again"},
               {"check.too_many_seats", "seats"}
             ]

      undecided = %{
        "type" => "text",
        "key" => "seats_note",
        "condition" => "context.missing > 1",
        "text" => "Seats."
      }

      assert {:error, found} =
               Screens.validate_screen(
                 document(elements() ++ [undecided]),
                 "account",
                 root(responses)
               )

      assert hd(codes(found)) == {"response.undecidable", "seats_note"}
      assert length(found) == 4
    end

    # Sabotage: made `opted_out?/2` never fire; the Back press answered the
    # seats finding and this went red.
    test "a press through a button that does not validate evaluates no check" do
      responses = Map.put(good(), "seats", "9")

      assert Screens.validate_screen(document(), "account", root(responses), "account_back") ==
               :ok

      assert {:error, [_finding]} =
               Screens.validate_screen(document(), "account", root(responses), "account_next")
    end

    # Sabotage: evaluated the checks against the host's responses rather than
    # the reading root; the PIN's own value decided the check and this went red.
    test "a check is never decided against a secret's value, in a document no one validated" do
      elements = [
        %{
          "type" => "secret_question",
          "key" => "card_pin",
          "label" => "PIN",
          "checks" => [
            %{
              "condition" => "responses.card_pin == '1234'",
              "code" => "check.pin",
              "message" => "x"
            }
          ]
        }
      ]

      assert Screens.validate_screen(document(elements), "account", root(%{"card_pin" => "9999"})) ==
               :ok

      assert {:ok, _screen, %{undecidable_checks: [%{key: "card_pin", code: "check.pin"}]}} =
               Screens.resolve_screen(
                 document(elements),
                 "account",
                 root(%{"card_pin" => "9999"})
               )
    end

    # Sabotage: read an entry whose message, and, run apart, whose code is not a
    # string as well formed; each time that entry raised the first finding and
    # this went red.
    test "a malformed check in a document no one validated is skipped" do
      checks = [
        "not an object",
        %{"condition" => 7, "code" => "check.number", "message" => "x"},
        %{"condition" => "false", "code" => "check.no_message"},
        %{"condition" => "false", "code" => "check.number_message", "message" => 7},
        %{"condition" => "false", "code" => 7, "message" => "a number for a code"},
        %{"condition" => "false", "code" => "response.format", "message" => "as written"}
      ]

      assert {:error,
              [%Finding{code: "response.format", field: "checks", author_message: "as written"}]} =
               Screens.validate_screen(
                 document([question(%{"checks" => checks})]),
                 "account",
                 root(%{"work_email" => "a"})
               )

      assert Screens.validate_screen(
               document([question(%{"checks" => "x"})]),
               "account",
               root(%{"work_email" => "a"})
             ) ==
               :ok
    end
  end

  describe "a variant's candidates" do
    defp seats_variant(first_checks) do
      %{
        "type" => "variant",
        "key" => "seats_variant",
        "elements" => [
          %{
            "type" => "text_question",
            "key" => "team_seats",
            "label" => "How many team seats?",
            "condition" => "context.team == true",
            "checks" => first_checks
          },
          %{
            "type" => "text_question",
            "key" => "solo_seats",
            "label" => "How many seats?",
            "checks" => [%{"condition" => "true", "code" => "check.always", "message" => "x"}]
          }
        ]
      }
    end

    # Sabotage: dropped the candidates from `node_findings/3`; the candidate's
    # malformed check raised nothing and this went red.
    test "a question among a variant's candidates carries its own checks, refused at admit" do
      bad = [%{"condition" => "true", "code" => "seats", "message" => "x"}]

      assert [
               %Finding{
                 code: "document.invalid_check",
                 element_key: "team_seats",
                 field: "checks"
               }
             ] =
               admit_findings([seats_variant(bad)])
    end

    # Sabotage: validated every question of the document's screen rather than
    # the resolved screen; the losing candidate's failing check raised a
    # finding and this went red.
    test "only the winning candidate's checks are evaluated" do
      never = [%{"condition" => "false", "code" => "check.never", "message" => "x"}]
      responses = %{"team_seats" => "4", "solo_seats" => "4"}

      assert Screens.validate_screen(
               document([seats_variant(never)]),
               "account",
               root(responses, %{"team" => false})
             ) ==
               :ok

      assert {:error, [%Finding{code: "check.never", element_key: "team_seats"}]} =
               Screens.validate_screen(
                 document([seats_variant(never)]),
                 "account",
                 root(responses, %{"team" => true})
               )
    end
  end

  describe "resolution" do
    # Sabotage: dropped the report of undecided checks from resolution, and, run
    # apart, reported every question's checks, hidden ones included; each time
    # this went red.
    test "an undecidable check of an answered, shown question is reported in the diagnostics" do
      responses = %{
        "work_email_again" => "ada@example.com",
        "seats" => "7",
        "referral" => "colleague"
      }

      # The hidden referral question is answered and its check reads a name
      # the root does not carry, so only its being hidden keeps it unlisted.
      undecided_referral = %{
        @referral_known
        | "condition" => "responses.referral == context.referrer"
      }

      document =
        elements()
        |> Enum.map(fn
          %{"key" => "referral"} = referral -> %{referral | "checks" => [undecided_referral]}
          element -> element
        end)
        |> document()

      assert {:ok, screen, diagnostics} =
               Screens.resolve_screen(
                 document,
                 "account",
                 root(responses, %{"show_referral" => false})
               )

      assert diagnostics == %{
               missing_variables: [],
               undecidable_conditions: [],
               undecidable_checks: [
                 %{
                   key: "work_email_again",
                   code: "check.emails_differ",
                   condition: @emails_differ["condition"]
                 },
                 %{
                   key: "seats",
                   code: "check.too_many_seats",
                   condition: @too_many_seats["condition"]
                 }
               ]
             }

      refute Enum.any?(screen.elements, &Map.has_key?(&1, :checks))

      assert {:ok, resolved} =
               Screens.resolve(document, root(responses, %{"show_referral" => false}))

      assert resolved.diagnostics == diagnostics
      refute Enum.any?(hd(resolved.screens).elements, &Map.has_key?(&1, :checks))
    end

    # Sabotage: reported the checks of a question whatever its response; the
    # first presentation listed the unanswered email check and this went red.
    test "diagnostics with no undecided check carry the two lists alone" do
      for responses <- [%{}, good()] do
        assert {:ok, _screen, diagnostics} =
                 Screens.resolve_screen(document(), "account", root(responses))

        assert diagnostics == %{missing_variables: [], undecidable_conditions: []}
      end
    end

    # Sabotage: left a resolved question its `checks`; the presented question
    # carried them and this went red.
    test "a presented screen carries undecidable_checks on the wire, and no checks on a question" do
      responses = %{"seats" => "7"}

      assert {:ok, %{"screen" => screen}} =
               Journey.present(document(), {:screen, "account"}, root(responses, %{}))

      assert screen["diagnostics"]["undecidable_checks"] == [
               %{
                 "key" => "seats",
                 "code" => "check.too_many_seats",
                 "condition" => @too_many_seats["condition"]
               }
             ]

      refute Enum.any?(screen["elements"], &Map.has_key?(&1, "checks"))
    end
  end
end
