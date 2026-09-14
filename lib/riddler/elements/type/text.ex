defmodule Riddler.Elements.Type.Text do
  @moduledoc """
  A block of authored prose.

  `text` is a template in the subset `Riddler.Template` admits, so a block of
  copy can read back what the visitor just told us. Nothing else about it is
  this type's to check: the template is compiled by the document, for every
  template field of every type, by the same code an editor calls.

      iex> Riddler.Elements.Type.Text.validate(%{type: "text", key: "plan_intro", text: "Nothing is charged today."})
      []
  """

  @behaviour Riddler.Elements.Type

  @impl true
  def fields, do: %{required: [:text], optional: []}

  @impl true
  def validate(_node), do: []
end
