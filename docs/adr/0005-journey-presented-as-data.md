# ADR-0005: A Journey is presented as data - a screen, waiting or done - and a host's context is replaced whole

Status: proposed

Recorded 2026-10-20, bead rd-4jb. The status a host passes as data and the
string-keyed answer `present/3` gives were ruled by the operator,
2026-10-19. The context replaced whole, with the responses untouched, was
ruled by the operator, 2026-10-19. The third argument of `present/3` being
the root every `Riddler.Screens` function takes was ruled by the operator,
2026-10-20. The `{:ok, answer}` wrapping, the two refusals' spellings and
the corpus capability ids were ruled by the operator, 2026-10-20. Where a
screen's diagnostics sit in the answer and the name `put_context/2` were
decided by the conductor under a standing consent, 2026-10-20.

This record is written before any code it describes. Every cite of `lib/`
below was read at `01c2261`.

## Context

**A Journey is one visitor's execution through a set of screens.** The
execution belongs to a workflow engine on the host's side: it waits for the
visitor, waits for a back office, and moves from one screen to the next
over minutes or days. What this package already does is the content half
of each step. `Riddler.Screens.resolve_screen/3` (`lib/riddler/screens.ex`
at `01c2261`) answers one named screen of an admitted document against a
root, with the diagnostics its resolution produced, or
`{:error, :no_such_screen}` when the document declares no screen under that
key. ADR-0002's amendment "the screen validated is the screen shown", under
"A single-screen call returns its diagnostics", is why the diagnostics come
back beside the screen.

**What is missing is the step's answer as a whole.** At any moment a host's
execution is in one of three places for the visitor: showing a screen,
waiting on something that is not the visitor, or finished. Without an
envelope stated here, a host that carries a Journey to a client invents its
own for those three, and two hosts invent two. A client that renders a
Journey - a browser page, a native app - then has to know which host it is
talking to. The three places are few and fixed, and a screen is already
this package's to resolve, so the envelope is this package's to state.

**What a Journey carries between steps.** The root every `Riddler.Screens`
function reads has two halves (`Riddler.Screens` moduledoc, "The root", at
`01c2261`): `"context"`, what the host knows, and `"responses"`, what the
visitor has submitted so far. Over a Journey the host's half changes: a
library card number is issued, a returning visitor is recognized, a flag is
withdrawn. The host sends its context complete at each step, so the
question is what happens to the context the root already held.

**What must not move.** ADR-0001 leaves transport, authentication,
streaming, the identity and durability of a visitor's execution, and the
editor open ("Nothing here decides transport, ..." in its Consequences),
and ADR-0002's Consequences leave them open in the same words. The
explanation page "What Riddler is for", under "What it leaves to the host",
says storage and what happens next are the host's, and that Riddler never
calls back into a workflow engine. This record keeps every one of those
where it is.

## Decision

### 1. A new module, `Riddler.Journey`, of pure functions

`Riddler.Journey` is a module of this one package, beside `Riddler.Screens`
and `Riddler.Template`. It holds two functions, `present/3` and
`put_context/2`. Both are pure: they consult no store, start no process,
keep no state between calls, and read no execution. There is no behaviour
for a host to implement and no callback this package calls; a host calls
these functions and uses what they give back.

### 2. The host passes its status as data

The host decides where its execution is and says so with one of three
values:

- `{:screen, key}` - the visitor is to be shown the screen the document
  declares under `key`;
- `:waiting` - the execution is waiting on something that is not the
  visitor;
- `:done` - the execution has finished.

Mapping its execution onto one of the three is the host's. Riddler never
reads an execution to find out.

### 3. `present/3` answers a string-keyed map

`Riddler.Journey.present(document, status, root)` takes an admitted
document, the status and the root, in the order `resolve_screen/3` takes
the document, a screen key and the root. The root is the same map every
`Riddler.Screens` function takes, read for `"context"` and `"responses"`
and nothing else; an absent half is an empty map, as it is there.

| Status | Answer |
|---|---|
| `{:screen, key}`, a key the document declares | `{:ok, %{"state" => "screen", "screen" => screen}}` |
| `{:screen, key}`, a key the document does not declare | `{:error, :no_such_screen}` |
| `:waiting` | `{:ok, %{"state" => "waiting"}}` |
| `:done` | `{:ok, %{"state" => "done"}}` |
| anything else | `{:error, :unknown_status}` |

`"state"` is exactly one of `"screen"`, `"waiting"` and `"done"`, and
`"screen"` is a key of the answer exactly when `"state"` is `"screen"`. The
answer for waiting and the answer for done carry nothing else: no reason,
no retry hint, no outcome. For those two the document is not read.

**The answer is wrapped**, ruled by the operator, 2026-10-20. The
package's convention for a function that can fail is
`{:ok, value} | {:error, reason}` (`CLAUDE.md`, "Conventions", the first
bullet), and `present/3` can be handed a key the document does not
declare. `resolve_screen/3` answers that case `{:error, :no_such_screen}`,
and `present/3` answers it with the same tuple rather than a second
spelling of the same mistake. The string-keyed map is the value inside
`{:ok, ...}`.

**A status outside the three is refused**, ruled by the operator,
2026-10-20: `present/3` answers `{:error, :unknown_status}`, an atom beside
`:no_such_screen`, so a host that builds its status from its own data is
told rather than handed an exception.

**The screen is data, and its diagnostics come with it.** `"screen"` holds
what `resolve_screen/3` answers for that key and root, in its data form:
`"key"`, `"title"` and `"nodes"` as resolution leaves them - hidden nodes
absent, each container collapsed to its winner, every template field
rendered, no `condition` anywhere, `writes` carried through - and
`"diagnostics"`, with `"missing_variables"` and `"undecidable_conditions"`
in document order. The encoding rules are the corpus runner's
(`Riddler.Corpus`, "the one encoder", at `01c2261`): structs become maps,
atom keys become strings, and an atom value other than `true`, `false` and
`nil` becomes a string. So an answer can be put on any wire as JSON and
stated byte for byte by a corpus case. A screen carrying its
`"diagnostics"` is new to the `journey.present` cases: the runner's
existing single-screen path for `screens.resolve` encodes the screen alone
and drops the diagnostics (`Riddler.Corpus`, the `{:ok, screen,
_diagnostics}` clause of its `screens.resolve` run, at `01c2261`). The
diagnostics ride inside `"screen"` rather than beside it so that the
answer's own keys are exactly `"state"` and `"screen"`, and so that a
caller is still never handed a screen without the report of resolving it.

`present/3` checks no responses. Whether what the visitor typed is enough
to submit a screen stays `Riddler.Screens.validate_screen/3,4`'s, called by
the host before it moves its execution on.

### 4. `put_context/2` replaces the context whole

`Riddler.Journey.put_context(root, context)` answers `{:ok, root}` with the
root's `"context"` replaced by `context`, whole. Nothing is merged: a key
the previous context held and the new one does not is gone. `"responses"`
and every other key of the root are left exactly as they were. A root with
no `"context"` gets one.

The host sends its context complete on every submit, and a replace is what
makes a key the host withdrew disappear; a merge would keep a withdrawn
flag true for the rest of the Journey.

**A context that is not a map is refused**, ruled by the operator,
2026-10-20: `put_context/2` answers `{:error, :context_not_a_map}`. A
struct is refused the same way: `Riddler.Screens` reads a context that is
not a plain map as an empty one (`submap/2` in `lib/riddler/screens.ex` at
`01c2261`), so putting one would answer a root that every later call reads
as carrying no context at all.

Both functions take a root that is a map, as every `Riddler.Screens`
function does; a root that is not a map is outside their function clauses,
as it is there.

### 5. The corpus capabilities

Ruled by the operator, 2026-10-20: the two functions are held to the
corpus as `journey.present` and `journey.put_context`, one case file each,
`corpus/journey/present.json` and `corpus/journey/put_context.json`. Each
expected answer is in the data form of section 3, and each error is stated
as `{"error": reason}` - `{"error": "no_such_screen"}`,
`{"error": "unknown_status"}`, `{"error": "context_not_a_map"}` - the way
`screens.resolve` already states `no_such_screen`.

### 6. What this package does not own

- **Storage.** Nothing here stores a root, a response, a status or an
  answer. The host keeps them wherever it keeps its executions.
- **The stepper.** Which status comes next - which screen follows a
  submit, when waiting ends, when the execution is done - is the host's
  workflow engine's to decide. `present/3` answers the status it is given.
- **The transport.** How an answer reaches a client, and how a submit
  comes back, is not decided here.
- **Identity.** Which visitor, which execution, and how a client names the
  Journey it is resuming are not decided here.

The transport and identity stay open as ADR-0001 left them, and a commit
that assumes an answer to either is out of scope until a record closes it.
Storage and what happens next stay the host's, as the explanation page
says under "What it leaves to the host".

## Consequences

- A client renders a Journey from one envelope whatever host it talks to:
  it switches on `"state"` and, for a screen, renders `"screen"`.
- A runtime in another language implements the same two functions and is
  held to them by the `journey.present` and `journey.put_context` cases.
- The answer for a screen costs one resolution of one screen, the same work
  `resolve_screen/3` does; waiting and done cost nothing.
- Nothing that exists changes. `Riddler.Screens` and `Riddler.Template`
  keep every answer they give; `Riddler.Journey` is added beside them.
- A host that needs a reason or a retry hint for waiting, or an outcome for
  done, carries it in its own envelope beside the answer; adding one to the
  answer is a new decision for a later record.
- A host that keeps its context in pieces has to assemble it before
  `put_context/2`, because a piece left out is a key removed.

## Typespecs

Minimal, and a contract for the code half rather than a second source of
truth. Elixir's typespecs cannot name a literal string key, so the keys are
in the comments.

```elixir
@typedoc "Where the host's execution is for the visitor."
@type status :: {:screen, screen_key :: term()} | :waiting | :done

@typedoc """
The root every Riddler.Screens function takes: "context" and "responses",
each a string-keyed map. Other keys are carried and never read.
"""
@type root :: map()

@typedoc """
"state" => "screen" | "waiting" | "done", and, only when "state" is
"screen", "screen" => screen().
"""
@type answer :: %{required(String.t()) => String.t() | screen()}

@typedoc """
"key", "title", "nodes" (the resolved nodes, string-keyed) and
"diagnostics" => %{"missing_variables" => [...],
"undecidable_conditions" => [...]}.
"""
@type screen :: %{required(String.t()) => term()}

@spec present(Riddler.Screens.Document.t(), term(), root()) ::
        {:ok, answer()}
        | {:error, :no_such_screen}
        | {:error, :unknown_status}

@spec put_context(root(), term()) ::
        {:ok, root()} | {:error, :context_not_a_map}
```

`present/3`'s status argument and `put_context/2`'s context argument are
typed `term()` because a value outside `status()` and a context that is not
a map are answered with a refusal rather than left outside the function.

## Worked examples

Patron registration: a visitor gets a library card. The document is the
one the README's basic usage admits, one screen, `patron_details`:

```elixir
document =
  Riddler.Screens.Document.admit(%{
    "schema_version" => 1,
    "id" => "patron_registration",
    "screens" => [
      %{"key" => "patron_details", "title" => "Get your library card",
        "nodes" => [
          %{"type" => "text", "key" => "welcome_back",
            "condition" => "context.returning == 'yes'",
            "text" => "Welcome back, {{ context.first_name }}."},
          %{"type" => "text_question", "key" => "reminder_email",
            "label" => "Email for due-date reminders",
            "required" => true, "format" => "email"},
          %{"type" => "button", "key" => "details_next",
            "label" => "Continue", "outcome" => "details_submitted"}
        ]}
    ]
  })
```

**A screen.** The host's execution is at the details screen, for a
returning visitor:

```elixir
root = %{"context" => %{"returning" => "yes", "first_name" => "Ada"}}

Riddler.Journey.present(document, {:screen, "patron_details"}, root)
#=> {:ok,
#    %{
#      "state" => "screen",
#      "screen" => %{
#        "key" => "patron_details",
#        "title" => "Get your library card",
#        "nodes" => [
#          %{"type" => "text", "key" => "welcome_back",
#            "text" => "Welcome back, Ada."},
#          %{"type" => "text_question", "key" => "reminder_email",
#            "label" => "Email for due-date reminders",
#            "required" => true, "format" => "email"},
#          %{"type" => "button", "key" => "details_next",
#            "label" => "Continue", "outcome" => "details_submitted"}
#        ],
#        "diagnostics" => %{
#          "missing_variables" => [],
#          "undecidable_conditions" => []
#        }
#      }
#    }}
```

**Waiting.** The visitor has submitted the details screen and the host's
execution is waiting while the library issues a card number:

```elixir
Riddler.Journey.present(document, :waiting, root)
#=> {:ok, %{"state" => "waiting"}}
```

**The context replaced.** The card number is issued and the host sends its
context complete. The card is no longer pending, so the new context leaves
`"card_pending"` out, and it is gone from the root; the responses are
untouched:

```elixir
root = %{
  "context" => %{
    "returning" => "yes",
    "first_name" => "Ada",
    "card_pending" => true
  },
  "responses" => %{"reminder_email" => "ada@example.com"}
}

context = %{
  "returning" => "yes",
  "first_name" => "Ada",
  "card_number" => "2915 0001 2345"
}

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

**Done.** The execution has finished:

```elixir
Riddler.Journey.present(document, :done, root)
#=> {:ok, %{"state" => "done"}}
```

**The refusals.** A screen the document does not declare, a status outside
the three, and a context that is not a map:

```elixir
Riddler.Journey.present(document, {:screen, "card_pickup"}, root)
#=> {:error, :no_such_screen}

Riddler.Journey.present(document, :card_issued, root)
#=> {:error, :unknown_status}

Riddler.Journey.put_context(root, ["first_name", "Ada"])
#=> {:error, :context_not_a_map}
```
