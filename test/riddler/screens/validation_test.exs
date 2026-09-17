defmodule Riddler.Screens.ValidationTest do
  use ExUnit.Case, async: true

  alias Riddler.Finding
  alias Riddler.Screens
  alias Riddler.Screens.Document

  # test/fixtures/signup_screens.json is a verbatim copy of
  # priv/fixtures/signup_screens.json in the statifier_examples repository,
  # read at 9d288c9. The signup cases below read their keys and conditions
  # from that file rather than restating them, and edit a copy of the decoded
  # map where a case needs a shape the fixture does not author.
  @fixture "test/fixtures/signup_screens.json"

  @good_email "ada@example.com"

  # One bad response per format, with whatever else that format reads. The map
  # is checked against `Document.formats/0` by the last test in the file, so a
  # format added to the document without a check behind it turns this file red.
  @bad_per_format %{
    "email" => {%{}, "ada at example dot com"},
    "phone" => {%{}, "ring me"},
    "pattern" => {%{"pattern" => "[0-9]{4}"}, "no"},
    "integer" => {%{}, "three"},
    "number" => {%{}, "three"}
  }

  defp raw_fixture, do: @fixture |> File.read!() |> Jason.decode!()

  defp fixture_document, do: Document.admit(raw_fixture())

  defp put_node_field(raw, node_key, field, value) do
    update_in(raw, ["screens", Access.all(), "nodes", Access.all()], fn node ->
      if node["key"] == node_key, do: Map.put(node, field, value), else: node
    end)
  end

  defp add_node(raw, screen_key, node) do
    update_in(raw, ["screens", Access.all()], fn screen ->
      if screen["key"] == screen_key,
        do: Map.update!(screen, "nodes", &(&1 ++ [node])),
        else: screen
    end)
  end

  # The fixture's confirm screen asks about a referral only when the visitor
  # took more than one seat, and authors it optional. Turning `required` on is
  # what makes the hidden case say something: a question that cannot fail
  # cannot show that being hidden is what kept it from failing.
  defp referral_required_document,
    do: raw_fixture() |> put_node_field("referral", "required", true) |> Document.admit()

  # The fixture's account screen with a Back button beside its Continue one:
  # the fixture authors a Back button on the plan screen only, and the opt-out
  # is only worth a case on a screen that has something to fail.
  defp account_with_back_document do
    raw_fixture()
    |> add_node("account", %{
      "type" => "button",
      "key" => "account_back",
      "label" => "Back",
      "outcome" => "went_back",
      "validates" => false
    })
    |> Document.admit()
  end

  # A one-question screen from the payments host, for the format cases: the
  # question carries whatever the format under test reads, and a Pay button so
  # that the arity-4 form has something to press.
  defp card_document(question) do
    Document.admit(%{
      "schema_version" => 1,
      "id" => "edoc_card",
      "screens" => [
        %{
          "key" => "card",
          "title" => "Your card",
          "nodes" => [
            Map.merge(
              %{"type" => "text_question", "key" => "card_field", "label" => "Card field"},
              question
            ),
            %{"type" => "button", "key" => "card_pay", "label" => "Pay", "outcome" => "paid"}
          ]
        }
      ]
    })
  end

  defp check(question, response) do
    Screens.validate_screen(card_document(question), "card", %{
      "responses" => %{"card_field" => response}
    })
  end

  # The case the ADR-0002 amendment of 2026-09-17 demonstrates: a screen with
  # one unconditional required question and one required question conditional
  # on the host's `context`. The host resolves it under a root whose `context`
  # satisfies that condition, so the visitor is shown both.
  defp checkout_document do
    Document.admit(%{
      "schema_version" => 1,
      "id" => "edoc_checkout",
      "screens" => [
        %{
          "key" => "checkout",
          "title" => "Checkout",
          "nodes" => [
            %{
              "type" => "text_question",
              "key" => "full_name",
              "label" => "Your name",
              "required" => true
            },
            %{
              "type" => "text_question",
              "key" => "vat_id",
              "label" => "VAT identifier",
              "condition" => "context.is_business == true",
              "required" => true
            }
          ]
        }
      ]
    })
  end

  describe "required over the signup fixture" do
    # Sabotage: made `blank?/1` answer `false` for `nil`; the unanswered name
    # raised no finding and this test went red.
    test "a required question with no response at all is a finding naming the node" do
      assert {:error, [finding]} =
               Screens.validate_screen(fixture_document(), "account", %{
                 "responses" => %{"email" => @good_email}
               })

      assert %Finding{code: "response.required", field: "required", node_key: "first_name"} =
               finding

      assert finding.message =~ "First name"
    end

    # Sabotage: made `blank?/1` answer `false` for a string of spaces; the
    # whitespace name was accepted and this test went red.
    test "a required question answered with whitespace is unanswered" do
      assert {:error, [finding]} =
               Screens.validate_screen(fixture_document(), "account", %{
                 "responses" => %{"first_name" => "   ", "email" => @good_email}
               })

      assert finding.node_key == "first_name"
    end

    # Sabotage: made `validate_screen/3` collect only the first node's
    # findings instead of every node's; the email finding was lost and this
    # test went red.
    test "every failing node on the screen is reported, in document order" do
      assert {:error, findings} =
               Screens.validate_screen(fixture_document(), "account", %{})

      assert Enum.map(findings, & &1.node_key) == ["first_name", "email"]
    end

    # Sabotage: made `checks/2` raise the required finding for every blank
    # response whatever `required` says; the unanswered optional seats question
    # raised one and this test went red.
    test "an optional question left blank is not a finding" do
      assert :ok == Screens.validate_screen(fixture_document(), "plan", %{})
    end

    # Sabotage: made `checks/2` run the format checks on a blank response as
    # well; the blank optional referral was put to the email format and this
    # test went red.
    test "a blank response that is not required is never put to its format" do
      assert :ok == check(%{"format" => "email", "required" => false}, "")
    end
  end

  describe "the email format over the signup fixture" do
    # Sabotage: made `check/3` answer `[]` for "email"; the bad address was
    # accepted and the second half of this test went red.
    test "the fixture's work email takes a good address and refuses a bad one" do
      assert :ok ==
               Screens.validate_screen(fixture_document(), "account", %{
                 "responses" => %{"first_name" => "Ada", "email" => @good_email}
               })

      assert {:error, [finding]} =
               Screens.validate_screen(fixture_document(), "account", %{
                 "responses" => %{"first_name" => "Ada", "email" => "ada.example.com"}
               })

      assert %Finding{code: "response.format", field: "format", node_key: "email"} = finding
    end
  end

  describe "checks run over the resolved screen only" do
    # Sabotage: made resolution keep a node whose condition decided false
    # (`shown/3`'s false branch answering the node instead of `nil`); the hidden
    # referral question reached the checks, raised a required finding, and this
    # test went red.
    test "a question the visitor's responses hid cannot fail, blank or not" do
      assert :ok ==
               Screens.validate_screen(referral_required_document(), "confirm", %{
                 "responses" => %{"seats" => 1}
               })
    end

    # Sabotage: made `blank?/1` answer `false` for `nil`; the shown referral
    # question raised nothing and this test went red. It is the control for the
    # test above: the mutation that hides nothing leaves this one green, so the
    # pair separates "hidden" from "not checked at all".
    test "the same question shown by the same responses does fail when blank" do
      assert {:error, [finding]} =
               Screens.validate_screen(referral_required_document(), "confirm", %{
                 "responses" => %{"seats" => 3}
               })

      assert finding.node_key == "referral"
    end
  end

  describe "the per-button opt-out" do
    # Sabotage: made `opted_out?/2` compare `validates` against a value it
    # never holds, so no button ever opts out; the Back press ran the checks on
    # the blank name and this test went red.
    test "a Back button declaring validates false answers :ok without running" do
      assert :ok ==
               Screens.validate_screen(
                 account_with_back_document(),
                 "account",
                 %{},
                 "account_back"
               )
    end

    # Sabotage: made `opted_out?/2` answer `true` for any button it found; the
    # Continue press skipped the checks and this test went red.
    test "the Continue button on the same screen answers the finding" do
      assert {:error, [%Finding{node_key: "first_name"} | _rest]} =
               Screens.validate_screen(
                 account_with_back_document(),
                 "account",
                 %{},
                 "account_continue"
               )
    end

    # Sabotage: made `opted_out?/2` answer `true` when no button matched; the
    # arity-3 form skipped every check and this test went red.
    test "the arity-3 form presses no button and validates" do
      assert {:error, _findings} =
               Screens.validate_screen(account_with_back_document(), "account", %{})
    end

    # Sabotage: made `opted_out?/2` answer `true` for a key naming no button;
    # a key the screen does not carry skipped the checks and this test went
    # red.
    test "a key naming no button on the screen validates, because true is the default" do
      assert {:error, _findings} =
               Screens.validate_screen(
                 account_with_back_document(),
                 "account",
                 %{},
                 "no_such_button"
               )
    end
  end

  describe "the formats" do
    # Sabotage: made the phone check count one digit as enough; "12" was
    # accepted and this test went red.
    test "phone takes punctuation and enough digits, and refuses too few" do
      assert :ok == check(%{"format" => "phone"}, "+1 (555) 010-4477")
      assert {:error, [%Finding{code: "response.format"}]} = check(%{"format" => "phone"}, "12")
      assert {:error, [%Finding{code: "response.format"}]} = check(%{"format" => "phone"}, "call")
    end

    # Sabotage: dropped the `\A(?:` and `)\z` anchors from `compile_pattern/1`;
    # the response carrying a match somewhere inside it was accepted and this
    # test went red.
    test "pattern holds the response to the author's regular expression, whole" do
      four_digits = %{"format" => "pattern", "pattern" => "[0-9]{4}"}

      assert :ok == check(four_digits, "4242")
      assert {:error, [%Finding{field: "format"}]} = check(four_digits, "4242 and more")
      assert {:error, [%Finding{field: "format"}]} = check(four_digits, "42")
    end

    # The admit-versus-validate boundary, pinned from this side. A pattern this
    # package cannot compile is a defect in the document, and the document says
    # so: `document.invalid_pattern`, raised before a visitor arrives. There is
    # nothing left here for a response to be wrong about, and this layer no
    # longer reports it a second time - a defect reported from two layers is
    # worse than one reported in the right place.
    #
    # Sabotage: made `unreadable_pattern/1` answer the response finding for a
    # declared pattern as well as for an absent one; the response carried
    # `response.format` again and this test went red.
    test "a pattern that is not a usable regular expression is the document's finding, not a response's" do
      question = %{"format" => "pattern", "pattern" => "[0-9"}

      assert :ok == check(question, "4242")

      assert {:error, [%Finding{code: "document.invalid_pattern", field: "pattern"}]} =
               Document.validate(card_document(question))
    end

    # The case this layer keeps: a question asking for the `pattern` format and
    # declaring no pattern at all. There is no expression for the document
    # check to read, so it raises nothing there, and a response cannot satisfy
    # a form the question never states.
    #
    # Sabotage: made `unreadable_pattern/1` answer `[]` for an absent pattern
    # as well; the response was accepted against a question nothing could
    # satisfy and this test went red.
    test "the pattern format with no pattern at all is still answered here" do
      question = %{"format" => "pattern"}

      assert {:ok, %Document{}} = Document.validate(card_document(question))

      assert {:error, [%Finding{code: "response.format", field: "pattern"}]} =
               check(question, "4242")
    end

    # The other side of the narrowing: a pattern on a question that asks for no
    # format is inert at BOTH layers, as it was before this bead. The document
    # says nothing about it, and there is no format here to hold a response to,
    # so a response is accepted. Widening the document check would have made
    # this document carry a finding it never carried.
    #
    # Sabotage: dropped the `format == "pattern"` guard from
    # `pattern_findings/1`; the document carried `document.invalid_pattern` and
    # this test went red on its first assertion.
    test "a pattern with no format to read it is inert at both layers" do
      question = %{"pattern" => "[0-9"}
      document = card_document(question)

      assert {:ok, ^document} = Document.validate(document)
      assert :ok == check(question, "4242")
    end

    # Sabotage: made `parse/2` for :integer accept a partial parse (dropping
    # the `""` rest match); "3 seats" and "3.5" were accepted and this test
    # went red.
    test "integer takes a whole number, typed or decoded, and nothing else" do
      assert :ok == check(%{"format" => "integer"}, "3")
      assert :ok == check(%{"format" => "integer"}, 3)

      assert {:error, [%Finding{code: "response.format"}]} =
               check(%{"format" => "integer"}, "3.5")

      assert {:error, [%Finding{code: "response.format"}]} =
               check(%{"format" => "integer"}, "3 seats")
    end

    # Sabotage: made `number/2` refuse a float; the decoded 19.99 was reported
    # as not a number and this test went red.
    test "number takes a decimal, typed or decoded, and refuses text" do
      assert :ok == check(%{"format" => "number"}, "19.99")
      assert :ok == check(%{"format" => "number"}, 19.99)
      assert :ok == check(%{"format" => "number"}, 19)

      assert {:error, [%Finding{code: "response.format"}]} =
               check(%{"format" => "number"}, "lots")
    end

    # Sabotage: made `under?/2` answer `false` always; the single seat under a
    # minimum of 2 was accepted and this test went red.
    test "min bounds a numeric response from below, and the bound itself passes" do
      seats = %{"format" => "integer", "min" => 2}

      assert :ok == check(seats, "2")
      assert {:error, [finding]} = check(seats, "1")
      assert %Finding{code: "response.out_of_range", field: "min"} = finding
    end

    # Sabotage: made `over?/2` answer `false` always; the 99 seats over a
    # maximum of 50 were accepted and this test went red.
    test "max bounds a numeric response from above, and the bound itself passes" do
      seats = %{"format" => "integer", "max" => 50}

      assert :ok == check(seats, "50")
      assert {:error, [finding]} = check(seats, "99")
      assert %Finding{code: "response.out_of_range", field: "max"} = finding
    end

    # Sabotage: made the email clause of `check/3` run `range_findings/2` over
    # the response's length as well; the short address failed the minimum and
    # this test went red.
    test "a bound on a question with no numeric format is consulted by nothing" do
      assert :ok == check(%{"format" => "email", "min" => 50}, "a@b.co")
    end

    # Sabotage: removed the "phone" clause of `check/3`, leaving the catch-all
    # to accept every phone number; the format list and the checks disagreed and
    # this test went red.
    test "every format the document admits has a check behind it" do
      assert Enum.sort(Map.keys(@bad_per_format)) == Enum.sort(Document.formats())

      for {format, {extra, bad}} <- @bad_per_format do
        assert {:error, [%Finding{code: "response.format"}]} =
                 check(Map.merge(%{"format" => format}, extra), bad),
               "the #{format} format accepted #{inspect(bad)}"
      end
    end

    # Sabotage: made `check/3`'s catch-all raise instead of answering `[]`; the
    # unknown format was refused at response time as well and this test went
    # red.
    test "a format name the package does not know is the document's finding, not a response's" do
      assert :ok == check(%{"format" => "postcode"}, "anything")
    end
  end

  describe "a screen the document does not declare" do
    # Sabotage: made `validate_screen/4` answer `:ok` for a screen key it
    # could not find; the host's mistake was reported as a clean screen and
    # this test went red.
    test "comes straight back from resolve_screen/3" do
      assert {:error, :no_such_screen} =
               Screens.validate_screen(fixture_document(), "billing", %{})

      assert {:error, :no_such_screen} =
               Screens.validate_screen(fixture_document(), "billing", %{}, "account_continue")
    end
  end

  describe "the screen validated is the screen shown" do
    # Sabotage: hard-coded the empty context back into `validate_screen/4`
    # (resolving against `%{"context" => %{}, "responses" => root["responses"]}`
    # the way the removed `validate_responses/4` did); the conditional question
    # was hidden from the validator, the blank went unreported, this assertion
    # got `:ok`, and the test went red.
    test "a blank required question the host's context showed is a finding" do
      root = %{"context" => %{"is_business" => true}, "responses" => %{}}

      {:ok, shown, diagnostics} = Screens.resolve_screen(checkout_document(), "checkout", root)
      assert Enum.map(shown.nodes, & &1.key) == ["full_name", "vat_id"]
      assert diagnostics.undecidable_conditions == []

      submitted = put_in(root, ["responses"], %{"full_name" => "Ada"})

      assert {:error, [%Finding{code: "response.required", node_key: "vat_id"}]} =
               Screens.validate_screen(checkout_document(), "checkout", submitted)
    end

    # Sabotage: made `checks/2` raise the required finding whatever the response
    # holds; the answered VAT identifier raised one and this test went red. It is
    # the control for the test above: it shows the finding tracks the blank and
    # not merely the question being shown.
    test "the same question answered under the same context is :ok" do
      root = %{
        "context" => %{"is_business" => true},
        "responses" => %{"full_name" => "Ada", "vat_id" => "DE123"}
      }

      assert :ok == Screens.validate_screen(checkout_document(), "checkout", root)
    end

    # The other half of the pair: under a context that does not carry
    # `is_business` the question is undecidable and hidden, so the visitor is
    # never shown it. Asserted through the diagnostics the single-screen call
    # now answers with, beside the whole-document ones, because the two are the
    # same report about the same screen.
    #
    # Sabotage: made `shown/3` answer the node for an undecidable condition
    # instead of `nil`; the question appeared on the screen the visitor would
    # have been shown and this test went red.
    test "the same screen under an empty context hides the question entirely" do
      root = %{"context" => %{}, "responses" => %{}}

      {:ok, screen, diagnostics} = Screens.resolve_screen(checkout_document(), "checkout", root)

      assert Enum.map(screen.nodes, & &1.key) == ["full_name"]

      assert diagnostics.undecidable_conditions == [
               %{key: "vat_id", condition: "context.is_business == true"}
             ]

      {:ok, resolved} = Screens.resolve(checkout_document(), root)

      assert hd(resolved.screens) == screen
      assert resolved.diagnostics == diagnostics
    end
  end
end
