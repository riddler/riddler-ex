defmodule Riddler.Finding do
  @moduledoc """
  One reason something was refused.

  A finding is the unit every refusal in this package reports: a template that
  names a construct outside the template subset, and later a document whose
  vocabulary is not admitted. Refusals return a list of findings rather than
  the first one, so that an author fixing what they wrote learns everything
  wrong with it in a single pass.

  The fields are deliberately few:

    * `:code` - a stable, machine-readable reason. Hosts switch on it; it does
      not change when the wording does.
    * `:message` - the human sentence, naming what was refused and, where the
      refusal has a place in some source text, where it appeared.
    * `:field` - what the finding is about: the name of the refused construct
      for a template, the offending field for a document. `nil` when the
      refusal is about the input as a whole.
    * `:node_key` - the key of the document node the finding belongs to.
      Always `nil` for a template finding: a template is compiled on its own,
      without the document that carries it.

  ## Examples

      iex> %Riddler.Finding{
      ...>   code: "template.tag_not_allowed",
      ...>   message: ~s(the tag "include" is not in the template subset (line 1, column 3)),
      ...>   field: "include"
      ...> }.node_key
      nil
  """

  @type t :: %__MODULE__{
          code: String.t(),
          message: String.t(),
          field: String.t() | nil,
          node_key: String.t() | nil
        }

  @enforce_keys [:code, :message]
  defstruct [:code, :message, :field, :node_key]
end
