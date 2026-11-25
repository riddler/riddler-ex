defmodule Riddler.Screens.SecretQuestionTest do
  use ExUnit.Case, async: true

  doctest Riddler.Screens.Type.SecretQuestion

  alias Riddler.Journey
  alias Riddler.Screens
  alias Riddler.Screens.Document

  # The one secret value any test here carries. It is a placeholder, chosen so
  # that a search for it cannot match anything else.
  @sentinel "PIN-4921-SENTINEL"

  defp document(screens) do
    %{"schema_version" => 1, "id" => "edoc_signup_screens", "screens" => screens}
  end

  defp screen(key, nodes), do: %{"key" => key, "title" => "Secure your account", "nodes" => nodes}

  defp pin(overrides \\ %{}) do
    Map.merge(
      %{
        "type" => "secret_question",
        "key" => "account_pin",
        "label" => "Choose a PIN for your account",
        "required" => true
      },
      overrides
    )
  end

  defp admitted(nodes), do: Document.admit(document([screen("security", nodes)]))

  defp findings(nodes) do
    case Document.validate(admitted(nodes)) do
      {:ok, _document} -> []
      {:error, findings} -> Enum.map(findings, &{&1.code, &1.element_key, &1.field})
    end
  end

  defp validated(response) do
    root = if response == :absent, do: %{}, else: %{"responses" => %{"account_pin" => response}}
    Screens.validate_screen(admitted([pin()]), "security", root)
  end

  describe "admission" do
    # Sabotage: removed the "secret_question" row from the registry; the node
    # was document.unknown_type and this test went red.
    test "a secret question carrying key, label, required and help is admitted with no finding" do
      node = pin(%{"help" => "You will type it each time you sign in, {{ context.first_name }}."})
      document = admitted([node])

      assert findings([node]) == []

      assert [
               %{
                 type: "secret_question",
                 key: "account_pin",
                 label: "Choose a PIN for your account",
                 required: true,
                 help: "You will type it each time you sign in, {{ context.first_name }}."
               }
             ] = hd(document.screens).elements
    end

    # Sabotage: added :format to the type's optional fields;
    # the admitted node carried it and this test went red.
    test "a placeholder, a format or a pattern on a secret question is dropped with no finding" do
      node =
        pin(%{"placeholder" => "Four digits", "format" => "pattern", "pattern" => "[0-9]{4}"})

      [admitted_node] = hd(admitted([node]).screens).elements

      assert findings([node]) == []
      refute Map.has_key?(admitted_node, :placeholder)
      refute Map.has_key?(admitted_node, :format)
      refute Map.has_key?(admitted_node, :pattern)
    end

    # Sabotage: dropped :default from the type's initial values; the default
    # was dropped at admit with no finding and this test went red.
    test "a default or a prefill is document.secret_initial_value naming which, default first" do
      assert findings([pin(%{"default" => @sentinel})]) ==
               [{"document.secret_initial_value", "account_pin", "default"}]

      assert findings([pin(%{"prefill" => "context.account_pin"})]) ==
               [{"document.secret_initial_value", "account_pin", "prefill"}]

      assert findings([pin(%{"prefill" => "context.account_pin", "default" => @sentinel})]) == [
               {"document.secret_initial_value", "account_pin", "default"},
               {"document.secret_initial_value", "account_pin", "prefill"}
             ]
    end

    # Sabotage: interpolated the field's value into the initial value message;
    # the sentinel was in the message and this test went red.
    test "the initial value finding names the field and never what it holds" do
      {:error, [finding]} = Document.validate(admitted([pin(%{"default" => @sentinel})]))

      refute finding.message =~ @sentinel
      assert finding.message =~ "default"
    end

    # Sabotage: removed :label from the type's required fields; no
    # missing_field was raised and this test went red.
    test "a secret question with no label, or a required that is not a boolean, is refused" do
      assert findings([Map.delete(pin(), "label")]) ==
               [{"document.missing_field", "account_pin", "label"}]

      assert findings([pin(%{"required" => "yes"})]) ==
               [{"document.invalid_required", "account_pin", "required"}]
    end

    # Sabotage: removed :help from the document's template fields; the help
    # template was not compiled at admit and this test went red.
    test "a help holding a construct outside the template subset is document.invalid_template" do
      assert [{"document.invalid_template", "account_pin", _field}] =
               findings([pin(%{"help" => "{{ context.first_name | strip_html }}"})])
    end
  end

  describe "a reference to a secret question's response" do
    defp text(key, source, overrides \\ %{}),
      do: Map.merge(%{"type" => "text", "key" => key, "text" => source}, overrides)

    # Sabotage: made the reference check answer [] for every node; no
    # document.secret_reference was raised and this test went red.
    test "a template, a condition and a write naming it are each refused on the node carrying it" do
      nodes = [
        pin(),
        text("pin_echo", "Your PIN is {{ responses.account_pin }}."),
        text("pin_thanks", "Your account is protected.", %{
          "condition" => "responses.account_pin != ''"
        }),
        %{
          "type" => "button",
          "key" => "pin_skip",
          "label" => "Skip",
          "outcome" => "skipped",
          "writes" => %{"responses.account_pin" => ["const", @sentinel]}
        }
      ]

      assert findings(nodes) == [
               {"document.secret_reference", "pin_echo", "text"},
               {"document.secret_reference", "pin_thanks", "condition"},
               {"document.secret_reference", "pin_skip", "writes"}
             ]
    end

    # Sabotage: made names_response?/2 compare the whole path to
    # ["responses", key]; a path under the response was not refused and this
    # test went red.
    test "a path under the response, a bracketed name, a filter argument and a tag operand are references" do
      sources = [
        "{{ responses.account_pin.size }}",
        ~s({{ responses["account_pin"] }}),
        "{{ context.first_name | append: responses.account_pin }}",
        "{% if responses.account_pin == 'PIN' %}Weak.{% endif %}"
      ]

      for source <- sources do
        assert findings([pin(), text("pin_echo", source)]) ==
                 [{"document.secret_reference", "pin_echo", "text"}],
               source
      end

      conditions = [
        "responses.account_pin.length > 3",
        ~s(responses["account_pin"] == "PIN"),
        "len(responses.account_pin) > 3"
      ]

      for condition <- conditions do
        node = text("pin_thanks", "Thanks.", %{"condition" => condition})

        assert findings([pin(), node]) ==
                 [{"document.secret_reference", "pin_thanks", "condition"}],
               condition
      end
    end

    # Sabotage: read the secret keys from the first screen only; the secret
    # question on the second screen was missed, the reference on the first was
    # not refused and this test went red.
    test "a reference on another screen, in a variant candidate or on the question itself is refused" do
      raw =
        document([
          screen("welcome", [
            %{
              "type" => "variant",
              "key" => "welcome_variant",
              "nodes" => [text("welcome_pin", "PIN: {{ responses.account_pin }}")]
            }
          ]),
          screen("security", [pin()])
        ])

      {:error, found} = Document.validate(Document.admit(raw))

      assert Enum.map(found, &{&1.code, &1.element_key, &1.field}) ==
               [{"document.secret_reference", "welcome_pin", "text"}]

      own = pin(%{"label" => "Confirm {{ responses.account_pin }}"})
      assert findings([own]) == [{"document.secret_reference", "account_pin", "label"}]
    end

    # Sabotage: dropped the key from the message, naming "a secret question";
    # the message no longer named "account_pin" and this test went red.
    test "the finding's message names the secret question's key" do
      {:error, [finding]} =
        Document.validate(admitted([pin(), text("pin_echo", "{{ responses.account_pin }}")]))

      assert finding.message =~ ~s("account_pin")
    end

    # Sabotage: matched a path on its prefix string rather than its segments;
    # responses.account_pin_hint was refused and this test went red.
    test "a response whose key merely starts with the secret question's key is not a reference" do
      nodes = [
        pin(),
        text("pin_hint", "Hint: {{ responses.account_pin_hint }}", %{
          "condition" => "responses.account_pin_hint != ''"
        })
      ]

      assert findings(nodes) == []
    end
  end

  describe "resolution" do
    # Sabotage: made reading/2 answer the root unchanged; the template
    # rendered the response and this test went red.
    test "the root a template and a condition read carries no secret question's response" do
      raw =
        document([
          screen("security", [
            pin(%{"help" => "Hi {{ context.first_name }}"}),
            %{
              "type" => "text",
              "key" => "pin_echo",
              "text" => "PIN: {{ responses.account_pin }}"
            },
            %{
              "type" => "text",
              "key" => "pin_thanks",
              "condition" => "responses.account_pin != ''",
              "text" => "Thanks, {{ responses.first_name }}."
            },
            %{
              "type" => "text",
              "key" => "name_echo",
              "text" => "Hello {{ responses.first_name }}."
            }
          ])
        ])

      root = %{
        "context" => %{"first_name" => "Ada"},
        "responses" => %{"account_pin" => @sentinel, "first_name" => "Ada"}
      }

      {:ok, screen, diagnostics} = Screens.resolve_screen(Document.admit(raw), "security", root)

      assert Enum.map(screen.elements, & &1.key) == ["account_pin", "pin_echo", "name_echo"]
      assert Enum.at(screen.elements, 0).help == "Hi Ada"
      assert Enum.at(screen.elements, 1).text == "PIN: "
      assert Enum.at(screen.elements, 2).text == "Hello Ada."

      assert diagnostics == %{
               missing_variables: [%{key: "pin_echo", variable: "responses.account_pin"}],
               undecidable_conditions: [
                 %{key: "pin_thanks", condition: "responses.account_pin != ''"}
               ]
             }

      {:ok, resolved} = Screens.resolve(Document.admit(raw), root)
      assert resolved.diagnostics == diagnostics
    end

    # Sabotage: made presented/2 delete only :condition; the default reached
    # the resolved node and this test went red.
    test "a resolved secret question carries no condition, default or prefill" do
      node =
        pin(%{
          "condition" => "context.signed_in",
          "default" => @sentinel,
          "prefill" => "context.p"
        })

      {:ok, screen, _} =
        Screens.resolve_screen(admitted([node]), "security", %{
          "context" => %{"signed_in" => true}
        })

      assert [resolved] = screen.elements
      assert Map.keys(resolved) |> Enum.sort() == [:held, :key, :label, :required, :type]
    end
  end

  describe "presentation" do
    @sealed_sentinel "SEALED-SENTINEL"

    defp patron_document do
      Document.admit(%{
        "schema_version" => 1,
        "id" => "patron_registration",
        "screens" => [
          %{
            "key" => "card_pin",
            "title" => "Protect your card",
            "nodes" => [
              %{
                "type" => "secret_question",
                "key" => "library_pin",
                "label" => "Choose a PIN for your library card",
                "help" => "You will type it at the self-checkout.",
                "required" => true
              },
              %{
                "type" => "button",
                "key" => "pin_next",
                "label" => "Continue",
                "outcome" => "pin_chosen"
              }
            ]
          }
        ]
      })
    end

    defp pin_root(response), do: %{"responses" => %{"library_pin" => response}}

    defp presented_pin(response) do
      {:ok, answer} =
        Journey.present(patron_document(), {:screen, "card_pin"}, pin_root(response))

      answer
    end

    # Mutation: in `lib/riddler/screens.ex`, made `held/2` answer
    # `Map.take(root["responses"], Document.secret_keys(document))` and made the
    # secret clause of `presented/2` put `Map.get(held, node[:key])` under
    # `:held`, carrying the held response onto the node; the plaintext and the
    # sealed sentinel were each in the encoded answer and this test went red.
    test "neither the plaintext nor the sealed string is anywhere in the encoded presented answer" do
      for {response, held} <- [{@sentinel, false}, {%{"sealed" => @sealed_sentinel}, true}] do
        answer = presented_pin(response)
        encoded = JSON.encode!(answer)

        refute encoded =~ @sentinel, inspect(response)
        refute encoded =~ @sealed_sentinel, inspect(response)

        {:ok, screen, _diagnostics} =
          Screens.resolve_screen(patron_document(), "card_pin", pin_root(response))

        resolved = inspect(screen, limit: :infinity, printable_limit: :infinity)
        refute resolved =~ @sentinel
        refute resolved =~ @sealed_sentinel

        assert [
                 %{
                   "type" => "secret_question",
                   "key" => "library_pin",
                   "label" => "Choose a PIN for your library card",
                   "help" => "You will type it at the self-checkout.",
                   "required" => true,
                   "held" => ^held
                 } = node,
                 _button
               ] = answer["screen"]["elements"]

        refute Map.has_key?(node, "value")
      end
    end

    # Sabotage: made resolve_screen/3 read held from the root a condition and a
    # template read (`held(document, reading(document, root))`), which carries
    # no secret response; the sealed form presented held false and this test
    # went red.
    test "held is true exactly where the host's root holds the sealed form" do
      not_held = [
        :absent,
        nil,
        "",
        @sentinel,
        [@sentinel],
        %{},
        %{"sealed" => 7},
        %{"sealed" => @sealed_sentinel, "pin" => @sentinel}
      ]

      assert presented_held(%{"sealed" => @sealed_sentinel}) == true

      for response <- not_held do
        assert presented_held(response) == false, inspect(response)
      end
    end

    # Sabotage: made resolve/2 read held from the root a condition and a
    # template read, after `reading/2`; the whole document's resolution
    # presented held false and this test went red.
    test "held is set in a variant's winner and by resolve/2 as by resolve_screen/3" do
      document =
        Document.admit(
          document([
            screen("security", [
              %{
                "type" => "variant",
                "key" => "pin_variant",
                "nodes" => [pin(%{"condition" => "context.signed_in"})]
              }
            ])
          ])
        )

      root = %{
        "context" => %{"signed_in" => true},
        "responses" => %{"account_pin" => %{"sealed" => @sealed_sentinel}}
      }

      {:ok, screen, _diagnostics} = Screens.resolve_screen(document, "security", root)
      assert [%{key: "account_pin", held: true}] = screen.elements

      {:ok, resolved} = Screens.resolve(document, root)
      assert [%{key: "account_pin", held: true}] = hd(resolved.screens).elements
    end

    defp presented_held(:absent) do
      {:ok, answer} = Journey.present(patron_document(), {:screen, "card_pin"}, %{})
      hd(answer["screen"]["elements"])["held"]
    end

    defp presented_held(response), do: hd(presented_pin(response)["screen"]["elements"])["held"]
  end

  describe "response validation" do
    # Sabotage: made secret_findings/2 answer [] for a blank response; a
    # required secret question with nothing answered passed and this test went
    # red.
    test "nothing answered on a required secret question is response.required" do
      for response <- [:absent, nil, "", "   "] do
        assert {:error,
                [%{code: "response.required", element_key: "account_pin", field: "required"}]} =
                 validated(response),
               inspect(response)
      end

      not_required = admitted([pin(%{"required" => false})])
      assert Screens.validate_screen(not_required, "security", %{}) == :ok
    end

    # Sabotage: dropped the map_size check from sealed?/1; the sealed form
    # with a second key passed and this test went red.
    test "a plaintext and the sealed form pass; anything else is response.invalid_shape" do
      assert validated(@sentinel) == :ok
      assert validated(%{"sealed" => @sentinel}) == :ok

      for response <- [
            [@sentinel],
            7,
            true,
            %{"sealed" => 7},
            %{"sealed" => @sentinel, "pin" => @sentinel},
            %{}
          ] do
        assert {:error,
                [%{code: "response.invalid_shape", element_key: "account_pin", field: "type"}]} =
                 validated(response),
               inspect(response)
      end
    end

    # Sabotage: made the secret clause fall through to the generic text path;
    # the four-digit PIN failed the email format admitted by the mutation and
    # this test went red.
    test "no format is put to a secret response" do
      document = admitted([pin(%{"format" => "email"})])

      assert Screens.validate_screen(document, "security", %{
               "responses" => %{"account_pin" => @sentinel}
             }) ==
               :ok
    end

    # Sabotage: made validate_screen/4 hand the full root to the condition's
    # second reading; the message read "does not answer true or false" and
    # this test went red.
    test "a condition naming the secret's response is undecidable when validated" do
      nodes = [
        pin(%{"required" => false}),
        %{
          "type" => "text",
          "key" => "pin_thanks",
          "condition" => "responses.account_pin != ''",
          "text" => "Thanks."
        }
      ]

      {:error, [finding]} =
        Screens.validate_screen(admitted(nodes), "security", %{
          "responses" => %{"account_pin" => @sentinel}
        })

      assert {finding.code, finding.element_key} == {"response.undecidable", "pin_thanks"}
      assert finding.message =~ "could not be decided"
    end

    # Sabotage: made opted_out?/2 answer false for every press; the Back press
    # raised response.required and this test went red.
    test "a secret question a condition hid is not checked, and a validates false press opts out" do
      hidden = admitted([pin(%{"condition" => "context.signed_in"})])

      assert Screens.validate_screen(hidden, "security", %{"context" => %{"signed_in" => false}}) ==
               :ok

      back = %{
        "type" => "button",
        "key" => "pin_back",
        "label" => "Back",
        "outcome" => "went_back",
        "validates" => false
      }

      assert Screens.validate_screen(admitted([pin(), back]), "security", %{}, "pin_back") == :ok
    end
  end

  # Sabotage: interpolated inspect(response) into the secret question's shape
  # message (the message the record keeps free of the response; the question
  # declares no format, so no format message can be reached); the sentinel was
  # in a finding and this test went red.
  test "the sentinel occurs nowhere in the admitted document, the resolved screen, the diagnostics or any finding" do
    raw =
      document([
        screen("security", [
          pin(%{"help" => "Keep it to yourself.", "format" => "email"}),
          %{"type" => "text", "key" => "pin_echo", "text" => "PIN: {{ responses.account_pin }}"},
          %{
            "type" => "text",
            "key" => "pin_thanks",
            "condition" => "responses.account_pin == 'PIN'",
            "text" => "Thanks."
          },
          %{"type" => "button", "key" => "pin_next", "label" => "Continue", "outcome" => "chosen"}
        ])
      ])

    document = Document.admit(raw)

    responses = [
      @sentinel,
      "  #{@sentinel}  ",
      [@sentinel],
      %{"sealed" => @sentinel},
      %{"sealed" => @sentinel, "pin" => @sentinel},
      %{"pin" => @sentinel},
      {@sentinel}
    ]

    seen =
      for response <- responses do
        root = %{"context" => %{}, "responses" => %{"account_pin" => response}}

        [
          document,
          Document.validate(document),
          Screens.resolve(document, root),
          Screens.resolve_screen(document, "security", root),
          Screens.validate_screen(document, "security", root),
          Screens.validate_screen(document, "security", root, "pin_next"),
          Journey.present(document, {:screen, "security"}, root)
        ]
      end

    for answer <- List.flatten(seen) do
      refute inspect(answer, limit: :infinity, printable_limit: :infinity) =~ @sentinel
    end

    # The run above reached the shape message the mutation writes into.
    assert {:error, findings} =
             Screens.validate_screen(document, "security", %{
               "responses" => %{"account_pin" => [@sentinel]}
             })

    assert Enum.map(findings, & &1.code) == ["response.undecidable", "response.invalid_shape"]
  end
end
