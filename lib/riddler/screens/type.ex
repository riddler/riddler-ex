defmodule Riddler.Screens.Type do
  @moduledoc """
  What an element type has to tell the document about itself.

  A type is a module. It declares the fields an element of that type may carry,
  and it checks the ones only it knows how to check - a heading's level, a
  button's writes, a variant's candidates. Everything an element needs that is
  not particular to its type - the key, the condition, the templates, the
  duplicate check - belongs to `Riddler.Screens.Document` and is done once
  for every element whatever its type is.

  The split is what keeps a sixth type from being a change to the document.
  Adding one is a module implementing this behaviour and a line in
  `Riddler.Screens.Registry`; nothing in the document's own checks moves.

  ## `fields/0`

  Returns `%{required: [atom()], optional: [atom()]}`. The names are the
  field names as a document spells them, as atoms. A required field the element
  does not carry is a finding the document raises; an optional one is not.
  A field named by neither list is not part of this version of the type, and
  the admitted element does not carry it.

  ## `validate/1`

  Takes the admitted element - an atom-keyed map, with the type's declared
  fields under their own names - and returns the findings that are this
  type's to raise, in source order, or `[]`. It is never asked about a field
  the element does not carry: a missing required field has already been
  reported, and there is nothing further to say about its value.
  """

  alias Riddler.Finding

  @typedoc """
  An admitted element, a child of a screen or of a container: `:type` and,
  where the document declared them, `:key`, `:condition` and the fields the
  element's type names.
  """
  @type element :: %{:type => term(), optional(atom()) => term()}

  @doc """
  The fields an element of this type may carry, split into required and optional.
  """
  @callback fields() :: %{required: [atom()], optional: [atom()]}

  @doc """
  The findings only this type can raise about an admitted element of it.
  """
  @callback validate(element()) :: [Finding.t()]
end
