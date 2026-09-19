defmodule Riddler.Screens.Compilers do
  @moduledoc false

  # The one reading this package takes of what a compiler it depends on hands
  # back.
  #
  # Two checks over a screen document ask the same things of those compilers:
  # the document check, which reads a document before a visitor arrives, and
  # the response check, which reads what a visitor sent back. Both ask whether
  # a `pattern` source compiles, and both ask where a refused condition is. A
  # single reading of each answer is what keeps the two doors from disagreeing,
  # and neither check owns that reading, so it lives here rather than inside
  # either of them. No part of the package's surface.

  alias Riddler.Finding

  # The one place a `pattern` source becomes a regular expression. The response
  # check compiles the author's expression with it to hold a response to, and
  # the document check compiles the same expression with it to decide whether
  # the format can use it, which is the whole reason it is shared: two
  # compilers would drift, and a document check holding an expression to
  # anchors the format did not apply would admit a pattern the format cannot
  # use, or refuse one it can. No part of the package's surface, as nothing in
  # this module is.
  #
  # The refusal's offset is discarded rather than carried, and that is a
  # decision. `Regex.compile/1` answers `{reason, offset}`, and the offset is a
  # byte count into the string compiled here, which is the author's expression
  # inside the anchors rather than the author's expression. What it counts to
  # is not one thing. Ten refusals were run against it. For six - an unmatched
  # `)`, a `{2,1}` quantifier, a `[z-a]` range, a doubled `*` on a second line,
  # a duplicate group name, and a malformed `(?P` - the offset lands at the
  # defect or at the character that closes it. For four - three unterminated
  # constructs and a trailing backslash - it lands at the end of the input
  # instead, the defect being detected only when the scan runs out. The
  # duplicate-name run, whose second name follows two two-byte characters,
  # answers 15 where the character count to the same place is 13, which is what
  # shows the count to be bytes. The anchors then move five of those six by
  # exactly the five bytes they add in front; the sixth, the unmatched `)`,
  # relocates onto the wrapper's own `)`; and the trailing backslash changes
  # reason as well, from one naming a backslash at the end of the pattern to
  # one naming a missing parenthesis. So a place derived from the offset would
  # be right for some refusals and wrong for others under one finding code,
  # which is worse for a host than none at all. `document.invalid_pattern`
  # names no place and carries none. These ten are the runs made and not a
  # classification of every refusal the compiler can answer.
  @doc false
  @spec compile_pattern(term()) :: {:ok, Regex.t()} | :error
  def compile_pattern(source) when is_binary(source) do
    case Regex.compile("\\A(?:" <> source <> ")\\z") do
      {:ok, regex} -> {:ok, regex}
      {:error, _reason} -> :error
    end
  end

  def compile_pattern(_source), do: :error

  # The place a refusal from the condition compiler or the evaluator names, in
  # the form a finding carries. The document check and the response check both
  # locate a refused condition with it, for the reason `compile_pattern/1` is
  # shared: one reading of what the dependency hands back is what keeps the two
  # doors from disagreeing about where a condition is wrong. No part of the
  # package's surface, as nothing in this module is.
  @doc false
  @spec error_position(term()) :: Finding.position() | nil
  def error_position(%{position: {line, column}}), do: Finding.position(line, column)
  def error_position(_placeless), do: nil
end
