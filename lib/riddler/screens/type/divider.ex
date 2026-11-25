defmodule Riddler.Screens.Type.Divider do
  @moduledoc """
  A rule between the elements before it and the elements after it.

  A divider carries no field of its own: its `type`, its `key` and an optional
  `condition`, as every element does, and nothing else. A field it does not
  name is dropped at admit with no finding, as on every type. How the rule is
  drawn is the renderer's.

      iex> Riddler.Screens.Type.Divider.validate(%{type: "divider", key: "details_rule"})
      []
  """

  @behaviour Riddler.Screens.Type

  @impl true
  def fields, do: %{required: [], optional: []}

  @impl true
  def validate(_node), do: []
end
