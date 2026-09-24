defmodule Riddler.Finding do
  @moduledoc """
  One reason something was refused.

  A finding is the unit every refusal in this package reports: a template that
  names a construct outside the template subset, and later a document whose
  vocabulary is not admitted. Refusals return a list of findings rather than
  the first one, so that an author fixing what they wrote learns everything
  wrong with it in a single pass.

  The fields stay few, and one is added only where a host would otherwise have
  to read the `:message` to get at something it needs:

    * `:code` - a stable, machine-readable reason. Hosts switch on it; it does
      not change when the wording does.
    * `:message` - the human sentence, naming what was refused and, where the
      refusal has a place in some source text, where it appeared.
    * `:field` - what the finding is about: the name of the refused construct
      for a template, the offending field for a document. `nil` when the
      refusal is about the input as a whole.
    * `:node_key` - the key of the document node the finding belongs to, and
      always a string or `nil`. It is `nil` wherever there is no key a host
      can look a node up by: a template finding, because a template is
      compiled on its own without the document that carries it; a finding
      about the envelope, which is the document's and not any one node's; and
      a node whose key is absent or is not a string. A key of the wrong form
      is named in the `message` rather than carried here, because a host reads
      this field to find the node the author has to fix and a key that is not
      a string is not a name it can find one by.
    * `:position` - where in some source text the refusal is, as
      `%{line: line, column: column}`, both one-based. The column counts in
      the unit of the parser that located the refusal, and this package
      converts neither: a column the template parser gave counts bytes, and a
      column the condition compiler or the evaluator gave counts characters.
      The two differ wherever a multi-byte character stands before the place
      on its line, so a host that maps a column onto an editor offset reads
      the finding's code to know which it holds. Five places in this package
      set it: the two template refusal clauses in `Riddler.Template`, the
      `document.invalid_template` finding that re-reports a template refusal
      against the template a document node writes, which carries the position
      of the refusal it wraps, the `document.invalid_condition` finding, which
      carries the place the condition compiler gave for a condition that does
      not parse and nothing for a condition that never reached the parser, and
      the `response.undecidable` finding, which carries the place the condition
      compiler or the evaluator gave for the condition it is about and nothing
      where neither gave one. The first three give bytes and the last two give
      characters. Every other finding leaves it `nil` - the
      document checks, a field refused for not being template source at all
      (which carries that same code, so the code alone does not say whether a
      span is there), and the other `response.*` findings.
      `document.invalid_pattern` is one of those by decision rather than by
      defect: the regular expression compiler answers a byte count into the
      expression this package compiles rather than a line and a column, and
      across the refusals run that count lands at the defect for some and at
      the end of the input for others, and is moved, or its reason replaced,
      by the anchors this package adds. A place derived from it would be right
      for some refusals under that code and wrong for others, which is worse
      for a host than none; the comment above `compile_pattern/1` in the
      internal Riddler.Screens.Compilers module records what was run. Where there is a
      position the `:message` names
      it too and goes on naming it, so that a person reading a finding reads
      one sentence; this field is the same fact in the form an editor can act
      on without parsing that sentence.

  ## Examples

      iex> finding = %Riddler.Finding{
      ...>   code: "template.tag_not_allowed",
      ...>   message: ~s[the tag "include" is not in the template subset (line 1, column 3)],
      ...>   field: "include",
      ...>   position: %{line: 1, column: 3}
      ...> }
      iex> {finding.node_key, finding.position}
      {nil, %{line: 1, column: 3}}
  """

  @typedoc """
  A place in some source text: a one-based line and a one-based column. The
  column counts bytes where the template parser located the place and
  characters where the condition compiler or the evaluator did; the
  `:position` field in the moduledoc says which finding gives which.
  """
  @type position :: %{line: pos_integer(), column: pos_integer()}

  @type t :: %__MODULE__{
          code: String.t(),
          message: String.t(),
          field: String.t() | nil,
          node_key: String.t() | nil,
          position: position() | nil
        }

  @enforce_keys [:code, :message]
  defstruct [:code, :message, :field, :node_key, :position]

  # The `:node_key` a raw document key earns. A key is a string by the record
  # the document implements, so a key of any other form is one no host can
  # look a node up by and this field is `nil` for it, exactly as it is for a
  # node that declares no key at all. Every check that puts a node's key on a
  # finding goes through here, which is what keeps the field inside its own
  # typespec whatever a host wrote.
  @doc false
  @spec node_key(term()) :: String.t() | nil
  def node_key(key) when is_binary(key), do: key
  def node_key(_key), do: nil

  # The `:position` a line and a column earn. A position is a whole span or it
  # is nothing: a line without a column, or either of them absent because the
  # parser reported an error it had no place for, is a span no editor can
  # point at, and this field is `nil` for it rather than half a pair. Every
  # check that puts a source position on a finding goes through here, for the
  # reason `node_key/1` exists - it is what keeps the field inside its own
  # typespec whatever the parser handed back.
  @doc false
  @spec position(term(), term()) :: position() | nil
  def position(line, column)
      when is_integer(line) and line > 0 and is_integer(column) and column > 0,
      do: %{line: line, column: column}

  def position(_line, _column), do: nil
end
