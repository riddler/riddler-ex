defmodule Riddler.ElementsTest do
  use ExUnit.Case, async: true

  doctest Riddler.Elements

  alias Riddler.Elements
  alias Riddler.Elements.Document

  # test/fixtures/signup_screens.json is a verbatim copy of
  # priv/fixtures/signup_screens.json in the statifier_examples repository,
  # read at 9d288c9. Every fixture case below reads the conditions and keys
  # from that file rather than restating them.
  @fixture "test/fixtures/signup_screens.json"

  defp document, do: @fixture |> File.read!() |> Jason.decode!() |> Document.admit()

  defp resolve_screen!(screen_key, root) do
    {:ok, screen} = Elements.resolve_screen(document(), screen_key, root)
    screen
  end

  defp keys(screen), do: Enum.map(screen.nodes, & &1.key)

  defp node(screen, key), do: Enum.find(screen.nodes, &(&1.key == key))

  defp root(responses, context \\ %{}),
    do: %{"context" => context, "responses" => responses}

  # A small credit-card document: the payments host's card notice, whose
  # candidates are considered in order and whose last candidate carries no
  # condition and is therefore the default.
  defp card_document(overrides \\ %{}) do
    Document.admit(%{
      "schema_version" => 1,
      "id" => "edoc_card_notice",
      "screens" => [
        %{
          "key" => "card",
          "title" => "Your card",
          "nodes" => [
            Map.merge(
              %{
                "type" => "variant",
                "key" => "card_notice",
                "nodes" => [
                  %{
                    "type" => "text",
                    "key" => "card_notice_declined",
                    "condition" => "context.last_charge_status == 'declined'",
                    "text" => "The card on file was declined. Try another one."
                  },
                  %{
                    "type" => "text",
                    "key" => "card_notice_expiring",
                    "condition" => "context.card_expires_within_days < 30",
                    "text" => "The card on file expires soon, {{ context.tenant_name }}."
                  },
                  %{
                    "type" => "text",
                    "key" => "card_notice_default",
                    "text" => "We will charge the card on file."
                  }
                ]
              },
              overrides
            )
          ]
        }
      ]
    })
  end

  describe "resolve_screen/3 over the signup fixture" do
    # Sabotage: made the undecidable branch of `evaluate/4` answer `{true, ...}`
    # instead of `{false, ...}`; the greeting appeared in the keys and this
    # test went red.
    test "the account screen with no responses hides the greeting and misses no variable" do
      screen = resolve_screen!("account", root(%{}))

      assert keys(screen) == [
               "account_heading",
               "account_intro",
               "first_name",
               "email",
               "account_continue"
             ]

      {:ok, resolved} = Elements.resolve(document(), root(%{}))
      refute Enum.any?(resolved.diagnostics.missing_variables, &(&1.key in keys(screen)))
    end

    # Sabotage: dropped the `render/3` call from `present/3` so a node kept its
    # template source; the greeting came back with the braces in it and this
    # test went red.
    test "the account screen with a first name renders the greeting" do
      screen = resolve_screen!("account", root(%{"first_name" => "Ada"}))

      assert "account_greeting" in keys(screen)
      assert node(screen, "account_greeting").text == "Nice to meet you, Ada."
    end

    # Sabotage: made `decide/3` treat `{:ok, false}` as shown; the business
    # button and the hint appeared beside the personal button and this test
    # went red.
    test "the plan screen at one seat shows the personal button and hides the hint" do
      screen = resolve_screen!("plan", root(%{"seats" => 1, "first_name" => "Ada"}))

      assert keys(screen) == ["plan_heading", "plan_intro", "seats", "plan_personal", "plan_back"]
    end

    # Sabotage: made `render_field/5` render against an empty map rather than
    # the root; the hint came back with the name rendered away and this test
    # went red.
    test "the plan screen at two seats shows the business button and renders the hint" do
      root = root(%{"seats" => 2, "first_name" => "Ada"})
      screen = resolve_screen!("plan", root)

      assert keys(screen) == [
               "plan_heading",
               "plan_intro",
               "seats",
               "plan_business_hint",
               "plan_business",
               "plan_back"
             ]

      assert node(screen, "plan_business_hint").text ==
               "More than one seat puts you on the business plan, Ada."

      {:ok, resolved} = Elements.resolve(document(), root)
      refute Enum.any?(resolved.diagnostics.missing_variables, &(&1.key == "plan_business_hint"))
    end

    # Sabotage: made `render_field/5` discard the missing list instead of
    # reporting it; the hint still rendered, and the missing-variable
    # assertion went red.
    test "a rendered template reports the variable the root does not carry" do
      root = root(%{"seats" => 2})
      screen = resolve_screen!("plan", root)

      assert node(screen, "plan_business_hint").text ==
               "More than one seat puts you on the business plan, ."

      {:ok, resolved} = Elements.resolve(document(), root)

      assert %{key: "plan_business_hint", variable: "responses.first_name"} in resolved.diagnostics.missing_variables
    end

    # Sabotage: made `resolve_nodes/3` keep a hidden node instead of dropping
    # it; the referral question and its heading appeared at one seat and this
    # test went red.
    test "the confirm screen at one seat hides the referral question" do
      screen = resolve_screen!("confirm", root(%{"seats" => 1, "email" => "ada@example.com"}))

      assert keys(screen) == ["confirm_heading", "confirm_summary", "confirm_finish"]
    end

    # Sabotage: dropped the `Map.delete(node, :condition)` from `present/3`;
    # the referral question came back still carrying its condition and this
    # test went red.
    test "the confirm screen at two seats shows the referral question and no condition" do
      screen =
        resolve_screen!(
          "confirm",
          root(%{"seats" => 2, "first_name" => "Ada", "email" => "a@b.c"})
        )

      assert keys(screen) == [
               "confirm_heading",
               "confirm_summary",
               "confirm_referral_heading",
               "referral",
               "confirm_finish"
             ]

      assert node(screen, "confirm_referral_heading").text == "One more thing, Ada"
      refute Enum.any?(screen.nodes, &Map.has_key?(&1, :condition))
    end

    # Sabotage: made `resolve_screen/3` fall back to the first screen when the
    # key matched nothing; the error tuple never came back and this test went
    # red.
    test "a screen key the document does not declare is an error" do
      assert Elements.resolve_screen(document(), "billing", root(%{})) ==
               {:error, :no_such_screen}
    end
  end

  describe "resolve/2 over the signup fixture" do
    # Sabotage: made the undecidable branch report nothing; the diagnostics
    # list came back empty and this test went red.
    test "an undecidable condition hides its node and names it" do
      {:ok, resolved} = Elements.resolve(document(), root(%{}))
      plan = Enum.find(resolved.screens, &(&1.key == "plan"))

      refute "plan_business_hint" in keys(plan)
      refute "plan_personal" in keys(plan)
      refute "plan_business" in keys(plan)

      assert %{key: "plan_business_hint", condition: "responses.seats > 1"} in resolved.diagnostics.undecidable_conditions

      assert %{key: "plan_personal", condition: "responses.seats <= 1"} in resolved.diagnostics.undecidable_conditions
    end

    # Sabotage: made `present/3` drop `:writes` along with `:condition`; the
    # write map came back absent and this test went red.
    test "a resolved screen carries no condition and every write intact" do
      root = root(%{"seats" => 2, "first_name" => "Ada", "email" => "ada@example.com"})
      {:ok, resolved} = Elements.resolve(document(), root)
      nodes = Enum.flat_map(resolved.screens, & &1.nodes)

      refute Enum.any?(nodes, &Map.has_key?(&1, :condition))

      assert Enum.find(nodes, &(&1.key == "plan_business")).writes == %{
               "responses.plan" => ["const", "business"]
             }
    end

    # Sabotage: made `resolve/2` build the envelope from literals rather than
    # from the document; the id and the metadata came back wrong and this test
    # went red.
    test "the resolved document keeps the envelope and every screen in order" do
      {:ok, resolved} = Elements.resolve(document(), root(%{"seats" => 1}))

      assert resolved.schema_version == 1
      assert resolved.id == "edoc_signup_screens"
      assert resolved.metadata["domain"] == "signup"
      assert Enum.map(resolved.screens, & &1.key) == ["account", "plan", "confirm"]
    end
  end

  describe "resolve/2 over a container" do
    # Sabotage: made `present/3` hand the candidates to `winner/3` in reverse,
    # so the last match won; the declined notice lost to the default and this
    # test went red.
    test "the first candidate whose condition holds replaces the container" do
      root = root(%{}, %{"last_charge_status" => "declined", "card_expires_within_days" => 9})
      {:ok, resolved} = Elements.resolve(card_document(), root)

      assert keys(hd(resolved.screens)) == ["card_notice_declined"]

      assert node(hd(resolved.screens), "card_notice_declined").text ==
               "The card on file was declined. Try another one."
    end

    # Sabotage: made `decide/3` answer `false` for a node carrying no
    # condition; the default never won, the screen came back empty, and this
    # test went red.
    test "the last candidate with no condition is the default" do
      root = root(%{}, %{"last_charge_status" => "ok", "card_expires_within_days" => 90})
      {:ok, resolved} = Elements.resolve(card_document(), root)

      assert keys(hd(resolved.screens)) == ["card_notice_default"]
    end

    # Sabotage: made `shown/3` present a node whose condition came back false;
    # the notice appeared for a host with no card on file and this test went
    # red.
    test "a container's own condition hides it before any candidate is tried" do
      document = card_document(%{"condition" => "context.has_card_on_file == true"})
      root = root(%{}, %{"has_card_on_file" => false})
      {:ok, resolved} = Elements.resolve(document, root)

      assert hd(resolved.screens).nodes == []
      assert resolved.diagnostics.undecidable_conditions == []
    end

    # Sabotage: made an undecidable candidate condition win its container
    # instead of being passed over; the declined notice was shown against a
    # context that carried nothing and this test went red.
    test "an undecidable candidate is passed over and reported" do
      {:ok, resolved} = Elements.resolve(card_document(), root(%{}))

      assert keys(hd(resolved.screens)) == ["card_notice_default"]

      assert resolved.diagnostics.undecidable_conditions == [
               %{
                 key: "card_notice_declined",
                 condition: "context.last_charge_status == 'declined'"
               },
               %{key: "card_notice_expiring", condition: "context.card_expires_within_days < 30"}
             ]
    end

    # Sabotage: made `present/3` treat a container as an ordinary node; the
    # `variant` itself survived into the output and this test went red.
    test "a container no candidate wins resolves to nothing" do
      document =
        Document.admit(%{
          "schema_version" => 1,
          "id" => "edoc_card_notice",
          "screens" => [
            %{
              "key" => "card",
              "title" => "Your card",
              "nodes" => [
                %{
                  "type" => "variant",
                  "key" => "card_notice",
                  "nodes" => [
                    %{
                      "type" => "text",
                      "key" => "card_notice_declined",
                      "condition" => "context.last_charge_status == 'declined'",
                      "text" => "The card on file was declined."
                    }
                  ]
                }
              ]
            }
          ]
        })

      {:ok, resolved} = Elements.resolve(document, root(%{}, %{"last_charge_status" => "ok"}))

      assert hd(resolved.screens).nodes == []
    end
  end

  describe "the root" do
    # Sabotage: made `normalize/1` hand the caller's map through untouched;
    # the third root rendered instead of coming back empty and this test went
    # red.
    test "the root is exactly context and responses, whatever else the caller passes" do
      document =
        Document.admit(%{
          "schema_version" => 1,
          "id" => "edoc_card_notice",
          "screens" => [
            %{
              "key" => "card",
              "title" => "Your card",
              "nodes" => [
                %{
                  "type" => "text",
                  "key" => "card_intro",
                  "text" => "Charging {{ visitor.name }}."
                }
              ]
            }
          ]
        })

      root = %{"responses" => %{}, "visitor" => %{"name" => "Acme"}}
      {:ok, resolved} = Elements.resolve(document, root)

      assert hd(hd(resolved.screens).nodes).text == "Charging ."

      assert resolved.diagnostics.missing_variables == [
               %{key: "card_intro", variable: "visitor.name"}
             ]
    end
  end
end
