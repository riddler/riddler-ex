# Present a Journey: a screen, waiting or done

This page shows how to ask Riddler what a visitor should see at one step of
a Journey, and how to send it the host's context as the Journey goes on. It
uses patron registration: a visitor gets a library card, and the Journey is
that one visitor's execution through the screens.

It assumes you already have a document that admits and validates; if not,
start from the basic usage in the README.

## What a host passes

A host's execution is, at any moment, in one of three places for the
visitor. You map it onto one of three values and pass it as the status:

- `{:screen, key}` - the visitor is to be shown the screen the document
  declares under `key`;
- `:waiting` - the execution is waiting on something that is not the
  visitor;
- `:done` - the execution has finished.

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
#        "nodes" => [
#          %{"type" => "text", "key" => "welcome_back", "text" => "Welcome back, Ada."},
#          %{"type" => "button", "key" => "details_next", "label" => "Continue",
#            "outcome" => "details_submitted"}
#        ],
#        "diagnostics" => %{"missing_variables" => [], "undecidable_conditions" => []}
#      }
#    }}
```

`"screen"` is the screen `Riddler.Screens.resolve_screen/3` resolves for that
key and root, as data: nodes a condition hid are absent, every template is
rendered, and no `condition` is left on any node.

`"diagnostics"` comes inside the screen and lists the variables the root did
not carry (`"missing_variables"`) and the conditions that could not be
decided against it (`"undecidable_conditions"`), so you are never handed a
screen without the report of resolving it.

### Waiting

```elixir
Riddler.Journey.present(document, :waiting, root)
#=> {:ok, %{"state" => "waiting"}}
```

The answer is the state alone: no reason, no retry hint. The document is not
read. If your host wants to say why, put that in an envelope of your own beside
the answer.

### Done

```elixir
Riddler.Journey.present(document, :done, root)
#=> {:ok, %{"state" => "done"}}
```

Like waiting, the answer is the state alone, and carries no outcome.

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
`:unknown_status` means the status is none of the three.

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
before you move your execution on.

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
