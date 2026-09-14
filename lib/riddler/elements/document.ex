defmodule Riddler.Elements.Document do
  @moduledoc """
  The element document: what a host declares, and why one is refused.

  A document is the contract between a host that authors content and any
  runtime that shows it. This module is the two halves of admitting one.
  `admit/1` turns decoded JSON into the struct the rest of the package
  reads, or says the input is not a document at all. `validate/1` takes that
  struct and returns every reason the document is wrong, all of them, so an
  author fixing what they wrote learns everything in one pass.

  Neither raises on anything a host can produce, and neither consults a
  context: a document is wrong or right on its own, before a visitor exists,
  which is what lets an editor answer the author while the author is still
  looking at it.

  ## What `admit/1` takes and what it builds

  It takes the decoded JSON map - string keys throughout, as
  `Jason.decode!/1` gives - and builds a struct whose fields are atoms. The
  two are different things: what the host writes is JSON, and what this
  package reads is the struct. A screen is `%{key: ..., title: ...,
  nodes: [...]}` and a node is an atom-keyed map carrying `:type`, its `:key`
  and `:condition` where the document declared them, and the fields its type
  names. `metadata` is the one map that keeps its string keys: it is an open
  map by declaration, and a host may put what it likes beside `name`,
  `description` and `domain`.

  `admit/1` answers `nil` for an input that is not an element document - not
  a map, or a map whose spine is not a document's: no list of screens, a
  screen that is not an object, a screen with no list of nodes, a node that
  is not an object, a variant whose candidates are not a list. That is the
  whole of what it refuses. Everything else - a missing field, a key of the
  wrong shape, a level of 9, a condition that does not parse - is a document
  that exists and is wrong, and saying which is `validate/1`'s job.

  A field this version does not know is not carried onto the admitted node.
  `metadata` is the declared place for what a host wants to keep beside the
  vocabulary, and the admitted node map is atom-keyed by declaration, so
  there is nowhere on a node for an unrecognized key to live. Whether such a
  key should also be a finding is not decided by the record this module
  implements, and this version does not raise one.

  ## The findings `validate/1` raises

  One code per check, stable, and a host switches on the code rather than on
  the wording:

    * `document.unknown_type` - the registry has no such type.
    * `document.duplicate_key` - a key used twice anywhere in the document.
    * `document.invalid_key` - a key missing, or not matching
      `[a-z][a-z0-9_]*`.
    * `document.missing_field` - a field the node's type requires.
    * `document.level_out_of_range` - a heading level outside 1 to 6.
    * `document.invalid_condition` - a condition that does not parse.
    * `document.invalid_template` - a template field holding a construct
      outside the template subset. The finding carries the construct the
      template refused, and the node's key.
    * `document.invalid_writes` - a write that does not address a response,
      or whose value is not the constant form.
    * `document.unknown_format` - a format name this package does not know.
    * `document.empty_variant` - a variant with no candidates.
    * `document.unreachable_variant_candidate` - an unconditional candidate
      that is not last, which buries every candidate after it.

  ## Examples

      iex> doc = Riddler.Elements.Document.admit(%{
      ...>   "schema_version" => 1,
      ...>   "id" => "edoc_signup",
      ...>   "screens" => [%{"key" => "account", "title" => "Create your account", "nodes" => [
      ...>     %{"type" => "heading", "key" => "account_heading", "level" => 1, "text" => "Create your account"}
      ...>   ]}]
      ...> })
      iex> {:ok, ^doc} = Riddler.Elements.Document.validate(doc)
      iex> hd(hd(doc.screens).nodes).key
      "account_heading"

      iex> Riddler.Elements.Document.admit("not a document")
      nil
  """

  alias Riddler.Elements.Registry
  alias Riddler.Finding
  alias Riddler.Template

  @typedoc "An admitted screen: its key, its title, and its nodes in order."
  @type screen :: %{key: term(), title: term(), nodes: [Riddler.Elements.Type.node_t()]}

  @typedoc "An admitted document."
  @type t :: %__MODULE__{
          schema_version: term(),
          id: term(),
          metadata: %{optional(String.t()) => term()},
          screens: [screen()]
        }

  defstruct schema_version: nil, id: nil, metadata: %{}, screens: []

  # The fields every node carries whatever its type is. The rest come from
  # the type's own `fields/0`.
  @common_fields [:type, :key, :condition]

  # The string fields a document writes as templates. Every other string in a
  # document is literal text.
  @template_fields [:text, :label, :placeholder]

  # The validation formats this package will recognize when a response
  # arrives. A document naming one of these is admitted; the checks
  # themselves belong to response validation.
  @formats ["email", "phone", "pattern", "integer", "number"]

  @key_shape ~r/^[a-z][a-z0-9_]*$/

  @doc """
  Turns a decoded JSON document into the struct, or answers `nil`.

  Total: it never raises, whatever it is handed. `nil` means the input is not
  an element document. A document that is wrong rather than absent is
  admitted here and refused by `validate/1`.

      iex> Riddler.Elements.Document.admit(%{"screens" => []})
      %Riddler.Elements.Document{schema_version: nil, id: nil, metadata: %{}, screens: []}

      iex> Riddler.Elements.Document.admit(%{"screens" => "three of them"})
      nil
  """
  @spec admit(term()) :: t() | nil
  def admit(raw) when is_map(raw) and not is_struct(raw) do
    with screens when is_list(screens) <- Map.get(raw, "screens"),
         {:ok, metadata} <- admit_metadata(Map.get(raw, "metadata")),
         {:ok, admitted} <- admit_each(screens, &admit_screen/1) do
      %__MODULE__{
        schema_version: Map.get(raw, "schema_version"),
        id: Map.get(raw, "id"),
        metadata: metadata,
        screens: admitted
      }
    else
      _not_a_document -> nil
    end
  end

  def admit(_raw), do: nil

  @doc """
  Returns `{:ok, document}` or every finding against it.

  The checks are the document's own - keys, conditions, templates,
  duplicates, and the fields each type requires - together with the checks
  each type raises about itself. Findings come back in document order, node
  by node, with the duplicate keys first because they are about the document
  rather than about any one node.

      iex> doc = Riddler.Elements.Document.admit(%{"screens" => [
      ...>   %{"key" => "account", "title" => "Create your account", "nodes" => [
      ...>     %{"type" => "carousel", "key" => "pictures"}
      ...>   ]}
      ...> ]})
      iex> {:error, [finding]} = Riddler.Elements.Document.validate(doc)
      iex> {finding.code, finding.node_key}
      {"document.unknown_type", "pictures"}
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [Finding.t()]}
  def validate(%__MODULE__{} = document) do
    case duplicate_findings(document) ++ Enum.flat_map(document.screens, &screen_findings/1) do
      [] -> {:ok, document}
      findings -> {:error, findings}
    end
  end

  @doc false
  @spec formats() :: [String.t()]
  def formats, do: @formats

  # -- admit ----------------------------------------------------------------

  defp admit_metadata(nil), do: {:ok, %{}}
  defp admit_metadata(map) when is_map(map) and not is_struct(map), do: {:ok, map}
  defp admit_metadata(_other), do: :error

  defp admit_each(list, fun) do
    Enum.reduce_while(list, {:ok, []}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, admitted} -> {:cont, {:ok, [admitted | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      :error -> :error
    end
  end

  defp admit_screen(raw) when is_map(raw) and not is_struct(raw) do
    with nodes when is_list(nodes) <- Map.get(raw, "nodes"),
         {:ok, admitted} <- admit_each(nodes, &admit_node/1) do
      {:ok, %{key: Map.get(raw, "key"), title: Map.get(raw, "title"), nodes: admitted}}
    else
      _not_a_screen -> :error
    end
  end

  defp admit_screen(_raw), do: :error

  defp admit_node(raw) when is_map(raw) and not is_struct(raw) do
    common = Map.put_new(take(raw, @common_fields), :type, nil)

    case Registry.fetch(common.type) do
      {:ok, module} -> admit_typed(raw, common, module)
      :error -> {:ok, common}
    end
  end

  defp admit_node(_raw), do: :error

  defp admit_typed(raw, common, module) do
    %{required: required, optional: optional} = module.fields()
    typed = Map.merge(common, take(raw, required ++ optional))

    case Map.fetch(typed, :nodes) do
      {:ok, candidates} when is_list(candidates) ->
        with {:ok, admitted} <- admit_each(candidates, &admit_node/1) do
          {:ok, Map.put(typed, :nodes, admitted)}
        end

      {:ok, _not_a_list} ->
        :error

      :error ->
        {:ok, typed}
    end
  end

  defp take(raw, fields) do
    for field <- fields,
        spelling = Atom.to_string(field),
        Map.has_key?(raw, spelling),
        into: %{} do
      {field, Map.fetch!(raw, spelling)}
    end
  end

  # -- validate -------------------------------------------------------------

  defp duplicate_findings(document) do
    document
    |> every_key()
    |> Enum.frequencies()
    |> Enum.filter(fn {_key, count} -> count > 1 end)
    |> Enum.sort()
    |> Enum.map(fn {key, count} ->
      %Finding{
        code: "document.duplicate_key",
        message:
          "the key #{inspect(key)} is used #{count} times; every key in a document is unique across the whole document",
        field: "key",
        node_key: key
      }
    end)
  end

  defp every_key(document) do
    document.screens
    |> Enum.flat_map(fn screen ->
      [screen.key | Enum.flat_map(screen.nodes, &node_keys/1)]
    end)
    |> Enum.filter(&is_binary/1)
  end

  defp node_keys(node) do
    [node[:key] | Enum.flat_map(candidates(node), &node_keys/1)]
  end

  defp candidates(node) do
    case node[:nodes] do
      candidates when is_list(candidates) -> candidates
      _none -> []
    end
  end

  defp screen_findings(screen) do
    key_findings(screen.key, "the screen #{inspect(screen.title)}") ++
      Enum.flat_map(screen.nodes, &node_findings/1)
  end

  defp node_findings(node) do
    case Registry.fetch(node.type) do
      :error ->
        [
          %Finding{
            code: "document.unknown_type",
            message:
              "#{inspect(node.type)} is not a node type this package knows; the types are #{Enum.join(Registry.types(), ", ")}",
            field: "type",
            node_key: node[:key]
          }
        ]

      {:ok, module} ->
        key = node[:key]

        key_findings(key, "the #{node.type} node") ++
          condition_findings(node, key) ++
          missing_findings(node, module, key) ++
          template_findings(node, key) ++
          module.validate(node) ++
          Enum.flat_map(candidates(node), &node_findings/1)
    end
  end

  defp key_findings(key, _what) when is_binary(key) do
    if Regex.match?(@key_shape, key) do
      []
    else
      [
        %Finding{
          code: "document.invalid_key",
          message:
            "the key #{inspect(key)} starts with a lower-case letter and carries only lower-case letters, digits and underscores after it",
          field: "key",
          node_key: key
        }
      ]
    end
  end

  defp key_findings(_key, what) do
    [
      %Finding{
        code: "document.invalid_key",
        message: "#{what} carries no key, and a key is how everything else names a node",
        field: "key",
        node_key: nil
      }
    ]
  end

  defp condition_findings(node, key) do
    case Map.fetch(node, :condition) do
      {:ok, condition} when is_binary(condition) -> compile_condition(condition, key)
      {:ok, condition} -> [invalid_condition(inspect(condition) <> " is not a condition", key)]
      :error -> []
    end
  end

  defp compile_condition(condition, key) do
    case Predicator.compile(condition) do
      {:ok, _instructions} -> []
      {:error, error} -> [invalid_condition(describe(error), key)]
    end
  end

  defp describe(%{message: message, position: {line, column}}),
    do: "#{message} (line #{line}, column #{column})"

  defp describe(%{message: message}), do: message
  defp describe(error), do: inspect(error)

  defp invalid_condition(detail, key) do
    %Finding{
      code: "document.invalid_condition",
      message: "the condition does not parse: #{detail}",
      field: "condition",
      node_key: key
    }
  end

  defp missing_findings(node, module, key) do
    %{required: required} = module.fields()

    for field <- required, not Map.has_key?(node, field) do
      %Finding{
        code: "document.missing_field",
        message: "a #{node.type} node carries #{field}, and this one does not",
        field: Atom.to_string(field),
        node_key: key
      }
    end
  end

  defp template_findings(node, key) do
    for field <- @template_fields,
        {:ok, source} <- [Map.fetch(node, field)],
        finding <- refusals(source, field, key) do
      finding
    end
  end

  defp refusals(source, field, key) when is_binary(source) do
    case Template.compile(source) do
      {:ok, _compiled} ->
        []

      {:error, findings} ->
        Enum.map(findings, fn finding ->
          %Finding{
            code: "document.invalid_template",
            message: "the #{field} template is refused: #{finding.message}",
            field: finding.field,
            node_key: key
          }
        end)
    end
  end

  defp refusals(source, field, key) do
    [
      %Finding{
        code: "document.invalid_template",
        message: "the #{field} template is refused: #{inspect(source)} is not template source",
        field: Atom.to_string(field),
        node_key: key
      }
    ]
  end
end
