defmodule Riddler.Screens.Resolved do
  @moduledoc """
  A document resolved against one visitor's context and responses.

  It is the same envelope the document carried - `schema_version`, `kind`,
  `id` and `metadata` - with the screens the visitor is actually shown, plus
  `diagnostics`. A resolved document with a non-empty `diagnostics` is still a
  resolved document: resolution reports what it could not decide, it does not
  refuse. Refusing is `Riddler.Screens.Document.validate/1`'s job, and it
  happens before a visitor exists.

  `kind` is the kind the document was decided to belong to, carried through
  so that a host holding a resolved document can tell what it is holding
  without the document it came from.

  ## The screens

  A resolved screen keeps its `key` and `title` and carries its elements in the
  order the document declared them, with the elements a condition hid absent
  rather than flagged, every container collapsed to its winner, every template
  field rendered to text, and no `condition` anywhere: an element that is present
  is an element that is shown. `writes` is carried through unchanged, because it is
  what the host applies when the visitor presses the button.

  ## The diagnostics

  `missing_variables` carries two kinds of entry, each with the key of the
  element it was found on: a template variable that was absent (its `variable`
  the name the template wanted, once per field that wanted it), and an
  `answer_options_from` path that held no list of options (its `variable` the
  path as written). `undecidable_conditions`
  names each element whose condition could not be evaluated, together with the
  condition that could not be evaluated. Both are in document order, and both
  are lists of entries rather than bare keys: one element can want two variables,
  and a diagnostic that cannot say which variable is a diagnostic an author
  cannot act on.
  """

  @typedoc "A template variable that was absent, and the element that wanted it."
  @type missing_variable :: %{key: term(), variable: String.t()}

  @typedoc "A condition that could not be evaluated, and the element carrying it."
  @type undecidable_condition :: %{key: term(), condition: term()}

  @typedoc "What resolution reports without refusing."
  @type diagnostics :: %{
          missing_variables: [missing_variable()],
          undecidable_conditions: [undecidable_condition()]
        }

  @typedoc "A resolved screen: the shape of the screen it came from."
  @type screen :: %{key: term(), title: term(), elements: [Riddler.Screens.Type.element()]}

  @type t :: %__MODULE__{
          schema_version: term(),
          kind: term(),
          id: term(),
          metadata: %{optional(String.t()) => term()},
          screens: [screen()],
          diagnostics: diagnostics()
        }

  defstruct schema_version: nil,
            kind: nil,
            id: nil,
            metadata: %{},
            screens: [],
            diagnostics: %{missing_variables: [], undecidable_conditions: []}
end
