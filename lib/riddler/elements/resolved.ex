defmodule Riddler.Elements.Resolved do
  @moduledoc """
  A document resolved against one visitor's context and responses.

  It is the same envelope the document carried - `schema_version`, `id` and
  `metadata` - with the screens the visitor is actually shown, plus
  `diagnostics`. A resolved document with a non-empty `diagnostics` is still a
  resolved document: resolution reports what it could not decide, it does not
  refuse. Refusing is `Riddler.Elements.Document.validate/1`'s job, and it
  happens before a visitor exists.

  ## The screens

  A resolved screen keeps its `key` and `title` and carries its nodes in the
  order the document declared them, with the nodes a condition hid absent
  rather than flagged, every container collapsed to its winner, every template
  field rendered to text, and no `condition` anywhere: a node that is present
  is a node that is shown. `writes` is carried through unchanged, because it is
  what the host applies when the visitor presses the button.

  ## The diagnostics

  `missing_variables` names each template variable that was absent, together
  with the key of the node whose template wanted it. `undecidable_conditions`
  names each node whose condition could not be evaluated, together with the
  condition that could not be evaluated. Both are in document order, and both
  are lists of entries rather than bare keys: one node can want two variables,
  and a diagnostic that cannot say which variable is a diagnostic an author
  cannot act on.
  """

  @typedoc "A template variable that was absent, and the node that wanted it."
  @type missing_variable :: %{key: term(), variable: String.t()}

  @typedoc "A condition that could not be evaluated, and the node carrying it."
  @type undecidable_condition :: %{key: term(), condition: term()}

  @typedoc "What resolution reports without refusing."
  @type diagnostics :: %{
          missing_variables: [missing_variable()],
          undecidable_conditions: [undecidable_condition()]
        }

  @typedoc "A resolved screen: the shape of the screen it came from."
  @type screen :: %{key: term(), title: term(), nodes: [Riddler.Elements.Type.node_t()]}

  @type t :: %__MODULE__{
          schema_version: term(),
          id: term(),
          metadata: %{optional(String.t()) => term()},
          screens: [screen()],
          diagnostics: diagnostics()
        }

  defstruct schema_version: nil,
            id: nil,
            metadata: %{},
            screens: [],
            diagnostics: %{missing_variables: [], undecidable_conditions: []}
end
