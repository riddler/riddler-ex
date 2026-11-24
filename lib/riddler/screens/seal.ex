defmodule Riddler.Screens.Seal do
  @moduledoc false

  # The work of `Riddler.Screens.seal_secrets/4` once the screen it names has
  # been found. The order is the amendment's to `docs/adr/0002-element-document.md`
  # headed "a `secret_question` node type": every refusal that needs no sealer
  # is found across the whole call first, in document order, and only a call
  # with none of them applies the sealer, once per plaintext, in document
  # order, stopping at the first answer that is not a sealed string.
  #
  # No finding here carries anything of a response, of the sealer's answer or
  # of a sealed string: each names the secret question by its key, which is not
  # a secret. The sealer's answer is matched and dropped. A sealer that raises
  # raises through this call: it is the host's own function, and nothing here
  # rescues it.

  alias Riddler.Finding
  alias Riddler.Screens.Document
  alias Riddler.Screens.Type.SecretQuestion

  @spec seal(Document.t(), map(), term(), map(), (String.t() -> term())) ::
          {:ok, map()} | {:error, [Finding.t()]}
  def seal(document, screen, screen_key, responses, sealer) do
    own = screen |> Document.secret_questions() |> first_per_key()
    own_keys = MapSet.new(own, & &1.key)

    case refusals(document, own_keys, screen_key, responses) do
      [] -> seal_each(own, responses, sealer)
      findings -> {:error, findings}
    end
  end

  # -- the refusals that need no sealer ---------------------------------------

  # Every secret question the document declares, once per key and in document
  # order. A key the named screen declares is held to the screen's rule - a
  # response of the wrong shape is refused - and any other is held to the
  # rule for a question this call does not seal: a response that is not
  # absent, nothing answered or the sealed form is refused, because sealing it
  # here would make it held without the validation of its own screen and
  # passing it on would hand the engine a plaintext.
  defp refusals(document, own_keys, screen_key, responses) do
    document.screens
    |> Enum.flat_map(&Document.secret_questions/1)
    |> first_per_key()
    |> Enum.flat_map(fn node ->
      response = Map.get(responses, node.key)

      if MapSet.member?(own_keys, node.key),
        do: own_refusal(node, response),
        else: other_refusal(node, response, screen_key)
    end)
  end

  defp own_refusal(node, response) do
    if left_alone?(response) or is_binary(response) do
      []
    else
      [
        finding(
          node,
          "response.invalid_shape",
          "type",
          "the secret question #{inspect(node.key)} is answered with the text the visitor typed, or with the sealed form a host keeps, and the response is neither"
        )
      ]
    end
  end

  defp other_refusal(node, response, screen_key) do
    if left_alone?(response) do
      []
    else
      [
        finding(
          node,
          "response.unsealed_secret",
          "sealed",
          "the response to the secret question #{inspect(node.key)} is not sealed, and that question is not on the screen #{inspect(screen_key)}, so this call does not seal it"
        )
      ]
    end
  end

  # What a call leaves as it is: no response, nothing answered, or the sealed
  # form. Sealing nothing answered would make an empty answer held, which
  # satisfies `required`; sealing a sealed form would seal a handle.
  defp left_alone?(response), do: blank?(response) or SecretQuestion.sealed?(response)

  defp blank?(nil), do: true
  defp blank?(response) when is_binary(response), do: String.trim(response) == ""
  defp blank?(_response), do: false

  # -- the seal -----------------------------------------------------------------

  defp seal_each(own, responses, sealer) do
    Enum.reduce_while(own, {:ok, responses}, fn node, {:ok, sealed} ->
      response = Map.get(sealed, node.key)

      if left_alone?(response),
        do: {:cont, {:ok, sealed}},
        else: apply_sealer(node, response, sealed, sealer)
    end)
  end

  defp apply_sealer(node, plaintext, sealed, sealer) do
    case sealer.(plaintext) do
      {:ok, handle} when is_binary(handle) ->
        {:cont, {:ok, Map.put(sealed, node.key, %{"sealed" => handle})}}

      _not_a_sealed_string ->
        {:halt,
         {:error,
          [
            finding(
              node,
              "response.seal_failed",
              "sealed",
              "the sealer did not seal the response to the secret question #{inspect(node.key)}: it answered something other than {:ok, string}, so no response was sealed"
            )
          ]}}
    end
  end

  # -- helpers ------------------------------------------------------------------

  # A key declared twice - two of a variant's candidates asking the same
  # secret question - names one response, which is checked and sealed once,
  # under the first node that declares it.
  defp first_per_key(nodes), do: Enum.uniq_by(nodes, & &1.key)

  defp finding(node, code, field, message) do
    %Finding{
      code: code,
      message: message,
      field: field,
      element_key: Finding.element_key(node.key)
    }
  end
end
