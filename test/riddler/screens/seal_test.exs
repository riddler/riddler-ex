defmodule Riddler.Screens.SealTest do
  use ExUnit.Case, async: true

  alias Riddler.Screens
  alias Riddler.Screens.Document

  # The one secret value any test here carries. It is a placeholder, chosen so
  # that a search for it cannot match anything else.
  @sentinel "PIN-4921-SENTINEL"

  defp pin(key, overrides \\ %{}) do
    Map.merge(
      %{
        "type" => "secret_question",
        "key" => key,
        "label" => "Choose a PIN for your account",
        "required" => true
      },
      overrides
    )
  end

  defp email,
    do: %{"type" => "text_question", "key" => "email", "label" => "Your email"}

  # Two screens: `security` asks for the account PIN, and a backup PIN from
  # one candidate of a variant whose condition nothing here can decide;
  # `recovery` asks for a recovery code, a secret question of its own.
  defp document do
    Document.admit(%{
      "schema_version" => 1,
      "id" => "edoc_signup_screens",
      "screens" => [
        %{
          "key" => "security",
          "title" => "Secure your account",
          "nodes" => [
            email(),
            pin("account_pin"),
            %{
              "type" => "variant",
              "key" => "backup",
              "nodes" => [
                pin("backup_pin", %{"condition" => "context.plan == 'pro'"}),
                %{"type" => "text", "key" => "backup_none", "text" => "No backup PIN."}
              ]
            }
          ]
        },
        %{
          "key" => "recovery",
          "title" => "Recover your account",
          "nodes" => [pin("recovery_code")]
        }
      ]
    })
  end

  # A sealer that records the plaintexts it is handed, in order, and seals the
  # n-th of them as "handle-n": a handle that holds nothing of the plaintext.
  defp recording_sealer do
    test = self()
    counter = :counters.new(1, [])

    fn plaintext ->
      send(test, {:sealed, plaintext})
      :counters.add(counter, 1, 1)
      {:ok, "handle-#{:counters.get(counter, 1)}"}
    end
  end

  defp sealed_plaintexts do
    receive do
      {:sealed, plaintext} -> [plaintext | sealed_plaintexts()]
    after
      0 -> []
    end
  end

  defp codes({:error, findings}), do: Enum.map(findings, &{&1.code, &1.node_key, &1.field})
  defp codes(answer), do: answer

  describe "a seal that succeeds" do
    # Sabotage: made the seal put the sealer's answer in place of the
    # plaintext as a bare string; the response was not the sealed form and
    # this test went red.
    test "each secret plaintext becomes the sealed form and every other response is untouched" do
      responses = %{
        "email" => "sam@example.com",
        "account_pin" => @sentinel,
        "backup_pin" => "PIN-0000-BACKUP",
        "referral" => "friend"
      }

      assert Screens.seal_secrets(document(), "security", responses, recording_sealer()) ==
               {:ok,
                %{
                  "email" => "sam@example.com",
                  "account_pin" => %{"sealed" => "handle-1"},
                  "backup_pin" => %{"sealed" => "handle-2"},
                  "referral" => "friend"
                }}

      assert sealed_plaintexts() == [@sentinel, "PIN-0000-BACKUP"]
    end

    # Sabotage (required): kept the plaintext beside the sealed form, putting
    # %{"sealed" => handle, "plaintext" => plaintext} in the response; the
    # sealed output held a plaintext key and the sentinel, and this test went
    # red.
    test "the sealed output holds no plaintext key and nothing of the plaintext" do
      {:ok, sealed} =
        Screens.seal_secrets(
          document(),
          "security",
          %{"account_pin" => @sentinel},
          recording_sealer()
        )

      assert sealed["account_pin"] == %{"sealed" => "handle-1"}
      assert Map.keys(sealed["account_pin"]) == ["sealed"]
      refute inspect(sealed, limit: :infinity, printable_limit: :infinity) =~ @sentinel
    end

    # Sabotage: made the seal walk only the screen's top-level nodes; the
    # variant's candidate was not sealed and this test went red.
    test "a secret question in a variant's candidate is sealed whatever its condition" do
      assert {:ok, %{"backup_pin" => %{"sealed" => "handle-1"}}} =
               Screens.seal_secrets(
                 document(),
                 "security",
                 %{"backup_pin" => @sentinel},
                 recording_sealer()
               )

      assert sealed_plaintexts() == [@sentinel]
    end

    # Sabotage: dropped the uniq_by from first_per_key/1; the wrong shape was
    # refused twice, once per node, and this test went red.
    test "a key two nodes declare, in a document no one validated, is sealed and refused once" do
      document =
        Document.admit(%{
          "schema_version" => 1,
          "id" => "edoc_signup_screens",
          "screens" => [
            %{
              "key" => "security",
              "title" => "Secure your account",
              "nodes" => [pin("account_pin"), pin("account_pin", %{"label" => "Again"})]
            }
          ]
        })

      assert {:error, _duplicate_key} = Document.validate(document)

      assert Screens.seal_secrets(
               document,
               "security",
               %{"account_pin" => @sentinel},
               recording_sealer()
             ) == {:ok, %{"account_pin" => %{"sealed" => "handle-1"}}}

      assert sealed_plaintexts() == [@sentinel]

      assert codes(
               Screens.seal_secrets(
                 document,
                 "security",
                 %{"account_pin" => [@sentinel]},
                 recording_sealer()
               )
             ) == [{"response.invalid_shape", "account_pin", "type"}]
    end

    # Sabotage: dropped the sealed form from what a call leaves alone; the
    # held handle was passed to the sealer and sealed again, and this test
    # went red.
    test "a response already sealed is left as it is and the sealer is not called for it" do
      responses = %{"account_pin" => %{"sealed" => "held-handle"}, "backup_pin" => @sentinel}

      assert Screens.seal_secrets(document(), "security", responses, recording_sealer()) ==
               {:ok,
                %{
                  "account_pin" => %{"sealed" => "held-handle"},
                  "backup_pin" => %{"sealed" => "handle-1"}
                }}

      assert sealed_plaintexts() == [@sentinel]
    end

    # Sabotage: made a whitespace-only plaintext count as one to seal; the
    # blank response came back held and this test went red.
    test "absent, null and whitespace-only responses are left as written and never sealed" do
      responses = %{"account_pin" => nil, "backup_pin" => "   "}

      assert Screens.seal_secrets(document(), "security", responses, recording_sealer()) ==
               {:ok, responses}

      assert sealed_plaintexts() == []
    end

    # Sabotage: made the other-screen check refuse a sealed form too; the held
    # recovery code was refused and this test went red.
    test "another screen's secret question nothing answered or held is left as it is" do
      responses = %{"recovery_code" => %{"sealed" => "held-handle"}, "account_pin" => @sentinel}

      assert {:ok, %{"recovery_code" => %{"sealed" => "held-handle"}}} =
               Screens.seal_secrets(document(), "security", responses, recording_sealer())

      assert {:ok, %{"recovery_code" => " "}} =
               Screens.seal_secrets(
                 document(),
                 "security",
                 %{"recovery_code" => " "},
                 recording_sealer()
               )
    end

    # Sabotage: made seal_secrets/4 answer {:error, :no_such_screen} for every
    # screen with no secret question; this test went red.
    test "a screen with no secret question answers the responses unchanged" do
      document =
        Document.admit(%{
          "schema_version" => 1,
          "id" => "edoc_signup_screens",
          "screens" => [%{"key" => "contact", "title" => "Contact", "nodes" => [email()]}]
        })

      responses = %{"email" => "sam@example.com"}

      assert Screens.seal_secrets(document, "contact", responses, recording_sealer()) ==
               {:ok, responses}

      assert sealed_plaintexts() == []
    end
  end

  describe "the refusals that need no sealer" do
    # Sabotage: made the own-screen check accept any shape; the list came back
    # sealed through to the engine unrefused and this test went red.
    test "a response of the wrong shape to the screen's secret question is response.invalid_shape" do
      answer =
        Screens.seal_secrets(
          document(),
          "security",
          %{"account_pin" => [@sentinel], "backup_pin" => "PIN-0000-BACKUP"},
          recording_sealer()
        )

      assert codes(answer) == [{"response.invalid_shape", "account_pin", "type"}]
      assert sealed_plaintexts() == []
    end

    # Sabotage: made the other-screen check answer [] for a plaintext; the
    # recovery code went through unsealed and this test went red.
    test "a plaintext or a wrong shape to another screen's secret question is response.unsealed_secret" do
      for response <- [@sentinel, 42] do
        answer =
          Screens.seal_secrets(
            document(),
            "security",
            %{"recovery_code" => response, "account_pin" => "PIN-0000-ACCOUNT"},
            recording_sealer()
          )

        assert codes(answer) == [{"response.unsealed_secret", "recovery_code", "sealed"}]
      end

      assert sealed_plaintexts() == []
    end

    # Sabotage: stopped the refusals at the first finding; the second came
    # back missing and this test went red.
    test "every refusal is found across the call, in document order, before any seal" do
      answer =
        Screens.seal_secrets(
          document(),
          "security",
          %{
            "recovery_code" => @sentinel,
            "backup_pin" => %{"sealed" => "h", "pin" => @sentinel},
            "account_pin" => "PIN-0000-ACCOUNT"
          },
          recording_sealer()
        )

      assert codes(answer) == [
               {"response.invalid_shape", "backup_pin", "type"},
               {"response.unsealed_secret", "recovery_code", "sealed"}
             ]

      assert sealed_plaintexts() == []
    end
  end

  describe "a sealer that does not seal" do
    # Sabotage (required): put the plaintext in the seal_failed message, its
    # tail "so no response was sealed" made "so #{plaintext} was not sealed";
    # the sentinel was in the finding and this test went red.
    test "a sealer answering {:error, :boom} leaves the sentinel in no finding and no returned map" do
      boom = fn _plaintext -> {:error, :boom} end

      answer =
        Screens.seal_secrets(
          document(),
          "security",
          %{"account_pin" => @sentinel},
          boom
        )

      assert codes(answer) == [{"response.seal_failed", "account_pin", "sealed"}]
      {:error, [finding]} = answer
      assert finding.author_message == nil

      seen = inspect(answer, limit: :infinity, printable_limit: :infinity)
      refute seen =~ @sentinel
      refute seen =~ "boom"
    end

    # Sabotage: matched {:ok, _} rather than {:ok, string}; the number came
    # back as the sealed form and this test went red.
    test "a sealer answering anything but {:ok, string} is response.seal_failed" do
      for answer <- [{:ok, 42}, {:ok, nil}, :ok, "sealed", {:error, @sentinel}] do
        sealer = fn _plaintext -> answer end

        result =
          Screens.seal_secrets(document(), "security", %{"account_pin" => @sentinel}, sealer)

        assert codes(result) == [{"response.seal_failed", "account_pin", "sealed"}]
        refute inspect(result, limit: :infinity, printable_limit: :infinity) =~ @sentinel
      end
    end

    # Sabotage: applied the sealer to every plaintext ahead of the seal loop,
    # past the first failure; the backup PIN reached the sealer and this test
    # went red.
    test "the first failed seal stops the call: no partly sealed map, no further sealer call" do
      test = self()

      sealer = fn plaintext ->
        send(test, {:sealed, plaintext})
        if plaintext == "PIN-0000-ACCOUNT", do: {:error, :key_unavailable}, else: {:ok, "h"}
      end

      answer =
        Screens.seal_secrets(
          document(),
          "security",
          %{"account_pin" => "PIN-0000-ACCOUNT", "backup_pin" => @sentinel},
          sealer
        )

      assert codes(answer) == [{"response.seal_failed", "account_pin", "sealed"}]
      assert sealed_plaintexts() == ["PIN-0000-ACCOUNT"]
    end

    # Sabotage: wrapped the sealer call in a rescue answering seal_failed; the
    # raise was swallowed and this test went red.
    test "a sealer that raises raises through the call" do
      raising = fn _plaintext -> raise ArgumentError, "the vault is closed" end

      assert_raise ArgumentError, "the vault is closed", fn ->
        Screens.seal_secrets(document(), "security", %{"account_pin" => @sentinel}, raising)
      end
    end
  end

  # Sabotage: made the screen lookup fall back to the first screen; the
  # unknown key sealed the security screen and this test went red.
  test "a screen key the document does not declare is {:error, :no_such_screen}" do
    assert Screens.seal_secrets(document(), "billing", %{"account_pin" => @sentinel}, fn _ ->
             {:ok, "h"}
           end) == {:error, :no_such_screen}
  end
end
