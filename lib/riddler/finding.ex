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
    * `:node_key` - the key of the document node the finding belongs to, and
      always a string or `nil`. It is `nil` wherever there is no key a host
      can look a node up by: a template finding, because a template is
      compiled on its own without the document that carries it; a finding
      about the envelope, which is the document's and not any one node's; and
      a node whose key is absent or is not a string. A key of the wrong form
      is named in the `message` rather than carried here, because a host reads
      this field to find the node the author has to fix and a key that is not
      a string is not a name it can find one by.

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
end
