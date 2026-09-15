defmodule Riddler.Screens.Type.Heading do
  @moduledoc """
  A section title: a level and the text of the heading.

  `level` is an integer from 1 to 6 - the range every document format that
  has headings agrees on, and the range a renderer can map onto whatever it
  builds. It is a number rather than a style name because what a heading
  means is its depth in the document; how big it looks is the renderer's.

      iex> node = %{type: "heading", key: "account_heading", level: 1, text: "Create your account"}
      iex> Riddler.Screens.Type.Heading.validate(node)
      []
  """

  @behaviour Riddler.Screens.Type

  alias Riddler.Finding

  @impl true
  def fields, do: %{required: [:level, :text], optional: []}

  @impl true
  def validate(node) do
    case Map.fetch(node, :level) do
      {:ok, level} when is_integer(level) and level >= 1 and level <= 6 ->
        []

      {:ok, level} ->
        [
          %Finding{
            code: "document.level_out_of_range",
            message: "a heading level is an integer from 1 to 6, not #{inspect(level)}",
            field: "level",
            node_key: node[:key]
          }
        ]

      :error ->
        []
    end
  end
end
