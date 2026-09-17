defmodule Riddler.Screens.Document do
  @moduledoc """
  The screen document: what a host declares, and why one is refused.

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

  The envelope's `kind` names the content kind the document belongs to, and
  a document that omits it is a screen document: the admitted struct carries
  `"screens"` for it, so a document authored before kinds existed is
  admitted unchanged. A `kind` this package has no runtime for is carried as
  it was written and refused by `validate/1`.

  `admit/1` answers `nil` for an input that is not a screen document - not
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

    * `document.unknown_kind` - the envelope names a content kind this
      package has no runtime for. The finding carries the value and no node
      key, because the envelope is the document's and not any one node's.
    * `document.invalid_schema_version` - the envelope declares a
      `schema_version` other than the one this package implements. No node
      key, for the same reason.
    * `document.invalid_id` - the envelope's `id` is there and is not a
      string. No node key.
    * `document.unknown_type` - the registry has no such type.
    * `document.duplicate_key` - a key used twice anywhere in the document.
      Only the keys that are strings are compared. A key that is not a string
      is already `document.invalid_key`, and two nodes carrying the same
      non-string key are never reported as a duplicate: there is no key there
      to have been used twice, and saying there is would tell the author to
      rename one of them when what each of them needs is a key.
    * `document.invalid_key` - a key missing, a key that is there and is not
      a string, or a key not matching `[a-z][a-z0-9_]*`. One code, three
      messages, because all three are the same mistake from the document's
      side: the node has no name anything else can use. The first two carry
      no node key - `node_key` is how a host looks the node up, and neither
      an absent key nor a key of the wrong form is a name to look one up by -
      and the key the document did write is named in the message.
    * `document.invalid_title` - a screen's `title` is there and is not a
      string. The finding carries the screen's key.
    * `document.missing_field` - a field the node's type requires.
    * `document.level_out_of_range` - a heading level outside 1 to 6.
    * `document.invalid_condition` - a condition that does not parse.
    * `document.invalid_template` - a template field holding a construct
      outside the template subset. The finding carries the construct the
      template refused, and the node's key.
    * `document.invalid_writes` - a write that does not address a response,
      or whose value is not the constant form.
    * `document.invalid_style` - a button's `style` is there and is not a
      string. Which string it is stays the renderer's business; that it is a
      string is this package's.
    * `document.invalid_validates` - a button's `validates` is there and is
      not a boolean.
    * `document.invalid_required` - a question's `required` is there and is
      not a boolean.
    * `document.unknown_format` - a format name this package does not know.
    * `document.invalid_pattern` - a question that asks for the `pattern`
      format declares a `pattern` that format cannot compile. Nothing a
      visitor could type would satisfy it, so it is the document that is
      wrong and not a response. Only where the question declares that format:
      a `pattern` on a question asking for another format, or for none, is a
      field nothing consults and raises nothing.
    * `document.empty_variant` - a variant with no candidates.
    * `document.unreachable_variant_candidate` - an unconditional candidate
      that is not last, which buries every candidate after it.

  ## Examples

      iex> doc = Riddler.Screens.Document.admit(%{
      ...>   "schema_version" => 1,
      ...>   "id" => "edoc_signup",
      ...>   "screens" => [%{"key" => "account", "title" => "Create your account", "nodes" => [
      ...>     %{"type" => "heading", "key" => "account_heading", "level" => 1, "text" => "Create your account"}
      ...>   ]}]
      ...> })
      iex> {:ok, ^doc} = Riddler.Screens.Document.validate(doc)
      iex> hd(hd(doc.screens).nodes).key
      "account_heading"

      iex> Riddler.Screens.Document.admit("not a document")
      nil
  """

  alias Riddler.Finding
  alias Riddler.Screens.Registry
  alias Riddler.Template

  # The content kind this module is the runtime for, and the kind a document
  # that names none belongs to. A document authored before kinds existed is
  # a screen document, so the default is what keeps every one of them
  # admitted unchanged.
  @default_kind "screens"

  # The version of this contract this package implements. The envelope's
  # `schema_version` is an integer and it is this integer in this version, so
  # a document authored against a contract this package is not the runtime for
  # says so in one field rather than by failing somewhere inside.
  @schema_version 1

  # The kinds this version has a runtime for. It is the registry of kinds,
  # and it is the other half of the rule that makes `kind` an open string in
  # the schema: the schema does not enumerate the kinds, and this does, so a
  # kind no runtime knows is refused here rather than resolved by the wrong
  # kind's rules.
  @kinds [@default_kind]

  @typedoc "An admitted screen: its key, its title, and its nodes in order."
  @type screen :: %{key: term(), title: term(), nodes: [Riddler.Screens.Type.node_t()]}

  @typedoc "An admitted document."
  @type t :: %__MODULE__{
          schema_version: term(),
          kind: term(),
          id: term(),
          metadata: %{optional(String.t()) => term()},
          screens: [screen()]
        }

  defstruct schema_version: nil, kind: @default_kind, id: nil, metadata: %{}, screens: []

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
  a screen document. A document that is wrong rather than absent is
  admitted here and refused by `validate/1`.

      iex> Riddler.Screens.Document.admit(%{"screens" => []})
      %Riddler.Screens.Document{schema_version: nil, kind: "screens", id: nil, metadata: %{}, screens: []}

      iex> Riddler.Screens.Document.admit(%{"screens" => "three of them"})
      nil
  """
  @spec admit(term()) :: t() | nil
  def admit(raw) when is_map(raw) and not is_struct(raw) do
    with screens when is_list(screens) <- Map.get(raw, "screens"),
         {:ok, metadata} <- admit_metadata(Map.get(raw, "metadata")),
         {:ok, admitted} <- admit_each(screens, &admit_screen/1) do
      %__MODULE__{
        schema_version: Map.get(raw, "schema_version"),
        kind: admit_kind(Map.get(raw, "kind")),
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

      iex> doc = Riddler.Screens.Document.admit(%{"screens" => [
      ...>   %{"key" => "account", "title" => "Create your account", "nodes" => [
      ...>     %{"type" => "carousel", "key" => "pictures"}
      ...>   ]}
      ...> ]})
      iex> {:error, [finding]} = Riddler.Screens.Document.validate(doc)
      iex> {finding.code, finding.node_key}
      {"document.unknown_type", "pictures"}
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [Finding.t()]}
  def validate(%__MODULE__{} = document) do
    findings =
      kind_findings(document) ++
        envelope_findings(document) ++
        duplicate_findings(document) ++ Enum.flat_map(document.screens, &screen_findings/1)

    case findings do
      [] -> {:ok, document}
      findings -> {:error, findings}
    end
  end

  @doc false
  @spec formats() :: [String.t()]
  def formats, do: @formats

  # -- admit ----------------------------------------------------------------

  # An absent `kind` is the default rather than `nil`: the decided kind is
  # carried through to the resolved document, so a host holding one can tell
  # what it is holding without the document it came from. A kind that is
  # there and wrong is carried as it was written, because `validate/1` has to
  # name the value it refused.
  defp admit_kind(nil), do: @default_kind
  defp admit_kind(kind), do: kind

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

  # The envelope's kind comes first because it is about the whole document:
  # a document resolved by the wrong kind's rules is worse than a document
  # refused, so the kind is settled before anything inside it is read.
  defp kind_findings(%__MODULE__{kind: kind}) when kind in @kinds, do: []

  defp kind_findings(%__MODULE__{kind: kind}) do
    [
      %Finding{
        code: "document.unknown_kind",
        message:
          "#{inspect(kind)} is not a content kind this package has a runtime for; the kinds are #{Enum.join(@kinds, ", ")}",
        field: "kind",
        node_key: nil
      }
    ]
  end

  # The rest of the envelope, checked for the shapes the record states: the
  # `schema_version` this package is the runtime for, and an `id` that is a
  # string. Each is checked only where the document carries it. An absent
  # field is `nil` in the admitted struct and is not a finding here: the
  # schema requires `screens` and nothing else, so whether either field is
  # required is a question this check does not answer, and answering it would
  # refuse documents this version admits.
  defp envelope_findings(%__MODULE__{} = document) do
    schema_version_findings(document.schema_version) ++ id_findings(document.id)
  end

  defp schema_version_findings(nil), do: []
  defp schema_version_findings(@schema_version), do: []

  defp schema_version_findings(version) do
    [
      %Finding{
        code: "document.invalid_schema_version",
        message:
          "a document this package is the runtime for declares schema_version #{@schema_version}, not #{inspect(version)}",
        field: "schema_version",
        node_key: nil
      }
    ]
  end

  defp id_findings(nil), do: []
  defp id_findings(id) when is_binary(id), do: []

  defp id_findings(id) do
    [
      %Finding{
        code: "document.invalid_id",
        message: "a document's id is the string that names it, not #{inspect(id)}",
        field: "id",
        node_key: nil
      }
    ]
  end

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

  # Only the keys that are strings. A key of any other form is not a key this
  # document has, and `document.invalid_key` has already said so about each
  # one of them; counting them here would report the same absence a second
  # time under a code that means something else - that the author used one
  # name twice - and send them to rename a key rather than to write one.
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
      title_findings(screen) ++
      Enum.flat_map(screen.nodes, &node_findings/1)
  end

  # A screen's title is a string, checked only where the screen carries one:
  # `admit/1` writes `nil` for a screen that declares none, and the schema
  # requires only `nodes` of a screen, so an absent title is not this check's
  # to refuse. The finding names the screen by its key, because the screen is
  # what the author has to fix.
  defp title_findings(%{title: nil}), do: []
  defp title_findings(%{title: title}) when is_binary(title), do: []

  defp title_findings(screen) do
    [
      %Finding{
        code: "document.invalid_title",
        message:
          "a screen's title is the string a visitor is shown, not #{inspect(screen.title)}",
        field: "title",
        node_key: Finding.node_key(screen.key)
      }
    ]
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
            node_key: Finding.node_key(node[:key])
          }
        ]

      {:ok, module} ->
        key = Finding.node_key(node[:key])

        key_findings(node[:key], "the #{node.type} node") ++
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

  defp key_findings(nil, what) do
    [
      %Finding{
        code: "document.invalid_key",
        message: "#{what} carries no key, and a key is how everything else names a node",
        field: "key",
        node_key: nil
      }
    ]
  end

  # A key that is there and is not a string is a different mistake from an
  # absent one, and the author fixing it needs to be told which: they wrote a
  # key, and they wrote it in a form nothing can name a node by. The value is
  # named here and not put on `node_key`, for the reason the moduledoc gives.
  defp key_findings(key, what) do
    [
      %Finding{
        code: "document.invalid_key",
        message:
          "#{what} carries #{inspect(key)} as its key, and a key is the string that names a node",
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
