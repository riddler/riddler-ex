defmodule Riddler.Encoding do
  @moduledoc false

  # The one encoder: a term put into the data form JSON can carry. Structs
  # become maps, atom keys become strings, and atom values other than `true`,
  # `false` and `nil` become strings. Nothing else is touched - a string, a
  # number and a list come back as themselves.
  #
  # It is shared rather than copied because two callers need the same rules:
  # the corpus runner, which compares an answer against the JSON a case
  # states, and `Riddler.Journey`, whose answer is that data form itself. Two
  # copies would let the corpus hold a runtime to a form the package does not
  # answer in.
  #
  # Two atom keys keep the spelling the data form has carried so far. The
  # admitted and resolved structs name a screen's children `:elements` and a
  # finding's element `:element_key`, while the data form a client reads
  # still says `"nodes"` and `"node_key"`; the data form changes in its own
  # step, and these two clauses are what that step removes.

  @doc false
  @spec to_data(term()) :: term()
  def to_data(struct) when is_struct(struct), do: struct |> Map.from_struct() |> to_data()

  def to_data(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key(key), to_data(value)} end)

  def to_data(list) when is_list(list), do: Enum.map(list, &to_data/1)
  def to_data(value) when value in [nil, true, false], do: value
  def to_data(atom) when is_atom(atom), do: Atom.to_string(atom)
  def to_data(value), do: value

  defp key(:elements), do: "nodes"
  defp key(:element_key), do: "node_key"
  defp key(key) when is_atom(key), do: Atom.to_string(key)
  defp key(key), do: key
end
