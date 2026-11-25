# Present a Journey: a screen, waiting or done

This page shows how to ask Riddler what a visitor should see at one step of
a Journey, and how to send it the host's context as the Journey goes on. It
uses patron registration: a visitor gets a library card, and the Journey is
that one visitor's execution through the screens.

It assumes you already have a document that admits and validates; if not,
start from the basic usage in the README.

## What a host passes

A host's execution is, at any moment, in one of three places for the
visitor. You map it onto one of three values and pass it as the status. Each
has a bare form and a form that carries a map:

- `{:screen, key}`, or `{:screen, key, opts}` - the visitor is to be shown
  the screen the document declares under `key`, and `opts` may say that you
  let the visitor go back from it;
- `:waiting`, or `{:waiting, info}` - the execution is waiting on something
  that is not the visitor, and `info` may say why and when a client should
  ask again;
- `:done`, or `{:done, result}` - the execution has finished, and `result` is
  what your host has to show for it.

The maps are string-keyed, like the root. A key a map carries that this page
does not name for it is not read.

`Riddler.Journey.present/3` takes the admitted document, that status, and
the root, the same map every `Riddler.Screens` function takes. The root
holds `"context"`, what your host knows, and `"responses"`, what the visitor
has submitted so far. A half the root does not carry is read as an empty
map.

The examples below use one screen of patron registration:

```elixir
document =
  Riddler.Screens.Document.admit(%{
    "schema_version" => 1,
    "id" => "patron_registration",
    "screens" => [
      %{
        "key" => "patron_details",
        "title" => "Get your library card",
        "nodes" => [
          %{
            "type" => "text",
            "key" => "welcome_back",
            "condition" => "context.returning == 'yes'",
            "text" => "Welcome back, {{ context.first_name }}."
          },
          %{
            "type" => "button",
            "key" => "details_next",
            "label" => "Continue",
            "outcome" => "details_submitted"
          }
        ]
      }
    ]
  })

root = %{"context" => %{"returning" => "yes", "first_name" => "Ada"}}
```

## The three answers

Each of the three answers comes back as `{:ok, answer}`, where the answer is
a map with string keys only, so you can put it on a wire as JSON as it stands. Its `"state"`
is `"screen"`, `"waiting"` or `"done"`, and a client switches on it.

### A screen

```elixir
Riddler.Journey.present(document, {:screen, "patron_details"}, root)
#=> {:ok,
#    %{
#      "state" => "screen",
#      "screen" => %{
#        "key" => "patron_details",
#        "title" => "Get your library card",
#        "elements" => [
#          %{"type" => "text", "key" => "welcome_back", "text" => "Welcome back, Ada."},
#          %{"type" => "button", "key" => "details_next", "label" => "Continue",
#            "outcome" => "details_submitted"}
#        ],
#        "diagnostics" => %{"missing_variables" => [], "undecidable_conditions" => []}
#      },
#      "moves" => %{"outcomes" => ["details_submitted"], "back" => false}
#    }}
```

`"screen"` is the screen `Riddler.Screens.resolve_screen/3` resolves for that
key and root, as data: nodes a condition hid are absent, every template is
rendered, and no `condition` is left on any node.

`"diagnostics"` comes inside the screen and lists the variables the root did
not carry (`"missing_variables"`) and the conditions that could not be
decided against it (`"undecidable_conditions"`), so you are never handed a
screen without the report of resolving it.

`"moves"` comes beside the screen, at the root of the answer, on every screen
answer. It says what a client may submit from this screen, so a client reads
it and never works it out from the nodes:

- `"outcomes"` lists the `outcome` of each button the screen shows, in
  document order. A button a condition hid is not listed, and a screen that
  shows no button lists `[]`. An outcome is listed once: no two buttons a
  screen can show together raise the same outcome in a document that
  validates, so an outcome names one move.
- `"back"` is `true` when you passed `{:screen, key, opts}` with `"back"` true
  in `opts`, and `false` otherwise.

### Let the visitor go back

Pass the third form to say the visitor may go back from this screen:

```elixir
Riddler.Journey.present(document, {:screen, "patron_details", %{"back" => true}}, root)
#=> {:ok, %{"state" => "screen", "screen" => ..., "moves" =>
#     %{"outcomes" => ["details_submitted"], "back" => true}}}
```

`{:screen, key, %{}}` answers exactly what `{:screen, key}` answers. `"back"`
is a flag for a client to read: Riddler does not take the visitor back, and
defines no submit for it. How a client asks to go back, and what your
execution does then, are yours.

### Waiting

```elixir
Riddler.Journey.present(document, :waiting, root)
#=> {:ok, %{"state" => "waiting"}}
```

The bare form answers the state alone, and the document is not read. To tell
the client why the execution waits, and when to ask again, pass the form that
carries a map:

```elixir
Riddler.Journey.present(
  document,
  {:waiting, %{"reason" => "card_number_pending", "retry_after_ms" => 5000}},
  root
)
#=> {:ok,
#    %{"state" => "waiting", "reason" => "card_number_pending", "retry_after_ms" => 5000}}
```

- `"reason"` is a string, and its words are yours: Riddler passes it on and
  reads nothing in it.
- `"retry_after_ms"` is a non-negative integer, the milliseconds you suggest a
  client waits before it asks again.

Each appears in the answer only where you supplied it, and `{:waiting, %{}}`
answers exactly what `:waiting` answers.

### Done

```elixir
Riddler.Journey.present(document, :done, root)
#=> {:ok, %{"state" => "done"}}
```

The bare form answers the state alone. To hand the client what the execution
produced, pass a result:

```elixir
Riddler.Journey.present(document, {:done, %{"card_number" => "EXAMPLE-CARD-0001"}}, root)
#=> {:ok, %{"state" => "done", "result" => %{"card_number" => "EXAMPLE-CARD-0001"}}}
```

The result is your map, carried onto the answer whole and never read. It goes
into the answer in its data form, so a struct inside it becomes a map, an atom
key a string, and an atom value other than `true`, `false` and `nil` a string.
That it holds only what JSON can carry is yours to keep, as it is for the
context. `{:done, %{}}` answers `"result"` as an empty map.

Do not put a secret in a result: it goes to the client as written.

## What a presented question carries

A question node in a presented screen is the question as resolved, with a few
fields a client reads. This document has one text question:

```elixir
document =
  Riddler.Screens.Document.admit(%{
    "schema_version" => 1,
    "id" => "patron_registration",
    "screens" => [
      %{
        "key" => "patron_details",
        "title" => "Get your library card",
        "nodes" => [
          %{
            "type" => "text_question",
            "key" => "reminder_email",
            "label" => "Email for due-date reminders",
            "help" => "We write to {{ context.first_name }} only about due dates.",
            "format" => "email",
            "required" => true,
            "prefill" => "context.patron.email",
            "messages" => %{"response.format" => "Check the address, it looks incomplete."}
          },
          %{
            "type" => "button",
            "key" => "details_next",
            "label" => "Continue",
            "outcome" => "details_submitted"
          }
        ]
      }
    ]
  })

root = %{"context" => %{"first_name" => "Ada", "patron" => %{"email" => "ada@example.com"}}}

{:ok, %{"screen" => screen}} =
  Riddler.Journey.present(document, {:screen, "patron_details"}, root)

hd(screen["elements"])
#=> %{
#     "type" => "text_question",
#     "key" => "reminder_email",
#     "label" => "Email for due-date reminders",
#     "help" => "We write to Ada only about due dates.",
#     "format" => "email",
#     "required" => true,
#     "messages" => %{"response.format" => "Check the address, it looks incomplete."},
#     "value" => "ada@example.com"
#   }
```

- `"value"` is what the field shows when it is drawn. It is the response the
  root already holds for the question, as written, so a screen shown again
  after a refused submit shows what the visitor sent. Else it is what the
  `prefill` path reads from `"context"`. Else the question's `default`. A
  question none of them yields a value for carries no `"value"`. The node
  carries neither `prefill` nor `default`. `"value"` is for drawing only:
  validation reads the responses in the root and never a `"value"`, so a
  required question that shows a prefill the visitor did not send back is
  still unanswered.
- `"help"` is the question's guidance line, rendered like the label.
- `"messages"` is the author's text for each finding code the question keys,
  carried as written. A client does not look a message up there: the finding
  carries it, as the next section shows.

A secret question carries `"held"` and never a `"value"`; see
[Seal and unseal a secret answer](seal-a-secret-answer.md).

### Show the author's message beside a finding

When `Riddler.Screens.validate_screen/3,4` refuses a response and the
question's `messages` keys the finding's code, the finding carries that text
as `author_message`, and its `message` stays the package's own sentence:

```elixir
root = Map.put(root, "responses", %{"reminder_email" => "ada"})

{:error, [finding]} =
  Riddler.Screens.validate_screen(document, "patron_details", root, "details_submitted")

{finding.code, finding.author_message, finding.message}
#=> {"response.format", "Check the address, it looks incomplete.",
#    "\"ada\" is not an email address"}
```

Show `author_message` where it is a string, and your own text where it is
`nil`. A client switches on `code`, which does not change when wording does.

## Handle a refusal

Two refusals come back as `{:error, reason}`, so a host that builds its
status from its own data is told rather than handed an exception:

```elixir
Riddler.Journey.present(document, {:screen, "card_pickup"}, root)
#=> {:error, :no_such_screen}

Riddler.Journey.present(document, :card_issued, root)
#=> {:error, :unknown_status}
```

`:no_such_screen` means the document declares no screen under that key.
`:unknown_status` means the status is none of the three, or is one of the
forms that carries a map and the map is wrong: not a map (a struct included),
a `"back"` that is not a boolean, a `"reason"` that is not a string, or a
`"retry_after_ms"` that is not an integer or is below zero. A result that is
not a map is refused the same way.

## Send the context as the Journey goes on

Between steps your host learns things: a card number is issued, a returning
visitor is recognised, a flag is withdrawn. Send the context complete each
time, with `Riddler.Journey.put_context/2`:

```elixir
root = %{
  "context" => %{"returning" => "yes", "first_name" => "Ada", "card_pending" => true},
  "responses" => %{"reminder_email" => "ada@example.com"}
}

context = %{"returning" => "yes", "first_name" => "Ada", "card_number" => "2915 0001 2345"}

Riddler.Journey.put_context(root, context)
#=> {:ok,
#    %{
#      "context" => %{
#        "returning" => "yes",
#        "first_name" => "Ada",
#        "card_number" => "2915 0001 2345"
#      },
#      "responses" => %{"reminder_email" => "ada@example.com"}
#    }}
```

The context is replaced, not merged:

- A key the old context held and the new one leaves out is gone. That is how
  a host withdraws a flag: `"card_pending"` is not in the result above.
- Because of that, a host that keeps its context in pieces assembles it
  before the call; a piece left out is a key removed.
- `"responses"`, and every other key of the root, are left exactly as they
  were.

A context that is not a map, or is a struct, is refused:

```elixir
Riddler.Journey.put_context(root, ["first_name", "Ada"])
#=> {:error, :context_not_a_map}
```

Pass the root `put_context/2` returns to the next `present/3` call.

## Check the responses before you move on

`present/3` checks no responses. Whether what the visitor submitted is enough
to leave a screen is `Riddler.Screens.validate_screen/3,4`'s, which you call
before you move your execution on. What arrives from a client, and the order of
those checks, is [Post a submit](post-a-submit.md).

## What stays yours

`Riddler.Journey` is two pure functions. It stores nothing, starts no process,
keeps no state between calls and reads no execution; there is no behaviour to
implement and nothing it calls back. These are not Riddler's to decide, and they stay with your host:

- **Storage.** Where the root, the responses, the status and the answers are
  kept is yours.
- **The stepper.** Which status comes next - which screen follows a submit,
  when waiting ends, when the execution is done - is decided by your
  workflow engine. `present/3` answers the status it is given.
- **The transport.** How an answer reaches a client, and how a submit comes
  back, is not decided by Riddler.
- **Identity.** Which visitor, which execution, and how a client names the
  Journey it is resuming are not decided by Riddler.

## See also

- `Riddler.Journey` for the two functions and their types.
- `Riddler.Screens.resolve_screen/3` for the screen inside a `"screen"`
  answer.
- `Riddler.Screens.validate_screen/4` for the check on a submit.
- [Post a submit](post-a-submit.md) for what a client sends back.
- [Supply options at run time](supply-options-at-run-time.md) for a choice
  question whose options come from your context.
