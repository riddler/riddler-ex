defmodule Riddler.Screens.Type.Button do
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
      iex> Riddler.Screens.Type.Button.validate(node)
      []

      iex> node = %{type: "button", key: "plan_business", label: "Go", outcome: "chosen", writes: %{"plan" => ["const", "business"]}}
      iex> [finding] = Riddler.Screens.Type.Button.validate(node)
      iex> finding.code
      "document.invalid_writes"
  """

  @behaviour Riddler.Screens.Type

  alias Riddler.Finding

  @response_path ~r/^responses\.[^.\s][^\s]*$/

  @impl true
  def fields, do: %{required: [:label, :outcome], optional: [:writes, :style, :validates]}

  @impl true
  def validate(node) do
    writes_findings(node) ++ style_findings(node) ++ validates_findings(node)
  end

  defp writes_findings(node) do
    case Map.fetch(node, :writes) do
      {:ok, writes} when is_map(writes) -> Enum.flat_map(writes, &write_findings(&1, node[:key]))
      {:ok, writes} -> [not_a_map(writes, node[:key])]
      :error -> []
    end
  end

  # Which style it is stays the renderer's, as the moduledoc says; that it is
  # a string is this package's, because a renderer handed a number has no name
  # to look up. Checked only where the button declares one: `style` is
  # optional and an absent field never reaches the admitted node.
  defp style_findings(node) do
    case Map.fetch(node, :style) do
      {:ok, style} when is_binary(style) ->
        []

      {:ok, style} ->
        [
          %Finding{
            code: "document.invalid_style",
            message:
              "a style is the name a renderer looks up, a string, not #{inspect(style)}; which names there are is the renderer's",
            field: "style",
            node_key: node[:key]
          }
        ]

      :error ->
        []
    end
  end

  # `validates` is the opt-out of validating the screen this button submits,
  # so a value that is not a boolean is a button whose submission rule nothing
  # can read. Checked only where the button declares one; an absent
  # `validates` is true, which the moduledoc states and the resolver applies.
  defp validates_findings(node) do
    case Map.fetch(node, :validates) do
      {:ok, validates} when is_boolean(validates) ->
        []

      {:ok, validates} ->
        [
          %Finding{
            code: "document.invalid_validates",
            message:
              "validates says whether pressing this button validates the screen first, true or false, not #{inspect(validates)}",
            field: "validates",
            node_key: node[:key]
          }
        ]

      :error ->
        []
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
