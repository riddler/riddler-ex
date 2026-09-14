defmodule Riddler.Elements.Type.Button do
  @moduledoc """
  A control a visitor presses, and what pressing it means.

  `outcome` is required and is the name of what the press raises - the whole
  reason a button is worth declaring rather than drawing. `writes` is what
  the press sets, a map whose keys address a response and whose values are
  the two-element constant form, and the host applies it; this package
  carries it through resolution unchanged. `style` is a name a renderer
  owns, and a style this package does not recognize is passed through rather
  than refused, because presentation is not this package's to enumerate.
  `validates` defaults to true, and the opt-out is what lets a Back button
  leave a half-filled screen without an error.

      iex> node = %{type: "button", key: "plan_business", label: "Take the business plan", outcome: "business_chosen", writes: %{"responses.plan" => ["const", "business"]}}
      iex> Riddler.Elements.Type.Button.validate(node)
      []

      iex> node = %{type: "button", key: "plan_business", label: "Go", outcome: "chosen", writes: %{"plan" => ["const", "business"]}}
      iex> [finding] = Riddler.Elements.Type.Button.validate(node)
      iex> finding.code
      "document.invalid_writes"
  """

  @behaviour Riddler.Elements.Type

  alias Riddler.Finding

  @response_path ~r/^responses\.[^.\s][^\s]*$/

  @impl true
  def fields, do: %{required: [:label, :outcome], optional: [:writes, :style, :validates]}

  @impl true
  def validate(node) do
    case Map.fetch(node, :writes) do
      {:ok, writes} when is_map(writes) -> Enum.flat_map(writes, &write_findings(&1, node[:key]))
      {:ok, writes} -> [not_a_map(writes, node[:key])]
      :error -> []
    end
  end

  defp write_findings({path, value}, key) do
    cond do
      not (is_binary(path) and Regex.match?(@response_path, path)) ->
        [
          finding(
            "a write addresses a response as \"responses.<path>\", not #{inspect(path)}",
            key
          )
        ]

      not constant?(value) ->
        [
          finding(
            "the write #{inspect(path)} sets a value in the form [\"const\", value], not #{inspect(value)}",
            key
          )
        ]

      true ->
        []
    end
  end

  defp constant?(["const", _value]), do: true
  defp constant?(_value), do: false

  defp not_a_map(writes, key) do
    finding(
      ~s(writes is a map of "responses.<path>" to ["const", value], not #{inspect(writes)}),
      key
    )
  end

  defp finding(message, key) do
    %Finding{
      code: "document.invalid_writes",
      message: message,
      field: "writes",
      node_key: key
    }
  end
end
