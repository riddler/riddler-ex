defmodule Riddler.Template.UnknownTag do
  @moduledoc false

  # A tag whose name the parser has no tag for - a construct outside the
  # subset that the parser does not know, or a branch or closing keyword
  # written where no block it belongs to is open - held in the parse tree as a
  # node of its own rather than reported as a refusal of the whole source.
  #
  # `Riddler.Template.compile/1` registers this module, for the names the
  # parser reported as unexpected, only on a second parse of a source the
  # parser refused, so that a block holding such a tag still parses and the
  # allowlist walk reaches everything else in the template. A tree holding one
  # of these is always refused, and it is never rendered.
  #
  # The tag reads its token to the end the way any tag does, so a string the
  # token carries stays a string rather than being read as template text.

  @behaviour Solid.Tag

  @enforce_keys [:loc, :name]
  defstruct [:loc, :name]

  @type t :: %__MODULE__{loc: Solid.Parser.Loc.t(), name: String.t()}

  @impl true
  def parse(name, loc, context) do
    case Solid.Lexer.tokenize_tag_end(context) do
      {:ok, _tokens, context} -> {:ok, %__MODULE__{loc: loc, name: name}, context}
      {:error, reason, rest, meta} -> {:error, reason, rest, meta}
    end
  end
end
