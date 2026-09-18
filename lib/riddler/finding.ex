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
      `%{line: line, column: column}`, both one-based and counting bytes as
      the parser's own locations do. Every template refusal sets it - the
      pinned parser locates every error it reports, and `position/2` declines
      half a span as defence rather than for a case that arises - and so does
      a `document.invalid_template` finding that wraps such a refusal,
      because the place it names is a place in the template the document node
      writes. It is `nil` everywhere else, and the rule is which checks
      OBTAIN a place rather than which inputs have source text:
      every check about the document as data, which has no place to carry; a
      field refused for not being template source at all, which has none
      either and carries the same `document.invalid_template` code, so that
      code alone does not promise a span; the `response.*` findings, which
      report a visitor's submission against a screen rather than refusing
      authored source, `response.undecidable` included, because a condition
      that cannot be decided against a host's root was refused at no place;
      and `document.invalid_condition` where the compiler gave the refused
      condition a place, whose message ends in a line and a column
      the finding does not yet carry - a `nil` that is owed, where the same
      code refusing a condition that is not source at all has no place to
      take and leaves an ordinary one. Where there is a position the
      `:message` names it too and goes on naming it, so that a person
      reading a finding reads one sentence; this field is the same
      fact in the form an editor can act on without parsing that sentence.

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
  A place in some source text: a one-based line and a one-based column, both
  counting bytes.
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
