# Supply options at run time

This page shows how to let your host decide, when a screen is shown, which
options a choice question offers, by naming a path under `context` instead of
writing the options into the document. It uses patron registration: a visitor
picks the library branch that will issue their card, and which branches are
open is your host's data, not the document author's.

It assumes you already have a document that admits and validates, and have
read [Ask a choice question](ask-a-choice-question.md) for the option shape.

## Name the path

Give the `choice_question` an `answer_options_from` where it would have had
`answer_options`:

```json
{
  "type": "choice_question",
  "key": "home_branch",
  "label": "Which branch will issue your card?",
  "select": "one",
  "required": true,
  "answer_options_from": "context.branches"
}
```

The path is dotted segments that start at `context` and have at least one more
segment, each a lower-case letter followed by lower-case letters, digits and
underscores, as a `prefill` path is. A path of another form is
`document.invalid_context_path`.

A question takes its options from one place. One that carries both
`answer_options` and `answer_options_from` is `document.conflicting_options`,
and one that carries neither is `document.missing_field` on `answer_options`.

## Put the list in the context

Your host puts the list in the context it sends, under that path. Each entry is
an object with a `value` and a `label`, both strings:

```elixir
context = %{
  "first_name" => "Ada",
  "branches" => [
    %{"value" => "riverside", "label" => "Riverside"},
    %{"value" => "hilltop", "label" => "Hilltop"}
  ]
}
```

- `value` has the shape any option's value has, `[a-z][a-z0-9_]*`, and no two
  entries share one.
- `label` is shown as you wrote it. Unlike an authored option's label, it is
  not a template: a `{{ ... }}` in it is not rendered.
- An entry's other keys are dropped, and the order of the list is the order
  the visitor is shown.

Send the context with `Riddler.Journey.put_context/2` as the Journey goes on,
as [Present a Journey](present-a-journey.md) shows.

## What the visitor is shown

Resolving or presenting the screen reads the list at the path and gives the
question the options as `answer_options`, with no `answer_options_from` left,
so a renderer draws it as it draws any choice question:

```elixir
{:ok, %{"screen" => screen}} =
  Riddler.Journey.present(document, {:screen, "patron_details"}, %{"context" => context})

hd(screen["elements"])["answer_options"]
#=> [
#     %{"value" => "riverside", "label" => "Riverside"},
#     %{"value" => "hilltop", "label" => "Hilltop"}
#   ]
```

A path that reaches nothing, or a value that is not a list of such entries (an
entry with a `value` outside the shape, a repeated `value`, a missing `label`),
gives the question no options, and the screen reports it in `missing_variables`:

```elixir
{:ok, %{"screen" => screen}} =
  Riddler.Journey.present(document, {:screen, "patron_details"}, %{"context" => %{}})

screen["diagnostics"]["missing_variables"]
#=> [%{"key" => "home_branch", "variable" => "context.branches"}]
```

An empty list is a question with no options and is not reported: you said
there are none. Either way a required question cannot be answered, so decide
in your host what the visitor sees when the list is empty.

## Check the submit against the options of the moment

A response is checked against the options the context holds when the screen is
validated, not the ones it held when the screen was shown. Pass
`validate_screen/3,4` the context your host holds at submit time:

```elixir
root = %{
  "context" => %{"branches" => [%{"value" => "riverside", "label" => "Riverside"}]},
  "responses" => %{"home_branch" => "hilltop"}
}

{:error, [finding]} = Riddler.Screens.validate_screen(document, "patron_details", root)
{finding.code, finding.element_key}
#=> {"response.not_an_option", "home_branch"}
```

A branch that closed between the screen and the submit is
`response.not_an_option`. A host that wants the visitor to see the shortened
list present the screen again with the new context. A host that sends the
context as it was when the screen was shown accepts a value the world no longer
offers; the check is only as current as the context you pass it.

## What a document cannot do with it

- No `default`: a question that reads its options from context takes none, and
  one that writes one is `document.invalid_default`, because it has no option
  at admit for a default to name.
- No selection bounds against the number of options: there are none at admit,
  so `min_selections` and `max_selections` are checked against the response
  only.
- A `prefill` still works, and is shown where its value is among the options the
  context holds.

## See also

- `Riddler.Screens.Type.ChoiceQuestion` for the field and its findings.
- `Riddler.Screens` for what resolution does with the options and what a
  response has to satisfy.
- [Ask a choice question](ask-a-choice-question.md) for the option shape and the
  checks on a response.
