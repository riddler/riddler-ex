defmodule Riddler.Screens.Upgrade do
  @moduledoc false

  # A version 1 screen document rewritten as version 2: `schema_version`
  # becomes `2`, and the `nodes` of every screen and of every container
  # admission reads becomes `elements`, its list as written. Nothing else in
  # the document is read or changed. `Riddler.Screens.upgrade/1` is the public
  # entry over a decoded document; `rewrite_text/1` is the same rewrite over
  # the JSON text, for `mix riddler.upgrade`, editing the text in place so that
  # every byte of the file but the key and the version is left as written.
  #
  # Admission is the judge of what a version 1 document is, so a document is
  # admitted before it is rewritten, and what is rewritten is exactly what
  # admission reads: the children of a screen and the candidates of a
  # container, at every depth. A `nodes` on an element whose type reads no
  # children is a field admission drops, at either version, after holding it
  # to the same shape, and it is left as written.

  alias Riddler.Screens.Document
  alias Riddler.Screens.Registry

  @doc false
  @spec upgrade(term()) :: {:ok, map()} | {:error, Riddler.Screens.upgrade_error()}
  def upgrade(raw) do
    case Document.admit(raw) do
      nil -> {:error, :not_a_document}
      %Document{schema_version: version} -> by_version(raw, version)
    end
  end

  defp by_version(raw, 2), do: {:ok, raw}

  defp by_version(raw, version) when version in [nil, 1] do
    if Enum.any?(raw["screens"], &carries_elements?/1),
      do: {:error, :other_version_spelling},
      else: {:ok, rewrite(raw)}
  end

  defp by_version(_raw, _other), do: {:error, :unsupported_version}

  # Whether a screen or an element, or anything under its `nodes`, carries an
  # `elements` key. A version 1 document spells its children `nodes`, and an
  # `elements` key is the other version's spelling wherever it stands: on a
  # screen or a container the rename would collide with it, and on any other
  # element version 2 would hold it to a shape version 1 never asked of it.
  defp carries_elements?(map) when is_map(map) do
    Map.has_key?(map, "elements") or
      case Map.get(map, "nodes") do
        list when is_list(list) -> Enum.any?(list, &carries_elements?/1)
        _none -> false
      end
  end

  defp carries_elements?(_not_a_map), do: false

  defp rewrite(raw) do
    raw
    |> Map.put("schema_version", 2)
    |> Map.update!("screens", fn screens -> Enum.map(screens, &rename/1) end)
  end

  defp rename(%{"nodes" => children} = map) do
    map
    |> Map.delete("nodes")
    |> Map.put("elements", Enum.map(children, &rename_container/1))
  end

  defp rename_container(element) do
    if container?(element["type"]), do: rename(element), else: element
  end

  # A type whose fields name `elements` reads children; every other type, and
  # a type the registry does not know, reads none.
  defp container?(type) do
    case Registry.fetch(type) do
      {:ok, module} ->
        %{required: required, optional: optional} = module.fields()
        :elements in required or :elements in optional

      :error ->
        false
    end
  end

  # -- the same rewrite over the JSON text ------------------------------------

  @doc false
  @spec rewrite_text(String.t()) ::
          {:ok, String.t()} | {:error, Riddler.Screens.upgrade_error() | :not_json}
  def rewrite_text(text) when is_binary(text) do
    with {:ok, decoded} <- decode(text),
         {:ok, upgraded} <- upgrade(decoded) do
      if upgraded == decoded, do: {:ok, text}, else: {:ok, edit(text, upgraded)}
    end
  end

  defp decode(text) do
    case JSON.decode(text) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _reason} -> {:error, :not_json}
    end
  end

  # The text with the key and the version edited in place, and the proof that
  # it decodes to the upgraded document: the edit is the decoded rewrite, or
  # it is not written.
  defp edit(text, upgraded) do
    {root, _end} = value(text, 0)
    edited = apply_edits(text, version_edit(text, root) ++ screens_edits(root))
    ^upgraded = JSON.decode!(edited)
    edited
  end

  defp version_edit(text, {:object, start, _stop, entries} = root) do
    case entries_named(root, "schema_version") do
      [] ->
        {_key, key_start, key_stop, {_kind, value_start, _value_stop, _inner}} = hd(entries)
        indent = binary_part(text, start + 1, key_start - start - 1)
        separator = binary_part(text, key_stop, value_start - key_stop)
        [{start + 1, start + 1, indent <> ~s("schema_version") <> separator <> "2,"}]

      versions ->
        for {_key, _key_start, _key_stop, {_kind, from, to, _inner}} <- versions,
            do: {from, to, "2"}
    end
  end

  defp screens_edits(root) do
    {_key, _start, _stop, {:array, _from, _to, screens}} =
      List.last(entries_named(root, "screens"))

    Enum.flat_map(screens, &children_edits(&1, true))
  end

  defp children_edits({:object, _start, _stop, _entries} = object, true) do
    for {_key, key_start, key_stop, children} <- entries_named(object, "nodes"),
        edit <- [{key_start, key_stop, ~s("elements")} | elements_edits(children)],
        do: edit
  end

  defp children_edits(_value, _read?), do: []

  defp elements_edits({:array, _start, _stop, elements}) do
    Enum.flat_map(elements, fn element -> children_edits(element, container?(type(element))) end)
  end

  defp elements_edits(_not_read), do: []

  defp type(object) do
    case List.last(entries_named(object, "type")) do
      {_key, _start, _stop, {:string, _from, _to, type}} -> type
      _none -> nil
    end
  end

  defp entries_named({:object, _start, _stop, entries}, name),
    do: Enum.filter(entries, fn {key, _start, _stop, _value} -> key == name end)

  # Edits are disjoint spans of the text, applied from the last to the first
  # so that each one's offsets still hold when it is applied.
  defp apply_edits(text, edits) do
    edits
    |> Enum.sort_by(fn {from, _to, _replacement} -> from end, :desc)
    |> Enum.reduce(text, fn {from, to, replacement}, acc ->
      binary_part(acc, 0, from) <> replacement <> binary_part(acc, to, byte_size(acc) - to)
    end)
  end

  # -- where each value sits in the text ---------------------------------------

  # The text has already decoded as JSON, so this reads it as valid JSON and
  # records, for each value, the byte span it occupies: an object as its
  # entries, each with its decoded key and the key's span, an array as its
  # values, and a string as its decoded value. A structural character is
  # ASCII, and no byte of a multi-byte UTF-8 character is one, so the spans
  # are byte offsets.
  defp value(text, pos) do
    pos = skip_space(text, pos)

    case :binary.at(text, pos) do
      ?{ -> object(text, pos + 1, pos, [])
      ?[ -> array(text, pos + 1, pos, [])
      ?" -> string(text, pos)
      _scalar -> scalar(text, pos, pos)
    end
  end

  defp object(text, pos, start, entries) do
    pos = skip_space(text, pos)

    case :binary.at(text, pos) do
      ?} ->
        {{:object, start, pos + 1, Enum.reverse(entries)}, pos + 1}

      ?, ->
        object(text, pos + 1, start, entries)

      ?" ->
        {{:string, key_start, key_stop, key}, after_key} = string(text, pos)
        colon = skip_space(text, after_key)
        {value, after_value} = value(text, colon + 1)
        object(text, after_value, start, [{key, key_start, key_stop, value} | entries])
    end
  end

  defp array(text, pos, start, values) do
    pos = skip_space(text, pos)

    case :binary.at(text, pos) do
      ?] ->
        {{:array, start, pos + 1, Enum.reverse(values)}, pos + 1}

      ?, ->
        array(text, pos + 1, start, values)

      _value ->
        {value, after_value} = value(text, pos)
        array(text, after_value, start, [value | values])
    end
  end

  defp string(text, start) do
    stop = string_end(text, start + 1)
    {{:string, start, stop, JSON.decode!(binary_part(text, start, stop - start))}, stop}
  end

  defp string_end(text, pos) do
    case :binary.at(text, pos) do
      ?" -> pos + 1
      ?\\ -> string_end(text, pos + 2)
      _byte -> string_end(text, pos + 1)
    end
  end

  defp scalar(text, pos, start) do
    if pos < byte_size(text) and :binary.at(text, pos) not in ~c" \t\r\n,]}",
      do: scalar(text, pos + 1, start),
      else: {{:scalar, start, pos, nil}, pos}
  end

  defp skip_space(text, pos) do
    if pos < byte_size(text) and :binary.at(text, pos) in ~c" \t\r\n",
      do: skip_space(text, pos + 1),
      else: pos
  end
end
