# Ask a choice question

This page shows how to put a question with a fixed list of answers into a
screen document, and what to render and check on the host's side. It uses
patron registration: a visitor becomes a library patron through a few
screens, and one of them asks which library card they want.

It assumes you already have a document that admits and validates; if not,
start from the basic usage in the README.

## Pick the node type

Two node types ask a question with fixed answers:

- `choice_question` offers a list of options and the visitor picks one or
  several of them.
- `boolean_question` is a lone checkbox or toggle, and the visitor answers
  yes or no.

Both are nodes of a screen like any other, so each carries a `key`, unique
across the whole document, and an optional `condition`.

## Ask one question with `choice_question`

A `choice_question` needs a `label`, a `select` and `answer_options`:

```json
{
  "type": "choice_question",
  "key": "card_type",
  "label": "Which library card would you like, {{ context.first_name }}?",
  "select": "one",
  "style": "radio",
  "required": true,
  "answer_options": [
    { "value": "adult", "label": "Adult card" },
    { "value": "child", "label": "Child card (under 13)" },
    { "value": "senior", "label": "Senior card (65 and over)" }
  ]
}
```

- `label` is what the visitor is asked. It is a template, so it can read
  `context` as a text node does.
- `select` is `"one"` or `"many"`. It fixes the shape of what the visitor
  submits, as the next sections show. A `select` that is neither is a
  finding, `document.invalid_select`.
- `answer_options` is the list of options, in the order the visitor is shown
  them. It must not be empty.

### The option shape

An option is an object with two fields, and both are required:

- `value` is what the response holds when the visitor picks the option. It
  is a string that starts with a lower-case letter and carries only
  lower-case letters, digits and underscores after it (`[a-z][a-z0-9_]*`),
  so a condition or a template can compare a response with it as written.
  Two options of one question cannot share a value, but two questions may
  each offer `adult`.
- `label` is what the visitor reads. It is a template, like the question's
  own `label`.

A field an option carries beyond these two is dropped when the document is
admitted, with no finding. In particular an option has no `condition` in this
version.

A defect in an option is a finding at validation: `document.invalid_option`
for a missing field or a `value` outside the pattern,
`document.duplicate_option_value` for a repeated value, and
`document.empty_answer_options` for a list with no options in it.

### The style hint

`style` tells the host's renderer which widget to draw. The names offered are
`radio` and `dropdown` for `select: "one"`, and `checkboxes` and `list` for
`select: "many"`. The set is open and the renderer owns it: Riddler checks
that `style` is a string and nothing more (a `style` that is not a string is
`document.invalid_style`), so a name it does not list, or one
offered for the other `select`, is passed through to the renderer unchanged. A
renderer that gets no `style` picks a widget by the number of options.

`boolean_question` carries no `style`; one written on it is dropped when the
document is admitted.

## Let a visitor pick several

Set `select` to `"many"` to let a visitor pick any number of options, and
bound the choice with `min_selections` and `max_selections`:

```json
{
  "type": "choice_question",
  "key": "reading_interests",
  "label": "What do you like to read?",
  "select": "many",
  "style": "checkboxes",
  "min_selections": 1,
  "max_selections": 3,
  "answer_options": [
    { "value": "fiction", "label": "Fiction" },
    { "value": "history", "label": "History" },
    { "value": "science", "label": "Science" },
    { "value": "graphic_novels", "label": "Graphic novels" },
    { "value": "local_authors", "label": "Books by {{ context.branch_name }} authors" }
  ]
}
```

The bounds are read only under `select: "many"`. Each is a non-negative whole
number (`2.0` is accepted and read as `2`); `min_selections` must not be above
`max_selections`, and neither may be above the number of options. Any of
these breaks, or a bound on a question whose `select` is `"one"`, is a
finding, `document.invalid_selection_bounds`.

## Ask a yes-or-no question with `boolean_question`

A `boolean_question` needs only a `label`:

```json
{
  "type": "boolean_question",
  "key": "agrees_to_rules",
  "label": "I agree to the borrowing rules of {{ context.library_name }}.",
  "required": true
}
```

On a `boolean_question`, `required: true` means the response must be `true`:
an unticked box is a visitor declining, not an empty field. That is the shape
of "tick to agree".

## What a host renders

`Riddler.Screens.resolve/2` and `resolve_screen/3` hand back the question with
its `label` rendered and no `condition`, and `answer_options` in the same
order with each option's `label` rendered against the root. Each `value` comes
back exactly as written, and `select`, `style`, `required` and the bounds are
carried through. A variable an option label wants that the root does not carry
renders as the empty string and is reported in `missing_variables` under the
question's key, as for any other template on the node.

Resolved against a root whose `context.branch_name` is `Riverside`, the last
option above reads `%{value: "local_authors", label: "Books by Riverside
authors"}`.

The host draws the widget, and it submits what the visitor picked under
`responses`, addressed by the question's key.

## What each question submits

| Type | `select` | The response | Nothing selected |
|---|---|---|---|
| `choice_question` | `"one"` | one option's `value`, a string | absent, `null` or `""` |
| `choice_question` | `"many"` | a list of distinct option values, in any order | absent, `null` or `[]` |
| `boolean_question` | - | `true` or `false` | absent or `null` |

For example, a visitor who chose the senior card and two reading interests
submits:

```json
{
  "responses": {
    "card_type": "senior",
    "reading_interests": ["fiction", "history"],
    "agrees_to_rules": true
  }
}
```

## Check what the visitor submitted

Pass the root, with `responses`, to `Riddler.Screens.validate_screen/3` or
`validate_screen/4`. Every choice and boolean question on the resolved screen
is checked, whether or not it declares `required`, and each raises at most one
finding. The checks run in this order, and the first that applies is the
question's finding:

1. Nothing is selected. A required question answers `response.required`; one
   that is not required answers nothing, and its bounds are not consulted, so
   an empty selection is accepted whatever its `min_selections`.
2. The response is not the shape the type and `select` fix: a list under
   `"one"`, a string under `"many"`, a list holding a value that is not a
   string or holding one value twice, or anything but `true` or `false` for a
   boolean question. `response.invalid_shape`.
3. A required boolean question whose response is `false`.
   `response.required`.
4. A value that no option of the question carries. `response.not_an_option`,
   one finding naming every such value. Values are compared as written: none
   is trimmed or case-folded.
5. Under `"many"`, fewer values than `min_selections` or more than
   `max_selections`. `response.out_of_range`, its `field` naming the bound.

Against the questions above:

| Response | Finding |
|---|---|
| `"card_type": "senior"` | none |
| `"card_type": "teen"` | `response.not_an_option` |
| `"card_type": ["adult"]` | `response.invalid_shape` |
| no `card_type` | `response.required` |
| `"reading_interests": []` | none: the question is not required |
| `"reading_interests"` with four values | `response.out_of_range`, `field` `max_selections` |
| `"reading_interests": ["fiction", "fiction"]` | `response.invalid_shape` |
| `"agrees_to_rules": false` | `response.required` |

A question whose `condition` hid it is not on the resolved screen, so it is
not checked and a response addressed to it is not read. A button that
declares `validates` as `false` skips the check for the whole screen, these
questions included.

## Required

`required` is a boolean and defaults to false. On a `choice_question` it means
the visitor picks at least one option. On a `boolean_question` it means the
response is `true`. A `required` that is not a boolean is a finding,
`document.invalid_required`.

## What `format` does here

Either type accepts a `format` and carries it through resolution, but nothing
reads it: no `document.unknown_format` is raised for it and no format is
applied to a response.

## See also

- `Riddler.Screens.Type.ChoiceQuestion` and
  `Riddler.Screens.Type.BooleanQuestion` for the fields and the findings.
- `Riddler.Screens.validate_screen/4` for the check and the `validates`
  opt-out.
