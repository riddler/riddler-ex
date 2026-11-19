# ADR-0005: A Journey is presented as data - a screen, waiting or done - and a host's context is replaced whole

Status: accepted (2026-10-20, riddler 0.4.0)

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

---

Noted 2026-10-20, bead rd-qs0. Two notes by addition, recorded with the
code half that makes them true, in one request. Nothing above is changed;
each paragraph says how a passage above is carried out.

**How a case states the status.** Section 5 names the capabilities, their
files and their answers; a case also has to state its input, and JSON has
no tuple and no atom. A `journey.present` case gives `document`, `root` and
`status`: `"waiting"` and `"done"` are the two bare statuses, `"screen"` is
`{:screen, key}` with the key under the input's own `"screen"`, the way a
`screens.resolve` case names its one screen, and any other value is handed
to `present/3` as itself, which is a status outside the three. A
`journey.put_context` case gives `root` and `context`, and the context may
be any JSON value. The corpus case schema's input description says the
same (`priv/schemas/corpus-case.schema.json`).

**One encoder, not two.** Section 3 says the screen's data form follows
the corpus runner's encoding rules. Those rules now sit in one internal
module, `Riddler.Encoding`, called by both the runner and
`Riddler.Journey`, so the form a `journey.present` case states and the form
`present/3` gives cannot drift apart. A `journey.present` answer is compared
as the function gives it, without passing through the encoder a second
time, so a key left an atom by `present/3` is a failing case.

---

Noted 2026-10-20. This record moves from `proposed` to `accepted`, its
Status line flipped in place and nothing else in it reworded; its row in
`docs/adr/README.md` reads accepted. The flip was decided by the conductor
under a standing consent, 2026-10-20.

It shipped in riddler 0.4.0, the commit tagged `v0.4.0` (`c4349b3`) and
published on Hex; its code half is `e17ed27`, and the 0.4.0 changelog's
`Added` section states both functions and both corpus capabilities. The
record says it "is written before any code it describes"; that code is now
`lib/riddler/journey.ex`. It was re-verified at the tag, every cite
re-located by anchor there; `main` is that commit. What was read:

- Decision 1: `Riddler.Journey` defines `present/3` and `put_context/2` and
  no other public function, and neither reads a store, starts a process or
  reads an execution.
- Decisions 2 and 3: `present/3` resolves `{:screen, key}` through
  `Riddler.Screens.resolve_screen/3`, passing its `{:error, :no_such_screen}`
  through; it answers `:waiting` and `:done` with the state alone, from
  clauses that do not read the document; and it answers any other status
  `{:error, :unknown_status}`. The screen is put in data form by
  `Riddler.Encoding.to_data/1`, with its diagnostics inside it.
- Decision 4: `put_context/2` puts the new `"context"` over the old one
  whole and refuses a context that is not a map, or is a struct,
  `{:error, :context_not_a_map}`; the private `submap/2` in
  `lib/riddler/screens.ex` still reads a context that is not a plain map as
  an empty one.
- Decision 5: `corpus/journey/present.json` and
  `corpus/journey/put_context.json` hold the cases, and
  `priv/schemas/corpus-case.schema.json` lists `journey.present` and
  `journey.put_context` among its capabilities.
- The typespecs in `lib/riddler/journey.ex` are the record's.
- The Context's cites stand: `resolve_screen/3`, "The root" in the
  `Riddler.Screens` moduledoc, "Nothing here decides transport, ..." in the
  Consequences of ADR-0001 and of ADR-0002, the explanation page "What
  Riddler is for" under "What it leaves to the host", and the first bullet of
  "Conventions" in `CLAUDE.md`.
- Every worked example was run at `c4349b3` and answers as written; its
  document is the one the README's basic usage admits.

**The encoder section 3 cites.** Section 3 cites the encoding rules as
`Riddler.Corpus`, "the one encoder", at `01c2261`. The note above of
2026-10-20, in its paragraph led "One encoder, not two.", records that the
rules now sit in `Riddler.Encoding`, called by the runner and by
`Riddler.Journey` alike; `Riddler.Corpus` keeps its section "the one
encoder", which hands each value to `Riddler.Encoding`, and its
`screens.resolve` run still encodes a single screen without its diagnostics
in its `{:ok, screen, _diagnostics}` clause. The rules are unchanged; this
note decides nothing.

---

## Amendment, 2026-11-18: the presented answer, the submit and a finding as a published wire contract

Status: accepted (2026-11-19, riddler 0.5.0)

Recorded 2026-11-18, bead rd-xikc. The status shapes a host passes - the
bare `{:screen, key}`, `:waiting` and `:done` unchanged, and beside them
`{:screen, key, opts}`, `{:waiting, info}` and `{:done, result}` - were
ruled by the operator, 2026-11-16, and so were the answer's new keys: a
`"moves"` on every screen answer, `"back"` false in it unless the host said
true, and `"reason"`, `"retry_after_ms"` and `"result"` only when the host
supplied them. That a question node in a presented screen may carry a
`"value"` was ruled by the operator, 2026-11-16. The submit's three keys,
a pure decoder for it in `Riddler.Journey` answering findings with
`submit.*` codes, and that comparing the submitted screen with the host's
own position is the host's check were decided by the conductor under a
standing consent, 2026-11-16. So were the schemas' draft, that they are
versioned with the package, that they enumerate the node types, and that
the fallback for an unknown node type is recorded here as the contract a
client is built to while how a client builds it stays open. The rest - the
refusals of a malformed status, the finding codes, what the decoder keeps
and drops, the finding's wire form, the schema file names, which node types
the enumeration lists, how a schema treats a key or a type it does not
name, and the corpus capability - is this entry's own, written 2026-11-18
at `proposed`.

Every cite below of the package as it stands is read at `b16dec4`. The
code half is separate requests (beads rd-k9t4 for the presented answer's
schema; rd-hzse for the submit's and the finding's schemas and the
decoder; rd-na05 for the waiting status; rd-7xg9 for the done status;
rd-82tm for the moves; rd-f2pr for the corpus and the export). Nothing
below is citable from `lib/` or `priv/` until they land, so what they add
is described here, not cited.

### What the record now decides

**The status gains three shapes beside the three it had.** Decision 2's
three values stand, and each gains a form that carries a map:

| Status | What the map may carry |
|---|---|
| `{:screen, key}` | - (unchanged) |
| `{:screen, key, opts}` | `"back"`, a boolean |
| `:waiting` | - (unchanged) |
| `{:waiting, info}` | `"reason"`, a string; `"retry_after_ms"`, a non-negative integer |
| `:done` | - (unchanged) |
| `{:done, result}` | the map is the result itself, any map JSON can carry |

The maps are string-keyed, as the root is. A key the map carries that the
table does not name for it is not read, and nothing of it reaches the
answer. A status that has one of these shapes but whose map is not a map,
or carries a named key of the wrong type - a `"back"` that is not a boolean,
a `"reason"` that is not a string, a `"retry_after_ms"` that is not an
integer or is below zero - is a status outside the shapes, and Decision 3's
table answers it on its row "anything else", `{:error, :unknown_status}`.
`{:screen, key, opts}` with a key the document does not declare is
`{:error, :no_such_screen}`, as `{:screen, key}` is.

`result` is the host's: it is carried onto the answer whole, in the data
form of Decision 3 (`Riddler.Encoding`, the one encoder, at `b16dec4`), and
nothing in it is read. That it holds only what JSON can carry once that
encoding has run is the host's to keep, as the context's is; `present/3`
checks that it is a map and nothing more. A struct is not a map here, as
it is not for `put_context/2` (Decision 4).

**The answer gains keys, each in one place.** Decision 3 says that the
answer's own keys are exactly `"state"` and `"screen"`, and that the
answer for waiting and the answer for done carry nothing else. This entry
answers those calls another way:

| Status | Answer |
|---|---|
| `{:screen, key}` or `{:screen, key, opts}`, a declared key | `{:ok, %{"state" => "screen", "screen" => screen, "moves" => moves}}` |
| `:waiting` | `{:ok, %{"state" => "waiting"}}`, unchanged |
| `{:waiting, info}` | `{:ok, %{"state" => "waiting"}}`, with `"reason"` and `"retry_after_ms"` beside `"state"` each only where `info` carries it |
| `:done` | `{:ok, %{"state" => "done"}}`, unchanged |
| `{:done, result}` | `{:ok, %{"state" => "done", "result" => result}}` |

`"moves"` sits at the answer root, beside `"screen"` and not inside it, and
every screen answer carries it, from either screen shape:

```json
{"outcomes": ["details_submitted"], "back": false}
```

`"outcomes"` is the `outcome` of each button among the presented screen's
`"nodes"`, in document order. A button is among them exactly when it is
shown: a button a condition hid is absent, and a container is replaced by
its winner, so a button inside a container is listed when its candidate won
and not otherwise (the `Riddler.Screens` moduledoc, "What resolution does
to a node", at `b16dec4`). A screen with no shown button lists `[]`.
`"back"` is `true` exactly when the host passed `{:screen, key, opts}` with
`"back"` true, and `false` otherwise. A client reads what it may submit
from `"moves"` and never derives it from the nodes.

`{:waiting, %{}}` answers exactly what `:waiting` answers, and
`{:screen, key, %{}}` exactly what `{:screen, key}` answers. `"result"` is
on a done answer only when the host passed `{:done, result}`; an empty map
passed so is carried as `{}`. `"screen"` is a key of the answer exactly
when `"state"` is `"screen"`, and `"moves"` too; `"reason"` and
`"retry_after_ms"` appear only on a waiting answer and `"result"` only on a
done one. For waiting and done the document is still not read.

**A question node may carry a `"value"`.** What a question node presents
of a response the root holds, a prefill or a default, and in what order,
is a later entry's on ADR-0002 to decide. This entry decides only that the
presented answer's schema below admits an optional `"value"` on a question
node of every enumerated question type but `secret_question`, and that a
`secret_question` node carries `"held"` and never `"value"`, as ADR-0002's
amendment, at `proposed`, headed "Amendment, 2026-11-16: a `secret_question` node type,
validated on plaintext and sealed by the host before it is stored" decides
under "A presented secret question carries `held` and never a value".

**A submit is a JSON object of three keys.** What a client sends back when
the visitor presses a button is:

```json
{"screen": "patron_details", "outcome": "details_submitted", "responses": {"reminder_email": "ada@example.com"}}
```

`"screen"` is the key of the screen the client was shown, a string;
`"outcome"` is the outcome of the button pressed, a string; `"responses"`
is what the visitor entered on that screen, an object keyed by question
key. All three are required; a screen with no question sends
`"responses": {}`.

**`Riddler.Journey.decode_submit/1` checks a submit's shape and nothing
else.** It takes the submit as decoded data - a host decodes the bytes it
received, and how they arrive is the transport's - and answers
`{:ok, submit}` or `{:error, findings}`. It is pure, as Decision 1 says of
the module's other two functions, it reads no document, and it never
raises on a value a client can send:

| The input | Finding |
|---|---|
| not a map, or a struct | `submit.not_an_object`, `field` nil |
| a map without `"screen"`, `"outcome"` or `"responses"` | `submit.missing_field`, its `field` naming the key |
| a map whose `"screen"` or `"outcome"` is not a string, or whose `"responses"` is not a map (a struct included) | `submit.invalid_field`, its `field` naming the key |

A submit that is not an object raises that one finding and nothing else;
otherwise every key is checked and each that fails raises one finding, in
the order `"screen"`, `"outcome"`, `"responses"`, so a client learns every
defect in one pass (the `Riddler.Finding` moduledoc: "Refusals return a
list of findings rather than the first one"). A submit finding's
`node_key` and `position` are nil. `{:ok, submit}` carries the string-keyed
map of exactly the three keys, each value as the client sent it; a key the
client sent beside them is dropped, not carried.

The decoder does not compare `"screen"` with the screen the host's
execution is at, and does not check that `"outcome"` is among the
`"moves"` the host presented: it reads no document and no execution, and
both are the host's checks before it validates the responses
(`Riddler.Screens.validate_screen/3,4`) and moves its execution on.
Decision 1's sentence that there is "no callback this package calls" stays
true: `decode_submit/1` is a third function a host calls, and it calls
nothing back.

The corpus holds `decode_submit/1` to its answers as `journey.decode_submit`,
one case file, `corpus/journey/decode_submit.json`, by Decision 5's
convention; an `{:ok, submit}` case states the submit's data form, and an
error case states its findings as every finding case does.

**A finding's wire form is its struct's data form.** A finding a host
sends a client - a submit refused by `decode_submit/1`, a screen refused by
`validate_screen/3,4` - is a JSON object of the five fields
`Riddler.Finding` defines (`defstruct` in `lib/riddler/finding.ex` at
`b16dec4`), every key present, as the one encoder writes a struct:

| Key | Value |
|---|---|
| `"code"` | a string |
| `"message"` | a string |
| `"field"` | a string, or `null` |
| `"node_key"` | a string, or `null` |
| `"position"` | `null`, or an object `{"line": n, "column": n}` of two integers each at least 1 |

A client switches on `"code"`, which does not change when the wording does
(the `Riddler.Finding` moduledoc, its `:code` bullet). The schema does not
enumerate the codes: `"code"` is a string, so a code a later release adds -
those ADR-0002's amendment of 2026-11-16 names among them - is a finding in
the same form. The unit a `"column"` counts is the one the
moduledoc names under `:position`, by the finding's code. This entry
changes no field and no message: the wire form is the data form the
encoder already gives a `Riddler.Finding`, written down. How a host
carries a list of findings to a client beside or instead of a presented
answer is the transport's. The corpus keeps comparing a finding by
`"code"`, `"field"` and `"node_key"` (`encode_findings/1` in
`lib/riddler/corpus.ex` at `b16dec4`).

**Three JSON Schemas, in `priv/schemas/`, draft-07.** They are:

- `presented-answer.schema.json`: the `{:ok, ...}` value of `present/3`,
  the map Decision 3 and this entry describe, its `"state"` one of the
  three, `"screen"` and `"moves"` required when the state is a screen,
  `"reason"`, `"retry_after_ms"` and `"result"` optional on their states;
- `submit.schema.json`: the submit above, its three keys required and
  typed;
- `finding.schema.json`: one finding in the wire form above.

They name JSON Schema draft 7, as the two schemas already there do and as
the corpus test holds them to (`test/riddler/corpus_test.exs` at
`b16dec4`, its test that both schemas name draft 7, "the highest draft the
validator knows"). None of the three names a file ending
`-document.schema.json`, because `test/packaging_test.exs` holds the
package to exactly one document schema. They ship in the package tarball
because `mix.exs`'s package `files:` names `priv/schemas` whole, and
`mix riddler.corpus` exports them beside the other two once the code half
adds them to the schemas `Riddler.Corpus` copies (its `@schema_files`,
which names the two at `b16dec4`).

**The schemas are versioned with the package.** A schema carries no
version of its own. It changes only in a release of this package, and that
release's changelog names the change. A client built to the schemas is
built to a riddler version, as a runtime in another language is built to
the tag it vendored the corpus from.

**No schema forbids a key it does not name.** An answer, a submit or a
finding that carries a key a later release adds still validates against an
earlier release's schema, so a client built to an earlier schema keeps
working against a later host for every key it already knew. A client that
refuses a key it does not know refuses later answers; that is the client's
choice, and the schema does not make it for it.

**The presented answer's schema enumerates the node types.** It lists, as
an enumeration, the node types a presented screen of that version can
carry: every type the registry names (`@types` in
`lib/riddler/screens/registry.ex` at `b16dec4`: `boolean_question`,
`button`, `choice_question`, `heading`, `text`, `text_question` and
`variant`) except `variant`, which resolution always replaces with its
winner or with nothing, so no presented screen carries one. A type the
registry gains, `secret_question` first, joins the enumeration in the
release whose code presents it. A node whose `type` is in the enumeration
is held to the fields its type names (each type module's `fields/0` under
`lib/riddler/screens/type/` at `b16dec4`) in their resolved form: no
`condition`, every template field a string. A node whose `type` is a string
outside the enumeration is not refused by the schema: the answer that
carries it still validates, so a client can meet it and follow the fallback
below rather than discard the whole answer. This is the presented answer's
counterpart of the screen document schema's choice not to enumerate the
types at all (`priv/schemas/screen-document.schema.json` at `b16dec4`, the
description of a node's `type`): there a validator older than a type must
not reject the document, and here a client must still be able to tell
which nodes it was built for.

**The fallback for a node type a client does not know.** A client that
meets, in a presented screen, a node whose `type` is not in the
enumeration of the schema it was built against does not render that node,
and does not let the visitor submit that screen from it. This package
renders nothing and sees no client, so it cannot enforce the rule; it is
stated here as the contract a client is built to. How a client tells the visitor, and what it offers instead, is the
client's.

**What stays open.** The transport (how an answer reaches a client and how
a submit comes back), identity (which visitor, which execution, how a
client names the Journey it resumes) and streaming stay open as ADR-0001's
Consequences leave them ("Nothing here decides transport, ..."), and as
Decision 6 keeps them. The schemas describe what crosses the wire, not the
wire.

### Typespecs

A contract for the code half, as the record's own typespecs are. Elixir's
typespecs cannot name a literal string key, so the keys are in the
comments.

```elixir
@typedoc "Where the host's execution is for the visitor."
@type status ::
        {:screen, screen_key :: term()}
        | {:screen, screen_key :: term(), screen_opts()}
        | :waiting
        | {:waiting, waiting_info()}
        | :done
        | {:done, result :: map()}

@typedoc ~s(Optionally "back" => boolean(). Other keys are not read.)
@type screen_opts :: map()

@typedoc """
Optionally "reason" => String.t() and "retry_after_ms" =>
non_neg_integer(). Other keys are not read.
"""
@type waiting_info :: map()

@typedoc """
"state" => "screen" | "waiting" | "done"; when "state" is "screen",
"screen" => screen() and "moves" => moves(); on a waiting answer,
optionally "reason" and "retry_after_ms"; on a done answer, optionally
"result".
"""
@type answer :: %{required(String.t()) => term()}

@typedoc ~s("outcomes" => [String.t()], "back" => boolean().)
@type moves :: %{required(String.t()) => [String.t()] | boolean()}

@typedoc ~s("screen" => String.t(), "outcome" => String.t(), "responses" => map().)
@type submit :: %{required(String.t()) => String.t() | map()}

@spec present(Riddler.Screens.Document.t(), term(), root()) ::
        {:ok, answer()}
        | {:error, :no_such_screen}
        | {:error, :unknown_status}

@spec decode_submit(term()) :: {:ok, submit()} | {:error, [Riddler.Finding.t()]}
```

`put_context/2`, `root()` and `screen()` are as Decision 4 and the record's
Typespecs give them.

### Worked examples

Patron registration, the document of the record's own worked examples:
one screen, `patron_details`, with a conditional greeting, a required
reminder email and a Continue button raising `details_submitted`. The
root is the returning visitor's, `%{"context" => %{"returning" => "yes",
"first_name" => "Ada"}}`.

**A screen, with its moves.** The answer is the record's screen example
with one key beside `"screen"`:

```elixir
Riddler.Journey.present(document, {:screen, "patron_details"}, root)
#=> {:ok,
#    %{
#      "state" => "screen",
#      "screen" => %{
#        "key" => "patron_details",
#        "title" => "Get your library card",
#        "nodes" => [...],
#        "diagnostics" => %{
#          "missing_variables" => [],
#          "undecidable_conditions" => []
#        }
#      },
#      "moves" => %{"outcomes" => ["details_submitted"], "back" => false}
#    }}
```

The nodes are the three of the record's screen example, unchanged.

**A screen the host lets the visitor go back from.**

```elixir
Riddler.Journey.present(document, {:screen, "patron_details", %{"back" => true}}, root)
#=> {:ok, %{"state" => "screen", "screen" => ..., "moves" =>
#      %{"outcomes" => ["details_submitted"], "back" => true}}}
```

**Waiting, with a reason and a retry hint.** The library is issuing the
card number:

```elixir
Riddler.Journey.present(
  document,
  {:waiting, %{"reason" => "card_number_pending", "retry_after_ms" => 5000}},
  root
)
#=> {:ok,
#    %{
#      "state" => "waiting",
#      "reason" => "card_number_pending",
#      "retry_after_ms" => 5000
#    }}

Riddler.Journey.present(document, {:waiting, %{"retry_after_ms" => -1}}, root)
#=> {:error, :unknown_status}
```

**Done, with a result.**

```elixir
Riddler.Journey.present(document, {:done, %{"card_number" => "EXAMPLE-CARD-0001"}}, root)
#=> {:ok, %{"state" => "done", "result" => %{"card_number" => "EXAMPLE-CARD-0001"}}}
```

`EXAMPLE-CARD-0001` is a placeholder, not a card number.

**A submit decoded.** The client posts the details screen:

```elixir
Riddler.Journey.decode_submit(%{
  "screen" => "patron_details",
  "outcome" => "details_submitted",
  "responses" => %{"reminder_email" => "ada@example.com"},
  "sent_at" => "2026-11-18T10:00:00Z"
})
#=> {:ok,
#    %{
#      "screen" => "patron_details",
#      "outcome" => "details_submitted",
#      "responses" => %{"reminder_email" => "ada@example.com"}
#    }}
```

`"sent_at"` is a key the client sent beside the three, and is dropped. A
submit with no outcome and a list where its responses belong raises both
findings:

```elixir
Riddler.Journey.decode_submit(%{"screen" => "patron_details", "responses" => ["ada@example.com"]})
#=> {:error,
#    [
#      %Riddler.Finding{code: "submit.missing_field", field: "outcome", message: ...},
#      %Riddler.Finding{code: "submit.invalid_field", field: "responses", message: ...}
#    ]}
```

The messages are the code half's, in the register of the existing
findings.

**A finding on the wire.** The reminder email refused by
`validate_screen/3` for its format, as a host sends it to a client:

```json
{
  "code": "response.format",
  "message": "...",
  "field": "format",
  "node_key": "reminder_email",
  "position": null
}
```

### Why an amendment and not a note

`docs/adr/README.md` states the test: an entry is an Amendment where "the
rule stated above answers a call one way, and this entry answers the same
call another". Decision 3 answers `{:screen, key, opts}`, `{:waiting, info}`
and `{:done, result}` `{:error, :unknown_status}`, and says the answer's own
keys are exactly `"state"` and `"screen"`; this entry admits all three and adds
`"moves"`, `"reason"`, `"retry_after_ms"` and `"result"`. Decision 1 says
the module holds two functions; this entry adds a third.

### What is unchanged

A host that passes only the three bare statuses gets every waiting and done
answer of riddler 0.4.0 unchanged, and every screen answer unchanged but
for `"moves"` beside `"screen"`. What `"screen"` holds is unchanged by this
entry, its nodes and its diagnostics included. `put_context/2`, its
answers and its refusal are unchanged. `{:error, :no_such_screen}` and
`{:error, :unknown_status}` keep their meanings. `Riddler.Finding` gains no
field and no finding's message changes. `Riddler.Screens` and
`Riddler.Template` gain nothing here. The screen document schema and the
corpus case schema are unchanged except that the corpus case schema lists
`journey.decode_submit` among its capabilities once the code half lands.
Decision 6 stands: storage, the stepper, the transport and identity are the
host's, and nothing here stores, steps, transports or identifies. ADR-0002's
amendment of 2026-11-16 on `secret_question` is unchanged, and its
sentence that `Riddler.Journey` "gains no function and no argument" is
about that amendment's own work. The vocabulary is the record's:
`responses`, `context`, `outcome`, `writes`, `nodes`, and a question owns
its `answer_options`.

### What this does not decide

- Whether an outcome that two shown buttons raise is listed in `"outcomes"`
  once or once for each button.
- What a client sends to go back, when `"back"` is true. A submit carries
  an outcome; a request to go back is a later record's.
- Which button a host passes to `validate_screen/4` for a submit, which
  names an outcome rather than a button key.
- What `"moves"` lists for a shown button that carries no string
  `outcome`, which only a document `validate/1` refuses can hold.
- What a question node's `"value"` holds and in what order a response, a
  prefill and a default yield it.
- How a client's built-in handling of an unknown node type is built, and
  what it shows the visitor.
- The transport, identity and streaming.

---

Noted 2026-11-19. The amendment above headed "the presented answer, the
submit and a finding as a published wire contract" moves from `proposed` to
`accepted`, its Status line flipped in place and nothing else in it reworded.
The record's own Status stays accepted, and its row in `docs/adr/README.md`
is unchanged. The flip was decided by the conductor under a standing consent,
2026-11-19.

It shipped in riddler 0.5.0, the commit tagged `v0.5.0` (`e315ef2`) and
published on Hex; its code half is `9cdce58`, `72f8069`, `d69e6ed`, `e5b7413`,
`2e7c730` and `82bcc79`. It was re-verified at the tag, every cite
re-located by anchor there; `main` is that commit. What was read:

- `Riddler.Journey.present/3` has a clause for each of the six status
  shapes. A map of the wrong type, a `"back"` that is not a boolean, a
  `"reason"` that is not a string, a `"retry_after_ms"` that is not a
  non-negative integer and a `result` that is a struct each answer
  `{:error, :unknown_status}`; a key the table does not name is not read; and
  `{:screen, key, opts}` with a key the document does not declare answers
  `{:error, :no_such_screen}`.
- Every screen answer carries `"moves"` beside `"screen"`: `"outcomes"` is
  the outcome of each shown button in document order, a hidden button absent
  and a container's winning candidate's button listed, `[]` where none is
  shown, and `"back"` is true only when the host passed it true. `"reason"`,
  `"retry_after_ms"` and `"result"` appear only on their states, and
  `{:waiting, %{}}` and `{:screen, key, %{}}` answer what the bare forms
  answer.
- `Riddler.Journey.decode_submit/1` is the module's third public function. It
  answers `submit.not_an_object` alone for a value that is not a map or is a
  struct, and otherwise one finding per failing key in the order
  `"screen"`, `"outcome"`, `"responses"`, each with `node_key` and
  `position` nil; an accepted submit keeps exactly the three keys.
  `corpus/journey/decode_submit.json` holds it as `journey.decode_submit`.
- `presented-answer.schema.json`, `submit.schema.json` and
  `finding.schema.json` are in `priv/schemas/`, each naming draft 7 and none
  forbidding a key it does not name; `@schema_files` in
  `lib/riddler/corpus.ex` names all five schemas, and
  `test/packaging_test.exs` still holds the package to one document schema.
  The presented answer's schema holds a node of `heading`, `text`,
  `text_question`, `choice_question`, `boolean_question`, `secret_question`
  or `button` to its resolved fields, lets a node of any other string type
  through, admits `"value"` on every question type but `secret_question`, and
  refuses it there.
- `Riddler.Encoding` writes a `Riddler.Finding` with every key present, and
  `encode_findings/1` in `lib/riddler/corpus.ex` still compares a finding by
  `"code"`, `"field"` and `"node_key"`.
- Every worked example was run at `e315ef2` and answers as written, and a
  screen, a waiting and a done answer each validate against the presented
  answer's schema.

Four sentences are read, not changed:

- **The finding's five keys.** The table under "A finding's wire form is its
  struct's data form" lists five keys, and "What is unchanged" says
  `Riddler.Finding` "gains no field". ADR-0002's amendment of 2026-11-18,
  accepted in the same request, adds `author_message`, says that sentence is
  about this entry's own work, and says the form carries a sixth key from the
  release whose code adds the field; `finding.schema.json` at the tag
  requires all six.
- **What else this entry calls unchanged.** "What `"screen"` holds is
  unchanged by this entry", every screen answer of riddler 0.4.0 "unchanged
  but for `"moves"`", and "`Riddler.Screens` and `Riddler.Template` gain
  nothing here" are about this entry's own work. In 0.5.0 a question node
  gains `"held"` or `"value"`, `help` and `messages` under ADR-0002's two
  amendments of 2026-11-16 and 2026-11-18, and `Riddler.Screens` gains
  `seal_secrets/4` and `Riddler.Template` an internal `paths/1` under the
  first of them.
- **The corpus case schema.** "What is unchanged" says the corpus case schema
  is unchanged except that it lists `journey.decode_submit` among its
  capabilities. At the tag its capability enumeration also lists
  `screens.seal_secrets`, from ADR-0002's amendment of 2026-11-16
  (`be85db1`), and the descriptions of its `input` and its `capability`
  gained sentences naming the inputs and answers of the capabilities this
  entry and that amendment add: `opts`, `info` and `result` for
  `journey.present` (`2e7c730`, `d69e6ed`, `e5b7413`), the moves beside a
  screen (`2e7c730`) and `journey.decode_submit` (`72f8069`). A description
  constrains nothing, so the schema accepts what it accepted at `v0.4.0` but
  for the two capabilities.
- **The cross-cite.** The section headed by "A question node may carry a
  `"value"`" cites ADR-0002's amendment of 2026-11-16 "at `proposed`". That
  amendment moves to accepted in the same request, by the note of this date
  at the foot of ADR-0002.

This note decides nothing.
