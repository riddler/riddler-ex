defmodule Riddler.Elements.Type.Variant do
  @moduledoc """
  A container that shows one of several candidates: first match wins.

  The candidates are considered in order, and the first whose condition
  holds is the winner; the winner replaces the container in the resolved
  output, so a host that can render a document can render a resolved one and
  nothing downstream needs to know a container was ever there. A candidate
  with no condition is unconditional and wins if it is reached, so the last
  candidate with no condition is the default.

  Two shapes are refused rather than resolved. A variant with no candidates
  has nothing to win and would disappear silently. And an unconditional
  candidate that is not last makes every candidate after it dead: the
  document says something it cannot mean, and the author is told so at admit
  time rather than discovering it as a screen that never varies.

      iex> node = %{type: "variant", key: "card_notice", nodes: [
      ...>   %{type: "text", key: "card_notice_declined", condition: "context.last_charge_status == 'declined'", text: "Try another card."},
      ...>   %{type: "text", key: "card_notice_default", text: "We will charge the card on file."}
      ...> ]}
      iex> Riddler.Elements.Type.Variant.validate(node)
      []

      iex> [finding] = Riddler.Elements.Type.Variant.validate(%{type: "variant", key: "card_notice", nodes: []})
      iex> finding.code
      "document.empty_variant"
  """

  @behaviour Riddler.Elements.Type

  alias Riddler.Finding

  @impl true
  def fields, do: %{required: [:nodes], optional: []}

  @impl true
  def validate(node) do
    case Map.fetch(node, :nodes) do
      {:ok, []} ->
        [
          %Finding{
            code: "document.empty_variant",
            message: "a variant carries at least one candidate; this one carries none",
            field: "nodes",
            node_key: node[:key]
          }
        ]

      {:ok, candidates} when is_list(candidates) ->
        unreachable(candidates, node[:key])

      _other ->
        []
    end
  end

  # Every unconditional candidate but the last one buries what follows it.
  defp unreachable(candidates, key) do
    candidates
    |> Enum.drop(-1)
    |> Enum.filter(&unconditional?/1)
    |> Enum.map(fn candidate ->
      %Finding{
        code: "document.unreachable_variant_candidate",
        message:
          "the candidate #{inspect(candidate[:key])} carries no condition and is not last, so every candidate after it is unreachable",
        field: "nodes",
        node_key: key
      }
    end)
  end

  defp unconditional?(candidate) when is_map(candidate),
    do: not Map.has_key?(candidate, :condition)

  defp unconditional?(_candidate), do: false
end
