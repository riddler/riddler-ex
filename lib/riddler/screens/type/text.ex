defmodule Riddler.Screens.Type.Text do
  @moduledoc """
  A block of authored prose.

  `text` is a template in the subset `Riddler.Template` admits, so a block of
  copy can read back what the visitor just told us. The template is compiled
  by the document, for every template field of every type, by the same code an
  editor calls.

  `style` is a hint a renderer owns - `body` and `caption` are the names
  offered, and a text with no `style` is `body` - and one this package does
  not offer is passed through; one that is not a string is
  `document.invalid_style`. A text that carries no `style` resolves with none.

      iex> Riddler.Screens.Type.Text.validate(%{type: "text", key: "plan_intro", text: "Nothing is charged today."})
      []

      iex> node = %{type: "text", key: "card_note", text: "Bring a proof of address.", style: 2}
      iex> [finding] = Riddler.Screens.Type.Text.validate(node)
      iex> {finding.code, finding.field}
      {"document.invalid_style", "style"}
  """

  @behaviour Riddler.Screens.Type

  alias Riddler.Finding

  @impl true
  def fields, do: %{required: [:text], optional: [:style]}

  @impl true
  def validate(node) do
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
            element_key: Finding.element_key(node[:key])
          }
        ]

      :error ->
        []
    end
  end
end
