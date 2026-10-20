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

  @doc false
  @spec to_data(term()) :: term()
  def to_data(struct) when is_struct(struct), do: struct |> Map.from_struct() |> to_data()

  def to_data(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key(key), to_data(value)} end)

  def to_data(list) when is_list(list), do: Enum.map(list, &to_data/1)
  def to_data(value) when value in [nil, true, false], do: value
  def to_data(atom) when is_atom(atom), do: Atom.to_string(atom)
  def to_data(value), do: value

  defp key(key) when is_atom(key), do: Atom.to_string(key)
  defp key(key), do: key
end
