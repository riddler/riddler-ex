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
  elements: [...]}` and an element is an atom-keyed map carrying `:type`, its `:key`
  and `:condition` where the document declared them, its
  `:accessible_label` and `:accessible_description` where the document wrote
  them, on any type, its `:checks` where the document wrote them, each check
  that is an object carried atom-keyed with its `:condition`, `:code` and
  `:message` and nothing else, and the fields its type names. `metadata` is the one
  map that keeps its string keys: it is an open map by declaration, and a
  host may put what it likes beside `name`, `description` and `domain`.

  The envelope's `kind` names the content kind the document belongs to, and
  a document that omits it is a screen document: the admitted struct carries
  `"screens"` for it, so a document authored before kinds existed is
  admitted unchanged. A `kind` this package has no runtime for is carried as
  it was written and refused by `validate/1`.

  The envelope's `schema_version` says which key a screen and a variant
  spell their children under: `nodes` at version 1, which is the version of a
  document that declares none, and `elements` at version 2. Either way the
  admitted struct carries them as `elements`. The other version's key is held
  to the shape the schema gives it and is then carried nowhere; `validate/1`
  refuses the screen or the variant that carried it. That shape is a list of
  elements, except an `elements` in a version 1 document, on a screen or an
  element, which is any value, as it was before version 2 existed. A document
  at a version this package does not implement is read as riddler 0.7.0 read
  it, from `nodes`, unless none of its screens carries that key; then it is
  read from `elements` as a version 2 document is, refusing no key.

  `admit/1` answers `nil` for an input that is not a screen document - not
  a map, or a map whose spine is not a document's: no list of screens, a
  `metadata` that is there and is not an object, `null` included, a screen
  that is not an object, a screen with no list of elements, an element that is not
  an object, a variant whose candidates are not a list. It answers
  `nil` too for a value of the wrong JSON type in a field the document schema
  types: an `id`, a `kind`, a screen's `key` or `title`, or an element's `key`,
  `type` or `condition` that is there and is not a string, `null` included; a
  `schema_version` that is there and is not an integer, a number with no
  fractional part counting as one and admitted as its integer; a `nodes` on a
  element whose type reads none that is not a list of elements; and an
  `answer_options` on a choice question that is not a list of objects, or an
  option whose `value` or `label` is there and is not a string. A list of elements
  there is admitted and dropped, as any field the type does not name is. That
  is the whole of what it refuses, and the document schema refuses each of
  them too, so a value the schema calls a document is admitted. Everything
  else - a missing field, a key of the wrong shape, a level of 9, a condition
  that does not parse - is a document that exists and is wrong, and saying
  which is `validate/1`'s job.

  A field this version does not know is not carried onto the admitted element.
  `metadata` is the declared place for what a host wants to keep beside the
  vocabulary, and the admitted element map is atom-keyed by declaration, so
  there is nowhere on an element for an unrecognized key to live. Whether such a
  key should also be a finding is not decided by the record this module
  implements, and this version does not raise one.

  ## The findings `validate/1` raises

  One code per check, stable, and a host switches on the code rather than on
  the wording:

    * `document.unknown_kind` - the envelope names a content kind this
      package has no runtime for. The finding carries the value and no element
      key, because the envelope is the document's and not any one element's.
    * `document.invalid_schema_version` - the envelope declares a
      `schema_version` other than the two this package implements, 1 and 2.
      No element key, for the same reason.
    * `document.other_version_spelling` - a screen or a variant carries the
      other version's key for its children: `elements` in a version 1
      document, or one declaring no version, and `nodes` in a version 2
      document. One finding, whether or not it carries its own version's key
      beside it, its `field` the key refused and its `element_key` the
      screen's or the variant's. Nothing under that key is admitted, so a
      variant refused for it is not also missing its candidates.
    * `document.unknown_type` - the registry has no such type.
    * `document.duplicate_key` - a key used twice anywhere in the document.
      Only the keys that are strings are compared. A key that is not a string
      is already `document.invalid_key`, and two elements carrying the same
      non-string key are never reported as a duplicate: there is no key there
      to have been used twice, and saying there is would tell the author to
      rename one of them when what each of them needs is a key.
    * `document.invalid_key` - a key missing, a key that is there and is not
      a string, or a key not matching `[a-z][a-z0-9_]*`. One code, three
      messages, because all three are the same mistake from the document's
      side: the element has no name anything else can use. The first two carry
      no element key - `element_key` is how a host looks the element up, and neither
      an absent key nor a key of the wrong form is a name to look one up by -
      and the key the document did write is named in the message.
    * `document.missing_field` - a field the element's type requires.
    * `document.level_out_of_range` - a heading level outside 1 to 6.
    * `document.invalid_condition` - a condition that does not parse, an
      element's or a check's; a check's carries the `field` `"checks"` and a
      message naming the check by its place and its code.
    * `document.invalid_check` - a `checks` on an element that is not a
      question, or one that is not a list; and, per entry, an entry that is
      not an object, one with no `condition`, `code` or `message`, a `code`
      that is not a string of two or more dotted segments beginning `check`
      (an author's code, which this package never raises), a `message` that
      is not a non-empty string, and a `code` an earlier check on the same
      question carries. Its `field` is `"checks"`, and its message names the
      entry by its place, counting from one, and by its code where it carries
      one.
    * `document.invalid_template` - a template field holding a construct
      outside the template subset, a choice question option's `label` and
      `description`, an image's `alt`, and the `accessible_label` and
      `accessible_description` any element may carry among them. An option's
      `description`, an `alt` or an accessible field that is not a string is
      this finding too. The finding carries the construct the template
      refused, and the element's key.
    * `document.invalid_writes` - a write that does not address a response,
      or whose value is not the constant form.
    * `document.invalid_url` - an image's `src` or a link's `href`, written
      as a literal, is not a URL the rule admits: an `https://` URL naming a
      host, a host-relative URL, or, for an image's `src` alone, a base64
      `data:` image of one of four raster types within its bound, as
      `Riddler.Screens.Type.Image` and `Riddler.Screens.Type.Link` state. Its
      `field` is `"src"` or `"href"`, and its message says which part of the
      rule the value fails and never quotes the value.
    * `document.invalid_hint` - an image's `size` or `fit` is there and is not
      a string, or a choice question's `searchable` is there and is not a
      boolean.
    * `document.invalid_style` - a `style` is there and is not a string, on an
      element whose type names one: a text, a link, a button, a text
      question or a choice question. Which string it is stays the renderer's
      business; that it is a string is this package's.
    * `document.invalid_validates` - a button's `validates` is there and is
      not a boolean.
    * `document.invalid_outcome` - a button's `outcome` is there and is not
      a string, `nil` included. One finding per such button, its `field`
      `"outcome"`, raised with the button's other field findings. A button
      with no `outcome` is `document.missing_field`, and is not this finding
      too.
    * `document.invalid_required` - a question's `required` is there and is
      not a boolean.
    * `document.invalid_select` - a choice question's `select` is there and
      is neither `"one"` nor `"many"`.
    * `document.empty_answer_options` - a choice question's `answer_options`
      is an empty list.
    * `document.invalid_option` - a choice question's option carries no
      `value`, a `value` not matching `[a-z][a-z0-9_]*`, or no `label`.
    * `document.duplicate_option_value` - two options of one choice question
      carry the same `value`. Option values are not keys, so two questions
      may offer the same one.
    * `document.invalid_selection_bounds` - a choice question's
      `min_selections` or `max_selections` on a question whose `select` is
      not `"many"`, one that is not a non-negative integer, a
      `min_selections` above `max_selections`, or either above the number of
      options. A bound with no fractional part counts as its integer.
    * `document.unknown_format` - a format name this package does not know.
    * `document.invalid_bound` - a text question's `min` or `max` is there
      and is not in the shape of the format that reads it: a number for the
      `integer` and `number` formats, and a string in the format's own shape
      for `date`, `time` and `datetime`, where a `min` after its `max` is
      refused too, its `field` `"max"`. A bound under any other format, or
      none, is a field nothing consults and raises nothing, and a numeric
      `min` above its `max` is admitted.
    * `document.invalid_step` - a text question's `step` is there and is not
      a number, whatever the format, or none; or is there under the `integer`
      or `number` format and is not a number above zero, or, under `integer`,
      is a number with a fractional part. A number step under any other
      format, or none, is a field nothing consults and raises nothing.
    * `document.invalid_pattern` - a question that asks for the `pattern`
      format declares a `pattern` that format cannot compile. Nothing a
      visitor could type would satisfy it, so it is the document that is
      wrong and not a response. Only where the question declares that format:
      a `pattern` on a question asking for another format, or for none, is a
      field nothing consults and raises nothing.
    * `document.invalid_default` - a text, choice or boolean question's
      `default` is not of the question's response shape: a string for a text
      question, `true` or `false` for a boolean question, and for a choice
      question one of its own options' values under `select: "one"` or a list
      of different ones under `"many"`. A choice question whose `select` is
      neither has no shape to read, and its default is not checked. A choice
      question that reads its options from context has no option of its own
      for a default to name, and any default on it is refused.
    * `document.invalid_context_path` - a `prefill`, a choice question's
      `answer_options_from`, or an image's `src` or a link's `href`
      beginning `context.`, that is not a string of dotted segments starting
      at `context`, with at least one more after it, each in the key shape
      `[a-z][a-z0-9_]*`; its `field` names which.
    * `document.conflicting_options` - a choice question carries both
      `answer_options` and `answer_options_from`, its `field`
      `"answer_options_from"`. A choice question carrying neither is
      `document.missing_field` on `answer_options`.
    * `document.invalid_messages` - a question's `messages` is there and is
      not an object, or a value in it is not a string. One finding per such
      value, its `field` `"messages"`.
    * `document.unknown_message_code` - a key of a question's `messages` is
      not a code its type raises on a response, the message naming the key.
      A text question may key `response.required`, `response.format` and
      `response.out_of_range`; a choice question `response.required`,
      `response.invalid_shape`, `response.not_an_option` and
      `response.out_of_range`; a boolean or a secret question
      `response.required` and `response.invalid_shape`. Which codes a type
      raises is per type, not per question.
    * `document.secret_initial_value` - a secret question carries a
      `default` or a `prefill`, its `field` naming which. A secret is a value
      only the visitor supplies, and the finding never repeats what the field
      holds.
    * `document.secret_reference` - a template, a condition, a check's
      condition or a button's `writes` entry, anywhere in the document, names a secret question's
      response, `responses.<key>`, or a path under it. Its `element_key` is the
      element carrying the reference and its `field` the field that carries it;
      the message names the secret question's key, which is not a secret.
    * `document.duplicate_outcome` - two buttons that a screen can show
      together raise the same `outcome`, so a client handed that screen could
      not tell which of them the visitor pressed. Two buttons can be shown
      together unless they are candidates in different arms of one variant,
      which resolves to one winner; a condition on a button does not keep it
      from being compared, because which of two conditions holds is the
      root's and not the document's. One finding for each button that
      repeats an outcome a button before it on the screen raises, its `field`
      `"outcome"` and its `element_key` the repeating button's key; the message
      names the earlier button. Only outcomes that are strings are compared,
      so a button raising `document.invalid_outcome` is not compared, and
      the findings come after every other finding on the screen.
    * `document.empty_variant` - a variant with no candidates.
    * `document.unreachable_variant_candidate` - an unconditional candidate
      that is not last, which buries every candidate after it.

  ## Examples

      iex> doc = Riddler.Screens.Document.admit(%{
      ...>   "schema_version" => 2,
      ...>   "id" => "edoc_signup",
      ...>   "screens" => [%{"key" => "account", "title" => "Create your account", "elements" => [
      ...>     %{"type" => "heading", "key" => "account_heading", "level" => 1, "text" => "Create your account"}
      ...>   ]}]
      ...> })
      iex> {:ok, ^doc} = Riddler.Screens.Document.validate(doc)
      iex> hd(hd(doc.screens).elements).key
      "account_heading"

      iex> Riddler.Screens.Document.admit("not a document")
      nil
  """

  alias Riddler.Finding
  alias Riddler.Screens.Checks
  alias Riddler.Screens.Compilers
  alias Riddler.Screens.Registry
  alias Riddler.Template

  # The content kind this module is the runtime for, and the kind a document
  # that names none belongs to. A document authored before kinds existed is
  # a screen document, so the default is what keeps every one of them
  # admitted unchanged.
  @default_kind "screens"

  # The versions of this contract this package implements, each with the key
  # its document spells a screen's and a variant's children under and the
  # other version's key, which it refuses. The envelope's `schema_version` is
  # an integer, so a document authored against a contract this package is not
  # the runtime for says so in one field rather than by failing somewhere
  # inside. `admit/1` reads a version written with no fractional part as its
  # integer, so `1.0` is version 1, and a document that declares no version is
  # version 1.
  @spellings %{
    1 => %{own: "nodes", other: "elements", refuses: true, typed: false},
    2 => %{own: "elements", other: "nodes", refuses: true, typed: true}
  }
  @schema_versions Map.keys(@spellings)

  # What an admitted screen or variant carries when its document wrote the
  # other version's key beside or instead of its own: that key, and nothing of
  # what was under it. `validate/1` reads it, and a valid document never
  # carries it.
  @other_spelling :other_version_spelling

  # The kinds this version has a runtime for. It is the registry of kinds,
  # and it is the other half of the rule that makes `kind` an open string in
  # the schema: the schema does not enumerate the kinds, and this does, so a
  # kind no runtime knows is refused here rather than resolved by the wrong
  # kind's rules.
  @kinds [@default_kind]

  @typedoc """
  An admitted screen: its key, its title, and its elements in order, whichever
  version the document was written in. A screen that carried the other
  version's key carries that key as `:other_version_spelling`, which is what
  `validate/1` refuses it by. The key is an internal mark, not part of what a
  host reads: a valid document never carries it, and resolution drops it.
  """
  @type screen :: %{
          required(:key) => String.t() | nil,
          required(:title) => String.t() | nil,
          required(:elements) => [Riddler.Screens.Type.element()],
          optional(:other_version_spelling) => String.t()
        }

  @typedoc "An admitted document."
  @type t :: %__MODULE__{
          schema_version: integer() | nil,
          kind: String.t(),
          id: String.t() | nil,
          metadata: %{optional(String.t()) => term()},
          screens: [screen()]
        }

  defstruct schema_version: nil, kind: @default_kind, id: nil, metadata: %{}, screens: []

  # The fields every element carries whatever its type is. The rest come from
  # the type's own `fields/0`. The accessible label and description are here
  # rather than in any type's list because every type may carry them; both are
  # templates, so they are on the template list below too.
  #
  # `checks` is here too: only a question takes it, and on any other element it
  # is refused rather than dropped, so admission carries it wherever it was
  # written for `validate/1` to say which.
  @accessible_fields [:accessible_label, :accessible_description]
  @common_fields [:type, :key, :condition, :checks | @accessible_fields]

  # The string fields a document writes as templates. Every other string in a
  # document is literal text. This is the one declaration of the list: the
  # admit-time refusal below and `Riddler.Screens`' resolve-time render are two
  # passes over the same fields, and both read it through `template_fields/0`.
  @template_fields [:text, :label, :placeholder, :help, :alt | @accessible_fields]

  # The element type whose response no template, condition or write may read.
  @secret_type "secret_question"

  # A choice question's options. An option's `label` and `description` are
  # templates too, but they are not fields of the element, so they are not on
  # the list above: the refusal below and the render in `Riddler.Screens` each
  # read them beside that list, through `option_template_fields/0`. An option's
  # `value` is literal text. The schema types `value` and `label`, so admission
  # refuses either of another JSON type; a `description` is typed nowhere, and
  # one that is not a string is the template finding, as an element's `alt` is.
  @choice_type "choice_question"
  @option_template_fields [:label, :description]
  @option_fields [:value | @option_template_fields]
  @option_scalars [{"value", :string}, {"label", :string}]
  @selection_bounds [:min_selections, :max_selections]

  # The validation formats this package will recognize when a response
  # arrives. A document naming one of these is admitted; the checks
  # themselves belong to response validation.
  @formats ["email", "phone", "pattern", "integer", "number", "date", "time", "datetime"]

  @key_shape ~r/^[a-z][a-z0-9_]*$/

  # The scalars the document schema types, each with the JSON type it gives
  # it. A value of another type in one of them is not a document to the
  # schema, and so it is not one to `admit/1` either: the schema says of
  # itself that schema-valid means admitted, and that holds read in both
  # directions only if admission refuses what the schema refuses.
  @envelope_scalars [{"id", :string}, {"kind", :string}, {"schema_version", :integer}]
  @screen_scalars [{"key", :string}, {"title", :string}]
  @node_scalars [{"key", :string}, {"type", :string}, {"condition", :string}]

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
         true <- typed?(raw, @envelope_scalars),
         {:ok, metadata} <- admit_metadata(Map.fetch(raw, "metadata")),
         version = integral(Map.get(raw, "schema_version")),
         {:ok, admitted} <- admit_each(screens, &admit_screen(&1, spelling(version, screens))) do
      %__MODULE__{
        schema_version: version,
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
  each type raises about itself. Findings come back in document order, element
  by element, with the duplicate keys first because they are about the document
  rather than about any one element.

      iex> doc = Riddler.Screens.Document.admit(%{"schema_version" => 2, "screens" => [
      ...>   %{"key" => "account", "title" => "Create your account", "elements" => [
      ...>     %{"type" => "carousel", "key" => "pictures"}
      ...>   ]}
      ...> ]})
      iex> {:error, [finding]} = Riddler.Screens.Document.validate(doc)
      iex> {finding.code, finding.element_key}
      {"document.unknown_type", "pictures"}
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [Finding.t()]}
  def validate(%__MODULE__{} = document) do
    secrets = secret_keys(document)

    findings =
      kind_findings(document) ++
        envelope_findings(document) ++
        duplicate_findings(document) ++
        Enum.flat_map(document.screens, &screen_findings(&1, secrets, document.schema_version))

    case findings do
      [] -> {:ok, document}
      findings -> {:error, findings}
    end
  end

  # The template-field list belongs to the module that refuses a document, so a
  # field only becomes a template by being named there. `Riddler.Screens`
  # already depends on this module and reads the list through this accessor;
  # the reverse reference would be a cycle. No part of the package's surface,
  # exactly as `formats/0` is not.
  @doc false
  @spec template_fields() :: [atom()]
  def template_fields, do: @template_fields

  # The template fields of a choice question's option, read the same way and
  # for the same reason: the refusal here and the render in `Riddler.Screens`
  # are two passes over one list.
  @doc false
  @spec option_template_fields() :: [atom()]
  def option_template_fields, do: @option_template_fields

  @doc false
  @spec formats() :: [String.t()]
  def formats, do: @formats

  # The key shape as a pattern source, for the authoring schema.
  @doc false
  @spec key_pattern() :: String.t()
  def key_pattern, do: Regex.source(@key_shape)

  # The keys of every secret question the document declares, on any screen and
  # among any variant's candidates, whatever its condition. Only a key that is
  # a string names a response. Admission refuses a reference to one of these
  # responses, and resolution removes each of them from the root a condition
  # and a template read, so both read this one list. No part of the package's
  # surface.
  @doc false
  @spec secret_keys(t()) :: [String.t()]
  def secret_keys(%__MODULE__{screens: screens}) do
    screens
    |> Enum.flat_map(&secret_questions/1)
    |> Enum.map(& &1.key)
    |> Enum.uniq()
  end

  # The secret questions one screen declares, in document order, a variant's
  # candidates included and whatever their condition, each carrying a key
  # that is a string. `secret_keys/1` reads every screen through it, and the
  # seal reads the one screen it was named. No part of the package's surface.
  @doc false
  @spec secret_questions(%{elements: [map()]}) :: [map()]
  def secret_questions(%{elements: nodes}), do: Enum.flat_map(nodes, &secret_questions_under/1)

  defp secret_questions_under(node) do
    own =
      case node do
        %{type: @secret_type, key: key} when is_binary(key) -> [node]
        _other -> []
      end

    own ++ Enum.flat_map(candidates(node), &secret_questions_under/1)
  end

  # -- admit ----------------------------------------------------------------

  # An absent `kind` is the default rather than `nil`: the decided kind is
  # carried through to the resolved document, so a host holding one can tell
  # what it is holding without the document it came from. A kind that is
  # there and wrong is carried as it was written, because `validate/1` has to
  # name the value it refused.
  defp admit_kind(nil), do: @default_kind
  defp admit_kind(kind), do: kind

  # Only an absent `metadata` is the empty map: one written as `null` is a
  # value of the wrong type in a field the schema types, so it is not a
  # document, as for every other typed field.
  defp admit_metadata(:error), do: {:ok, %{}}
  defp admit_metadata({:ok, map}) when is_map(map) and not is_struct(map), do: {:ok, map}
  defp admit_metadata({:ok, _other}), do: :error

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

  # A screen's children are read from the key its document's version spells
  # and from no other. A screen that carries only the other version's key is
  # admitted with no elements, and `validate/1` refuses it by that key; a
  # screen that carries neither is not a document.
  defp admit_screen(raw, spelling) when is_map(raw) and not is_struct(raw) do
    with true <- typed?(raw, @screen_scalars),
         {children, other} = spelled(raw, spelling),
         :ok <- held(other, spelling),
         refused = refused(other, spelling),
         elements when is_list(elements) <- Map.get(children, "elements", refused && []),
         {:ok, admitted} <- admit_each(elements, &admit_node(&1, spelling)) do
      screen = %{key: Map.get(raw, "key"), title: Map.get(raw, "title"), elements: admitted}
      {:ok, other_spelling(screen, refused)}
    else
      _not_a_screen -> :error
    end
  end

  defp admit_screen(_raw, _spelling), do: :error

  defp admit_node(raw, spelling) when is_map(raw) and not is_struct(raw) do
    if typed?(raw, @node_scalars) do
      {children, other} = spelled(raw, spelling)
      admit_common(children, other, spelling)
    else
      :error
    end
  end

  defp admit_node(_raw, _spelling), do: :error

  defp admit_common(raw, other, spelling) do
    common = raw |> take(@common_fields) |> Map.put_new(:type, nil) |> admit_checks()

    case Registry.fetch(common.type) do
      {:ok, module} ->
        admit_typed(raw, common, module, other, spelling)

      :error ->
        with :ok <- held(other, spelling),
             :ok <- unread_nodes(raw, spelling),
             do: {:ok, common}
    end
  end

  defp admit_checks(%{checks: checks} = common), do: %{common | checks: Checks.admit(checks)}
  defp admit_checks(common), do: common

  defp admit_typed(raw, common, module, other, spelling) do
    %{required: required, optional: optional} = module.fields()
    refused = (:elements in required or :elements in optional) && refused(other, spelling)

    with :ok <- held(other, spelling),
         {:ok, typed} <- admit_choice(Map.merge(common, take(raw, required ++ optional))) do
      admit_candidates(raw, typed, refused, spelling)
    end
  end

  # Only a container has children, so only a container is refused for the
  # other version's key; on any other element both keys are fields its type
  # does not name, dropped once each is held to the shape the schema gives it.
  defp admit_candidates(raw, typed, refused, spelling) do
    case Map.fetch(typed, :elements) do
      {:ok, candidates} when is_list(candidates) ->
        with {:ok, admitted} <- admit_each(candidates, &admit_node(&1, spelling)) do
          {:ok, typed |> Map.put(:elements, admitted) |> other_spelling(refused)}
        end

      {:ok, _not_a_list} ->
        :error

      :error ->
        with :ok <- unread_nodes(raw, spelling), do: {:ok, other_spelling(typed, refused)}
    end
  end

  # How a document of this version reads a screen's and a container's
  # children: the key it spells them under (`own`), the other version's key
  # (`other`), whether it refuses that other key by name (`refuses`), and
  # whether `elements` is held to a shape where nothing reads it (`typed`),
  # which is wherever the document is read from `elements`. A document
  # that declares no version is version 1.
  #
  # A version this package does not implement refuses no key, and is read as
  # riddler 0.7.0 read it: from `nodes`, wherever any of its screens carries
  # that key, with `elements` left unread; a document none of whose screens
  # carries `nodes` is read from `elements`, as a version 2 document is but
  # refusing no key. Either way the version is the one finding `validate/1`
  # raises about the reading.
  defp spelling(nil, _screens), do: Map.fetch!(@spellings, 1)

  defp spelling(version, _screens) when is_map_key(@spellings, version),
    do: Map.fetch!(@spellings, version)

  defp spelling(_unknown, screens) do
    if Enum.any?(screens, &(is_map(&1) and Map.has_key?(&1, "nodes"))),
      do: %{own: "nodes", other: "elements", refuses: false, typed: false},
      else: %{own: "elements", other: "nodes", refuses: false, typed: true}
  end

  # The value with its children under `"elements"`, read from the key its
  # version spells, and the other version's key with what it holds, where the
  # value carries it. Whatever is under that other key is carried nowhere:
  # nothing under it is admitted, validated or resolved.
  defp spelled(raw, %{own: own, other: other}) do
    children = Map.drop(raw, ["nodes", "elements"])

    children =
      case Map.fetch(raw, own) do
        {:ok, value} -> Map.put(children, "elements", value)
        :error -> children
      end

    case Map.fetch(raw, other) do
      {:ok, value} -> {children, {other, value}}
      :error -> {children, nil}
    end
  end

  defp refused({other, _value}, %{refuses: true}), do: other
  defp refused(_other, _spelling), do: nil

  # A key that is carried nowhere is held to the shape the document schema
  # gives it there, and to no other, so that what the schema calls a document
  # is admitted and what it refuses is not. `nodes` is a list of elements on a
  # screen and on an element at every version, as riddler 0.7.0 held it.
  # `elements` is a list of elements, on a screen and on an element alike,
  # wherever a document is read from `elements`: at version 2, and at a
  # version this package does not implement when none of its screens carries
  # `nodes`. Wherever a document is read from `nodes` it is a key nothing
  # reads, of any value, dropped unread as 0.7.0 dropped it.
  defp held(nil, _spelling), do: :ok

  defp held({key, value}, spelling) do
    if held?(key, spelling), do: shape(value, spelling), else: :ok
  end

  defp held?("nodes", _spelling), do: true
  defp held?("elements", %{typed: typed}), do: typed

  defp shape(candidates, spelling) when is_list(candidates) do
    with {:ok, _dropped} <- admit_each(candidates, &admit_node(&1, spelling)), do: :ok
  end

  defp shape(_not_a_list, _spelling), do: :error

  defp other_spelling(admitted, nil), do: admitted
  defp other_spelling(admitted, false), do: admitted
  defp other_spelling(admitted, other), do: Map.put(admitted, @other_spelling, other)

  # A choice question's `answer_options` is the one field a type names that
  # the document schema types, under a conditional on the element's `type`: an
  # array of objects, each `value` and `label` a string where present. A value
  # of another shape there is not a document, as for every field the schema
  # types. Each option is admitted atom-keyed, carrying the `value` and `label`
  # the document wrote and nothing else, as an element carries only the fields its
  # type names. On every other element `answer_options` is a field the type does
  # not name, untyped by the schema and dropped above whatever it holds.
  #
  # The selection bounds are not typed by the schema, and a bound with no
  # fractional part is admitted as its integer: JSON does not tell `2.0` from
  # `2`, and a resolved question carrying `2.0` would read differently to a
  # runtime whose parser cannot see the difference. Any other value is carried
  # as written and is `validate/1`'s to refuse.
  defp admit_choice(%{type: @choice_type} = typed) do
    with {:ok, typed} <- admit_options(typed) do
      {:ok, Enum.reduce(@selection_bounds, typed, &integral_bound/2)}
    end
  end

  defp admit_choice(typed), do: {:ok, typed}

  defp admit_options(%{answer_options: options} = typed) when is_list(options) do
    with {:ok, admitted} <- admit_each(options, &admit_option/1) do
      {:ok, %{typed | answer_options: admitted}}
    end
  end

  defp admit_options(%{answer_options: _not_a_list}), do: :error
  defp admit_options(typed), do: {:ok, typed}

  defp admit_option(raw) when is_map(raw) and not is_struct(raw) do
    if typed?(raw, @option_scalars), do: {:ok, take(raw, @option_fields)}, else: :error
  end

  defp admit_option(_raw), do: :error

  defp integral_bound(bound, typed) do
    case Map.fetch(typed, bound) do
      {:ok, value} -> %{typed | bound => integral(value)}
      :error -> typed
    end
  end

  # A number with no fractional part read as its integer, and any other value
  # as it was written. JSON does not tell `1.0` from `1`, and a runtime whose
  # parser cannot see the difference has to read a document the same way this
  # one does, so `admit/1` reads the envelope's `schema_version` and a choice
  # question's selection bounds through this, and `resolve/2` and `validate/1`
  # see the integer.
  defp integral(value) when is_float(value) do
    if Float.round(value) == value, do: trunc(value), else: value
  end

  defp integral(value), do: value

  # Children on an element whose type reads none - every type but the
  # container, and a type the registry does not know - are carried nowhere,
  # as no field a type does not name is, once held to the shape the schema
  # gives it, by `held/3`. The other version's key was held when the element
  # was read; this is the element's own key, under the `"elements"` the
  # children were read into.
  defp unread_nodes(raw, %{own: own} = spelling) do
    case Map.fetch(raw, "elements") do
      {:ok, value} -> held({own, value}, spelling)
      :error -> :ok
    end
  end

  # Whether each of these fields, where the value carries it, holds a value of
  # the JSON type the schema gives it. A field that is absent is not this
  # check's: the schema requires none of them. A field that is there and holds
  # `null` is refused like any other value of the wrong type.
  defp typed?(raw, fields) do
    Enum.all?(fields, fn {spelling, type} ->
      case Map.fetch(raw, spelling) do
        {:ok, value} -> of_type?(type, value)
        :error -> true
      end
    end)
  end

  # JSON has one number type, and the schema's draft counts a number with no
  # fractional part as an integer, so `1.0` is an integer to it. A value the
  # schema calls an integer is admitted, and whether it is the version this
  # package implements stays `validate/1`'s question.
  defp of_type?(:string, value), do: is_binary(value)
  defp of_type?(:integer, value) when is_integer(value), do: true
  defp of_type?(:integer, value) when is_float(value), do: Float.round(value) == value
  defp of_type?(:integer, _value), do: false

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
        element_key: nil
      }
    ]
  end

  # The rest of the envelope: the `schema_version` this package is the
  # runtime for, checked only where the document carries one. An absent
  # version is `nil` in the admitted struct and is not a finding here: the
  # schema requires `screens` and nothing else, so whether the field is
  # required is a question this check does not answer, and answering it would
  # refuse documents this version admits. That the version is an integer, and
  # that the `id` beside it is a string, is `admit/1`'s: a value of another
  # type there is not a document.
  defp envelope_findings(%__MODULE__{} = document) do
    schema_version_findings(document.schema_version)
  end

  defp schema_version_findings(nil), do: []
  defp schema_version_findings(version) when version in @schema_versions, do: []

  defp schema_version_findings(version) do
    [
      %Finding{
        code: "document.invalid_schema_version",
        message:
          "a document this package is the runtime for declares schema_version #{Enum.join(@schema_versions, " or ")}, not #{inspect(version)}",
        field: "schema_version",
        element_key: nil
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
        element_key: key
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
      [screen.key | Enum.flat_map(screen.elements, &node_keys/1)]
    end)
    |> Enum.filter(&is_binary/1)
  end

  defp node_keys(node) do
    [node[:key] | Enum.flat_map(candidates(node), &node_keys/1)]
  end

  defp candidates(node) do
    case node[:elements] do
      candidates when is_list(candidates) -> candidates
      _none -> []
    end
  end

  defp screen_findings(screen, secrets, version) do
    key_findings(screen.key, "the screen #{inspect(screen.title)}") ++
      other_spelling_findings(screen, "screen", version) ++
      Enum.flat_map(screen.elements, &node_findings(&1, secrets, version)) ++
      outcome_findings(screen)
  end

  # -- each version has one spelling for a screen's children ------------------

  # A screen or a variant that carried the other version's key, whether or not
  # it carried its own beside it. One finding, naming the key refused; what was
  # under it was never admitted, so nothing under it raises anything.
  defp other_spelling_findings(%{@other_spelling => other} = admitted, what, version) do
    own = own_spelling(version)
    key = Finding.element_key(admitted[:key])

    [
      %Finding{
        code: "document.other_version_spelling",
        message:
          "the #{what} #{inspect(key)} carries #{inspect(other)}, and a version #{version || 1} document spells a #{what}'s elements #{inspect(own)} and no other way",
        field: other,
        element_key: key
      }
    ]
  end

  defp other_spelling_findings(_admitted, _what, _version), do: []

  # The key a document of this version writes a screen's and a variant's
  # children under, which is what a finding about those children names in its
  # `field`. A version this package does not implement is named as riddler
  # 0.7.0 named it, `nodes`.
  defp own_spelling(nil), do: own_spelling(1)

  defp own_spelling(version) when is_map_key(@spellings, version),
    do: Map.fetch!(@spellings, version).own

  defp own_spelling(_unknown), do: "nodes"

  defp spelled_fields(findings, version) do
    own = own_spelling(version)

    Enum.map(findings, fn
      %Finding{field: "elements"} = finding -> %{finding | field: own}
      finding -> finding
    end)
  end

  # -- each button a screen can show raises its own outcome -------------------

  # A screen's own elements are all shown together, conditions aside, so the
  # buttons under one of them are compared with the buttons under every other.
  # The buttons under one element are never compared with each other: the only
  # element that holds others is a variant, which resolves to one winner, so at
  # most one button under it is ever shown. Walking the screen's elements in
  # order, each button whose outcome a button under an earlier element already
  # raised is one finding naming the first such button.
  defp outcome_findings(screen) do
    {findings, _seen} =
      Enum.reduce(screen.elements, {[], %{}}, fn node, {findings, seen} ->
        buttons = buttons_under(node)

        repeats =
          for {key, outcome} <- buttons, Map.has_key?(seen, outcome) do
            duplicate_outcome(key, outcome, Map.fetch!(seen, outcome), screen.key)
          end

        seen =
          Enum.reduce(buttons, seen, fn {key, outcome}, acc -> Map.put_new(acc, outcome, key) end)

        {findings ++ repeats, seen}
      end)

    findings
  end

  defp buttons_under(node) do
    own =
      case node do
        %{type: "button", outcome: outcome} when is_binary(outcome) -> [{node[:key], outcome}]
        _other -> []
      end

    own ++ Enum.flat_map(candidates(node), &buttons_under/1)
  end

  defp duplicate_outcome(key, outcome, first_key, screen_key) do
    %Finding{
      code: "document.duplicate_outcome",
      message:
        "the outcome #{inspect(outcome)} is raised by the button #{inspect(first_key)} too, and the screen #{inspect(screen_key)} can show both; each button a screen can show raises its own outcome",
      field: "outcome",
      element_key: Finding.element_key(key)
    }
  end

  defp node_findings(node, secrets, version) do
    case Registry.fetch(node.type) do
      :error ->
        [
          %Finding{
            code: "document.unknown_type",
            message:
              "#{inspect(node.type)} is not an element type this package knows; the types are #{Enum.join(Registry.types(), ", ")}",
            field: "type",
            element_key: Finding.element_key(node[:key])
          }
        ]

      {:ok, module} ->
        key = Finding.element_key(node[:key])

        key_findings(node[:key], "the #{node.type} element") ++
          condition_findings(node, key) ++
          spelled_fields(missing_findings(node, module, key), version) ++
          other_spelling_findings(node, node.type, version) ++
          template_findings(node, key) ++
          secret_reference_findings(node, key, secrets) ++
          spelled_fields(module.validate(node), version) ++
          check_findings(node, key, secrets) ++
          Enum.flat_map(candidates(node), &node_findings(&1, secrets, version))
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
          element_key: key
        }
      ]
    end
  end

  defp key_findings(nil, what) do
    [
      %Finding{
        code: "document.invalid_key",
        message: "#{what} carries no key, and a key is how everything else names an element",
        field: "key",
        element_key: nil
      }
    ]
  end

  # A key that is there and is not a string is a different mistake from an
  # absent one, and the author fixing it needs to be told which: they wrote a
  # key, and they wrote it in a form nothing can name an element by. The value is
  # named here and not put on `element_key`, for the reason the moduledoc gives.
  defp key_findings(key, what) do
    [
      %Finding{
        code: "document.invalid_key",
        message:
          "#{what} carries #{inspect(key)} as its key, and a key is the string that names an element",
        field: "key",
        element_key: nil
      }
    ]
  end

  defp condition_findings(node, key) do
    case Map.fetch(node, :condition) do
      {:ok, condition} when is_binary(condition) ->
        compile_condition(condition, key)

      {:ok, condition} ->
        [invalid_condition(inspect(condition) <> " is not a condition", key, nil)]

      :error ->
        []
    end
  end

  # A condition that reached the parser and was refused is located by it, and
  # the place is read out of the refusal by the same helper the response check
  # reads it with, so the two doors cannot name different places for one
  # condition. A condition that never reached the parser has none.
  defp compile_condition(condition, key) do
    case Predicator.compile(condition) do
      {:ok, _instructions} ->
        []

      {:error, error} ->
        [invalid_condition(describe(error), key, Compilers.error_position(error))]
    end
  end

  defp describe(%{message: message}), do: message
  defp describe(error), do: inspect(error)

  # The place is appended from the position rather than from the numbers it was
  # built out of, so the message and the field cannot disagree about whether
  # there is one.
  defp span(%{line: line, column: column}), do: " (line #{line}, column #{column})"
  defp span(nil), do: ""

  defp invalid_condition(detail, key, position) do
    %Finding{
      code: "document.invalid_condition",
      message: "the condition does not parse: #{detail}" <> span(position),
      field: "condition",
      element_key: key,
      position: position
    }
  end

  # -- a question's checks ----------------------------------------------------

  # A `checks` on an element that is not a question, or one that is not a
  # list, is one finding. Otherwise each entry is read in list order, and an
  # entry's findings come in this order: not an object; each of `condition`,
  # `code` and `message` missing; a `code` not in the `check.` shape; a
  # `message` that is not a non-empty string; a `code` an earlier entry
  # carries; then its condition, as an element's condition is read: not a
  # string, not parsing, and naming a secret question's response. Every
  # finding's `field` is `"checks"`, and its message names the entry by its
  # place, counting from one, and by its code where the entry carries a string
  # one.
  defp check_findings(%{checks: checks} = node, key, secrets) do
    cond do
      node.type not in Checks.question_types() ->
        [
          invalid_check(
            "checks are carried by a question, and a #{node.type} element is not one",
            key
          )
        ]

      not is_list(checks) ->
        [invalid_check("checks is a list of checks, not #{inspect(checks)}", key)]

      true ->
        {findings, _codes} =
          checks
          |> Enum.with_index(1)
          |> Enum.reduce({[], []}, fn {entry, place}, {findings, codes} ->
            {findings ++ entry_findings(entry, place, codes, key, secrets), seen(entry, codes)}
          end)

        findings
    end
  end

  defp check_findings(_node, _key, _secrets), do: []

  defp seen(%{code: code}, codes) when is_binary(code), do: codes ++ [code]
  defp seen(_entry, codes), do: codes

  defp entry_findings(entry, place, codes, key, secrets) when is_map(entry) do
    named = named_check(place, entry)

    missing =
      for field <- Checks.fields(), not Map.has_key?(entry, field) do
        invalid_check("#{named} carries no #{field}", key)
      end

    missing ++
      code_findings(entry, named, key) ++
      message_findings(entry, named, key) ++
      repeated_code_findings(entry, named, codes, key) ++
      check_condition_findings(entry, named, key, secrets)
  end

  defp entry_findings(entry, place, _codes, key, _secrets) do
    [
      invalid_check(
        "check #{place} is an object of condition, code and message, not #{inspect(entry)}",
        key
      )
    ]
  end

  defp code_findings(%{code: code}, named, key) do
    if Checks.code?(code) do
      []
    else
      [
        invalid_check(
          "the code of #{named} is #{inspect(code)}, and an author's code is a string in the check. namespace: check, then one or more segments joined by dots, each a lower-case letter followed by lower-case letters, digits and underscores",
          key
        )
      ]
    end
  end

  defp code_findings(_entry, _named, _key), do: []

  defp message_findings(%{message: message}, _named, _key)
       when is_binary(message) and message != "",
       do: []

  defp message_findings(%{message: message}, named, key) do
    [
      invalid_check(
        "the message of #{named} is the text its author shows, a non-empty string, not #{inspect(message)}",
        key
      )
    ]
  end

  defp message_findings(_entry, _named, _key), do: []

  defp repeated_code_findings(%{code: code}, named, codes, key) when is_binary(code) do
    if code in codes do
      [
        invalid_check(
          "#{named} carries a code an earlier check on this question carries, and each check on a question carries its own",
          key
        )
      ]
    else
      []
    end
  end

  defp repeated_code_findings(_entry, _named, _codes, _key), do: []

  # A check's condition is refused as an element's condition is, by the same
  # codes, its `field` `"checks"` telling a host the condition is a check's.
  defp check_condition_findings(%{condition: condition}, named, key, secrets)
       when is_binary(condition) do
    parse =
      for %Finding{} = finding <- compile_condition(condition, key) do
        %{
          finding
          | field: "checks",
            message: "the condition of #{named} does not parse: " <> after_lead(finding.message)
        }
      end

    paths = condition_paths(condition)

    secret =
      for secret <- secrets, names_response?(paths, secret) do
        %Finding{
          code: "document.secret_reference",
          message:
            "the condition of #{named} reads responses.#{secret}, the response to the secret question #{inspect(secret)}, and no template, condition or write reads a secret question's response",
          field: "checks",
          element_key: key
        }
      end

    parse ++ secret
  end

  defp check_condition_findings(%{condition: condition}, named, key, _secrets) do
    [
      %Finding{
        code: "document.invalid_condition",
        message: "the condition of #{named} is #{inspect(condition)}, which is not a condition",
        field: "checks",
        element_key: key
      }
    ]
  end

  defp check_condition_findings(_entry, _named, _key, _secrets), do: []

  defp after_lead("the condition does not parse: " <> rest), do: rest
  defp after_lead(message), do: message

  defp named_check(place, %{code: code}) when is_binary(code),
    do: "check #{place} (#{inspect(code)})"

  defp named_check(place, _entry), do: "check #{place}"

  defp invalid_check(message, key) do
    %Finding{
      code: "document.invalid_check",
      message: message,
      field: "checks",
      element_key: key
    }
  end

  defp missing_findings(node, module, key) do
    %{required: required} = module.fields()

    for field <- required,
        not Map.has_key?(node, field),
        not supplied?(node, field),
        not refused?(node, field) do
      %Finding{
        code: "document.missing_field",
        message: "a #{node.type} element carries #{field}, and this one does not",
        field: Atom.to_string(field),
        element_key: key
      }
    end
  end

  # A choice question that names a context path for its options carries no
  # `answer_options`, and is not missing them: carrying both is the type's
  # `document.conflicting_options`, and carrying neither is still this
  # finding on `answer_options`.
  defp supplied?(%{type: @choice_type} = node, :answer_options),
    do: Map.has_key?(node, :answer_options_from)

  defp supplied?(_node, _field), do: false

  # A container that carried its candidates under the other version's key
  # only is refused for that key and not also for missing its own.
  defp refused?(node, :elements), do: Map.has_key?(node, @other_spelling)
  defp refused?(_node, _field), do: false

  defp template_findings(node, key) do
    node_fields =
      for field <- @template_fields,
          {:ok, source} <- [Map.fetch(node, field)],
          finding <- refusals(source, "the #{field} template", Atom.to_string(field), key) do
        finding
      end

    node_fields ++ option_template_findings(node, key)
  end

  # Each option's `label` and then its `description`, after the element's own
  # template fields and in the order the options are listed. The finding is the
  # one an element's template field raises, on the question's key; the message
  # names the option.
  defp option_template_findings(%{type: @choice_type, answer_options: options}, key)
       when is_list(options) do
    for {option, position} <- Enum.with_index(options, 1),
        is_map(option),
        field <- @option_template_fields,
        {:ok, source} <- [Map.fetch(option, field)],
        finding <-
          refusals(source, "the #{field} template of option #{position}", "#{field}", key) do
      finding
    end
  end

  defp option_template_findings(_node, _key), do: []

  # -- a secret question's response is read by nothing -----------------------

  # A condition, a template field, an option's label and a button's `writes`,
  # in that order, each naming `responses.<key>` for a secret question's key
  # or a path under it. One finding per field and per secret question named,
  # however many times the field names it. A template or a condition that does
  # not compile names no path here: it is already its own finding, and
  # resolution reads nothing out of it either.
  defp secret_reference_findings(_node, _key, []), do: []

  defp secret_reference_findings(node, key, secrets) do
    condition =
      case Map.fetch(node, :condition) do
        {:ok, source} when is_binary(source) -> [{"condition", condition_paths(source)}]
        _absent_or_refused -> []
      end

    templates =
      for field <- @template_fields,
          {:ok, source} <- [Map.fetch(node, field)],
          do: {Atom.to_string(field), template_paths(source)}

    named = condition ++ templates ++ option_paths(node) ++ writes_paths(node)

    for {field, paths} <- named,
        secret <- Enum.filter(secrets, &names_response?(paths, &1)) do
      %Finding{
        code: "document.secret_reference",
        message:
          "the #{field} reads responses.#{secret}, the response to the secret question #{inspect(secret)}, and no template, condition or write reads a secret question's response",
        field: field,
        element_key: key
      }
    end
  end

  defp names_response?(paths, secret) do
    Enum.any?(paths, &match?(["responses", ^secret | _under], &1))
  end

  defp template_paths(source) when is_binary(source) do
    case Template.compile(source) do
      {:ok, compiled} -> Template.paths(compiled)
      {:error, _findings} -> []
    end
  end

  defp template_paths(_not_source), do: []

  defp option_paths(%{type: @choice_type, answer_options: options}) when is_list(options) do
    for option <- options,
        is_map(option),
        field <- @option_template_fields,
        {:ok, source} <- [Map.fetch(option, field)],
        do: {Atom.to_string(field), template_paths(source)}
  end

  defp option_paths(_node), do: []

  # A write's address is `responses.<path>`, read as segments split on `.`
  # with a bracketed index starting a segment of its own, so a write to a
  # path under a secret question's response names that response.
  defp writes_paths(%{writes: writes}) when is_map(writes) do
    paths =
      for {path, _value} <- writes, is_binary(path) do
        path
        |> String.split(["."])
        |> Enum.flat_map(&String.split(&1, "[", parts: 2))
        |> Enum.take(2)
      end

    [{"writes", paths}]
  end

  defp writes_paths(_node), do: []

  # Every path a condition names, as segments: a name, then each property and
  # each literal key in brackets after it, up to the first key computed at
  # evaluation. Each access along a chain is a path of its own, so
  # `responses.library_pin.length` names `["responses", "library_pin"]` as
  # well.
  defp condition_paths(source) do
    case Predicator.parse(source) do
      {:ok, ast} -> ast |> collect_paths([]) |> Enum.reverse()
      _refused -> []
    end
  end

  defp collect_paths(term, acc) when is_tuple(term) do
    acc =
      case chain(term) do
        {:ok, path} -> [path | acc]
        :error -> acc
      end

    term |> Tuple.to_list() |> Enum.reduce(acc, &collect_paths/2)
  end

  defp collect_paths(list, acc) when is_list(list), do: Enum.reduce(list, acc, &collect_paths/2)
  defp collect_paths(_other, acc), do: acc

  defp chain({:identifier, name, _position}) when is_binary(name),
    do: {:ok, String.split(name, ".")}

  defp chain({:property_access, object, property, _position}) when is_binary(property) do
    with {:ok, path} <- chain(object), do: {:ok, path ++ [property]}
  end

  defp chain({:bracket_access, object, {:string_literal, key, _quote, _position}, _at})
       when is_binary(key) do
    with {:ok, path} <- chain(object), do: {:ok, path ++ [key]}
  end

  defp chain(_not_a_path), do: :error

  defp refusals(source, what, _field, key) when is_binary(source) do
    case Template.compile(source) do
      {:ok, _compiled} ->
        []

      {:error, findings} ->
        Enum.map(findings, fn finding ->
          # The wrapped refusal's position is a place in the template this
          # element writes, so it survives the re-wrap. The message already
          # carries it as prose; carrying the field too is what spares a
          # host parsing that sentence, and this is the door a host with a
          # document comes through.
          %Finding{
            code: "document.invalid_template",
            message: "#{what} is refused: #{finding.message}",
            field: finding.field,
            element_key: key,
            position: finding.position
          }
        end)
    end
  end

  defp refusals(source, what, field, key) do
    [
      %Finding{
        code: "document.invalid_template",
        message: "#{what} is refused: #{inspect(source)} is not template source",
        field: field,
        element_key: key
      }
    ]
  end
end
