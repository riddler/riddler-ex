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

---

## Amendment, 2026-11-19: the back request, and a button's outcome is a string

Status: accepted (2026-11-20, riddler 0.6.0)

Recorded 2026-11-19, bead rd-h206. A second submit shape, `"screen"` with
`"back"` true and no outcome, in which unsubmitted input on the screen left
is dropped and earlier held responses are kept, shipping in riddler 0.6.0,
was ruled by the operator, 2026-11-19. That `validate/1` refuses a shown
button whose `outcome` is not a string with a new document finding in
riddler 0.6.0, so that a 0.x minor refuses what 0.5.0 admitted, was ruled by
the operator, 2026-11-19. That the back request is a shape this package
decodes and the host raises its own engine's event, with no store, stepper,
trail, process, transport, renderer or identity surface added here, was
ruled by the operator, 2026-11-19. The rest - how the decoder tells the two
shapes apart, what it answers for each, the finding codes, the new finding's
name and fields, and what the schemas and the corpus gain - is this entry's
own, written 2026-11-19 at `proposed`.

Every cite below of the package as it stands is read at `10fe9cd`. The code
half is separate requests (bead rd-9yqn for the decoder, its schema and its
corpus cases; bead rd-ms7n for the new document finding). Nothing below is
citable from `lib/`, `priv/` or `corpus/` until they land, so what they add
is described here, not cited.

### What the record now decides

**A client asks to go back with a second submit shape.** When the presented
answer's `"moves"` carries `"back"` true and the visitor asks to go back,
what the client sends is:

```json
{"screen": "card_delivery", "back": true}
```

`"screen"` is the key of the screen the client was shown, a string, as it is
in a submit; `"back"` is `true`. There is no `"outcome"`: going back presses
no button. There is no `"responses"` either: what the visitor entered on the
screen being left was never submitted, and it is dropped.

**`decode_submit/1` tells the two shapes apart by two keys.** A map that
carries no `"outcome"` and whose `"back"` is `true` is a back request. Every
other value is decoded exactly as riddler 0.5.0 decodes it, against the
three-key submit of the Amendment of 2026-11-18 above, whose table and
order of findings are unchanged. So:

| The input | Answer |
|---|---|
| a map with no `"outcome"`, `"back"` true, `"screen"` a string | `{:ok, %{"screen" => key, "back" => true}}` |
| a map with no `"outcome"`, `"back"` true, `"screen"` absent | `{:error, findings}`, the one finding `submit.missing_field`, its `field` `"screen"` |
| a map with no `"outcome"`, `"back"` true, `"screen"` not a string | `{:error, findings}`, the one finding `submit.invalid_field`, its `field` `"screen"` |
| any other value | the answer riddler 0.5.0 gives it |

`{:ok, back_request}` carries the string-keyed map of exactly `"screen"` and
`"back"`. A key the client sent beside them is dropped, not carried, as it
is for a submit, and that includes a `"responses"`: a client that sends what
the visitor had typed beside `"back"` true has it dropped by the decoder, so
none of it reaches the root. The finding codes are the three the submit
already has, in the same register; no code is added for the back request.
`node_key` and `position` are nil on every one, as they are on a submit's.

The two malformed shapes a client can send near a back request answer as
they do in riddler 0.5.0, because neither is a back request by the rule
above:

- **An outcome beside `"back"`.** A map carrying `"outcome"` is a submit,
  whatever its `"back"` holds, and is decoded as one: with `"screen"`,
  `"outcome"` and `"responses"` well formed it is `{:ok, submit}` with
  `"back"` dropped as a key beside the three, and otherwise it raises the
  submit's findings. A client that means to go back sends no outcome.
- **A `"back"` that is not `true`.** A map with no `"outcome"` whose
  `"back"` is absent, `false` or any value other than `true` is a submit with
  no outcome, and raises `submit.missing_field` on `"outcome"`, with the
  submit's other findings, as it does today.

Only a map that carries no `"outcome"` and `"back"` true answers otherwise
than in riddler 0.5.0, which answered it `submit.missing_field` on
`"outcome"`, with a finding for each of its other keys that failed
(`decode_submit/1` in `lib/riddler/journey.ex` at `10fe9cd`).

The decoder reads no document and no execution, as Decision 1 and the
Amendment of 2026-11-18 say of it. It does not check that the host presented
`"back"` true for that screen, as it does not check that an outcome is among
the presented `"outcomes"`, and it does not compare `"screen"` with the
screen the host's execution is at.

**The host raises its engine's back event, and this package holds no
trail.** Which screen going back reaches, whether it is allowed from where
the execution is, and how the engine records where the visitor has been are
the host's workflow engine's, under Decision 6's stepper. This package keeps
no trail of screens, no history and no count of steps, and gains no function
that moves a Journey. A host that decodes a back request raises its engine's
event, and then passes `present/3` the status its engine answers, as for any
step.

**The responses already held are kept.** A back request changes nothing in
the root. The root's `"responses"` - what the visitor submitted on earlier
screens, the screen gone back to included - stay as they are, and nothing in
this package removes one; `put_context/2` leaves them untouched (Decision 4).
What a question node presents of a response the root holds stays the open
item it was (below).

**A shown button's `outcome` is a string, and `validate/1` refuses one that
is not.** The presented answer's schema already types a button's
`"outcome"` a string, and each item of `"outcomes"` too
(`priv/schemas/presented-answer.schema.json` at `10fe9cd`, the button's
conditional and the `"moves"` object). The screen document schema does not:
a field a type names other than a choice question's `answer_options` is
"the type's own and is carried through untouched" (its node description,
`priv/schemas/screen-document.schema.json` at `10fe9cd`), so `admit/1`
carries a button's `outcome` as written. And `validate/1` does not check its
type: a
button needs the field (`Riddler.Screens.Type.Button.fields/0` at
`10fe9cd`, which names `outcome` required, raising `document.missing_field`
when it is absent), and `document.duplicate_outcome` compares only the
outcomes that are strings (the `Riddler.Screens.Document` moduledoc, its
`document.duplicate_outcome` bullet, at `10fe9cd`). From riddler 0.6.0
`validate/1` raises a new finding:

- `document.invalid_outcome` - a button's `outcome` is there and is not a
  string, `null` included. One finding per such button, its `field`
  `"outcome"` and its `node_key` the button's key; it is raised with the
  button's other field findings, so it comes before any
  `document.duplicate_outcome` on the screen. A button with no `outcome` is
  still `document.missing_field`, and is not this finding too.

The code is named in the register of `document.invalid_writes`,
`document.invalid_style` and `document.invalid_validates`, the three
findings a button already raises for a field that is there and of the wrong
type (`Riddler.Screens.Type.Button.validate/1` at `10fe9cd`). `document.duplicate_outcome`
keeps comparing string outcomes only; a button carrying the new finding is
not compared.

**So `"moves"` never meets a button without a string outcome.** For a
document `validate/1` accepts, every shown button's outcome is a string, and
`"outcomes"` lists it. `present/3` does not validate the document it is
handed; for a document `validate/1` refuses, it lists only the outcomes that
are strings, as it does at `10fe9cd` (the private `outcomes/1` in
`lib/riddler/journey.ex`), and nothing here changes that.

**The schemas and the corpus.** `submit.schema.json` describes the back
request beside the submit, in the release whose code decodes it, as a shape
of the two keys required, `"screen"` a string and `"back"` the constant
`true`; it forbids no key it does not name, as no schema here does. The
corpus holds the back request to its answers in the existing
`journey.decode_submit` capability and its one case file,
`corpus/journey/decode_submit.json`, and holds `document.invalid_outcome` in
the cases `validate/1` is already held to. No capability is added. The
presented answer's schema is unchanged: `"moves"` already carries `"back"`.
The screen document schema is unchanged too: a button whose `outcome` is
not a string is still a document, admitted and then refused by `validate/1`,
as its description says of everything a document can be wrong about.

### Typespecs

A contract for the code half, as the record's own typespecs are.

```elixir
@typedoc ~s("screen" => String.t(), "outcome" => String.t(), "responses" => map().)
@type submit :: %{required(String.t()) => String.t() | map()}

@typedoc ~s("screen" => String.t(), "back" => true.)
@type back_request :: %{required(String.t()) => String.t() | true}

@spec decode_submit(term()) ::
        {:ok, submit() | back_request()} | {:error, [Riddler.Finding.t()]}
```

`present/3`, `put_context/2` and the status shapes are as the Amendment of
2026-11-18 gives them.

### Worked examples

Patron registration, the document of the record's own worked examples with a
second screen after `patron_details`: `card_delivery`, where the visitor
chooses how the library card reaches them, a choice question
`delivery_method` and a Continue button raising `delivery_chosen`. The
visitor has submitted `patron_details`, so the root holds
`%{"reminder_email" => "ada@example.com"}` under `"responses"`, and the host
presents `card_delivery` with `"back"` true:

```elixir
Riddler.Journey.present(document, {:screen, "card_delivery", %{"back" => true}}, root)
#=> {:ok, %{"state" => "screen", "screen" => ..., "moves" =>
#      %{"outcomes" => ["delivery_chosen"], "back" => true}}}
```

**A back request decoded.** The visitor picks a delivery method, then
presses Back before Continue. The client sends what the visitor had picked
beside the request, and the decoder drops it:

```elixir
Riddler.Journey.decode_submit(%{
  "screen" => "card_delivery",
  "back" => true,
  "responses" => %{"delivery_method" => "mail"}
})
#=> {:ok, %{"screen" => "card_delivery", "back" => true}}
```

The host raises its engine's back event; its engine answers that the
execution is at `patron_details` again, and the host presents that screen.
The root's responses still hold `"reminder_email"`, and `"delivery_method"`
never reached them.

**Near a back request.** An outcome beside `"back"` is a submit, and a
`"back"` that is not `true` is a submit with no outcome:

```elixir
Riddler.Journey.decode_submit(%{
  "screen" => "card_delivery",
  "back" => true,
  "outcome" => "delivery_chosen",
  "responses" => %{"delivery_method" => "mail"}
})
#=> {:ok,
#    %{
#      "screen" => "card_delivery",
#      "outcome" => "delivery_chosen",
#      "responses" => %{"delivery_method" => "mail"}
#    }}

Riddler.Journey.decode_submit(%{"screen" => "card_delivery", "back" => "yes"})
#=> {:error,
#    [
#      %Riddler.Finding{code: "submit.missing_field", field: "outcome", message: ...},
#      %Riddler.Finding{code: "submit.missing_field", field: "responses", message: ...}
#    ]}

Riddler.Journey.decode_submit(%{"back" => true})
#=> {:error,
#    [%Riddler.Finding{code: "submit.missing_field", field: "screen", message: ...}]}
```

**A button whose outcome is not a string.** The details screen's Continue
button written with a number where its outcome belongs:

```elixir
%{"type" => "button", "key" => "details_next",
  "label" => "Continue", "outcome" => 1}
```

The document is admitted, and `validate/1` refuses it:

```elixir
Riddler.Screens.Document.validate(document)
#=> {:error,
#    [
#      %Riddler.Finding{code: "document.invalid_outcome", field: "outcome",
#        node_key: "details_next", message: ...}
#    ]}
```

The messages are the code half's, in the register of the existing findings.

### Why an amendment and not a note

`docs/adr/README.md` states the test: an entry is an Amendment where "the
rule stated above answers a call one way, and this entry answers the same
call another". The Amendment of 2026-11-18 answers a map with no
`"outcome"` and `"back"` true with `submit.missing_field` findings, and
this entry answers it `{:ok, back_request}`. `validate/1` accepts a document
whose button carries an `outcome` that is not a string, and this entry
refuses it; a new refusal is, in the README's words, a sufficient reason for
an amendment.

### What is unchanged

Every value riddler 0.5.0's `decode_submit/1` decodes, other than a map
with no `"outcome"` and `"back"` true, answers as it does there: the
three-key submit, its findings and their order, and the dropping of a key
beside the three. `present/3`, the status shapes, the answer and its
`"moves"` are unchanged, and so is `put_context/2`. A document that declares
a button its host's engine treats as going back - a button raising an
outcome, with `validates` false so that pressing it does not validate the
screen (the `Riddler.Screens.Type.Button` moduledoc at `10fe9cd`) - is
unchanged, and pressing it sends a submit, not a back request.
`Riddler.Finding` gains no field. Every document finding `validate/1` raises
in 0.5.0 keeps its code and its meaning. Decision 6 stands: storage, the
stepper, the transport and identity are the host's, and nothing here stores,
steps, transports or identifies. No dependency is added. The vocabulary is
the record's: `responses`, `context`, `outcome`, `writes`, `nodes`, and a
question owns its `answer_options`.

### What this decides of the open items

Of the items the Amendment of 2026-11-18 lists under "What this does not
decide", two are decided here and the bullets there are not reworded:

- "What a client sends to go back, when `"back"` is true" is the back
  request above.
- "What `"moves"` lists for a shown button that carries no string
  `outcome`" is answered by the refusal above: no document `validate/1`
  accepts holds one, and for one it refuses `"outcomes"` lists only the
  string outcomes.

### What this does not decide

- Whether an outcome that two shown buttons raise is listed in `"outcomes"`
  once or once for each button.
- Which button a host passes to `validate_screen/4` for a submit.
- What a question node's `"value"` holds and in what order a response, a
  prefill and a default yield it, and so what the screen gone back to shows
  of the responses held for it.
- How a client's built-in handling of an unknown node type is built, and
  what it shows the visitor.
- Going back across a boundary the host's engine draws inside a Journey.
- The transport, identity and streaming.

---

Noted 2026-11-20, bead rd-qulg, and two items carried out of the reviews
of the two amendments above. Five notes by addition, each read against `main`
at `f745baa`. Nothing above is changed; each paragraph below says what the
text above means now. Where a note speaks of `validate/1` refusing a button
whose `outcome` is not a string, that is `document.invalid_outcome`, which is
on `main` and ships in riddler 0.6.0: `@version` in `mix.exs` at `f745baa` is
still 0.5.0.

- **An outcome two shown buttons raise is listed once.** The Amendments of
  2026-11-18 and 2026-11-19 each list, under "What this does not decide",
  whether such an outcome is listed in `"outcomes"` once or once for each
  button; the bullets are not reworded. The code answers it, and has since
  riddler 0.5.0 (`2e7c730`, in `v0.5.0`): the private `outcomes/1` in
  `lib/riddler/journey.ex` lists each string outcome once, at its first
  button in the screen's order (`uniq: true`), and the `Riddler.Journey`
  `@doc` for the answer says no outcome is listed twice. For a document
  `validate/1` accepts the two readings give one list, because
  `document.duplicate_outcome` refuses two buttons a screen can show together
  that raise one outcome (the `Riddler.Screens.Document` moduledoc at
  `f745baa`), so there is one entry per shown button. For a document
  `validate/1` refuses, the list is the code's once-each reading, and the
  presented answer's schema agrees with it: `"outcomes"` there is
  `uniqueItems` (`priv/schemas/presented-answer.schema.json` at `f745baa`).
  The moves paragraph's "the outcome of each button among the presented
  screen's `"nodes"`, in document order" is read so: each outcome once, at
  its first button. `test/riddler/journey_test.exs` holds it in "lists an
  outcome once for a document validate/1 refuses". This note decides
  nothing the code did not already do.
- **The presented answer's per-type holds are met by the answer for a
  document `validate/1` accepts.** `present/3` takes an admitted document and
  does not validate it, and `admit/1` carries a button's `outcome` as
  written. Run at `f745baa`, a document with one button whose `outcome` is
  `5` and another whose `outcome` is a string is refused by `validate/1`; its
  `present/3` answer carries the button with `"outcome"` as `5` among the
  screen's `"nodes"`, and that answer does not satisfy the presented answer's
  schema, whose button branch types `"outcome"` a string. Its `"moves"` still
  does: `outcomes/1` lists the string outcomes only (the Amendment of
  2026-11-19, "So `"moves"` never meets a button without a string outcome").
  The same document with only its string-outcome button answers a screen that
  satisfies the schema. So the schema's holds on a node of a known type
  describe what a validated document presents, and for a button's `outcome`
  an admitted document `validate/1` refuses is outside them. From 0.6.0 that
  document is one `validate/1` refuses with `document.invalid_outcome`, so a
  host that validates before it presents never meets the difference.
- **"A struct is not a map here" holds for the screen form's `opts` and the
  waiting form's `info` as it does for the done form's `result`.** The
  sentence stands in the paragraph on the `{:done, result}` form only, and
  the code applies it to all three: `back/1` and `waiting_data/1` in
  `lib/riddler/journey.ex` each carry `not is_struct/1` on the map clause, so
  `{:screen, key, opts}` with a struct `opts` and `{:waiting, info}` with a
  struct `info` answer `{:error, :unknown_status}`, as `{:done, result}` with
  a struct does, and the `Riddler.Journey` `@doc` says "a struct included" of
  each. `test/riddler/journey_test.exs` holds the three: "refuses opts that
  are not a map or carry a back that is not a boolean" and "refuses an info
  that is not a map or carries a named key of the wrong type" each name a
  `URI` struct, and so does the done form's test, "refuses a result that is not a map". The refusal is the
  `{:error, :unknown_status}` of Decision 3's row "anything else".
- **The corpus case schema.** The Note of 2026-11-19 cites `be85db1` for the
  `screens.seal_secrets` enum entry only. That commit also added a sentence
  naming the capability's inputs and the fixed test sealer to the
  description of `input`, and a sentence naming its answer to the description
  of `capability`, in `priv/schemas/corpus-case.schema.json`. So those two
  descriptions' sentences for `screens.seal_secrets` are `be85db1`'s, beside
  the four commits that note names for the sentences about
  `journey.present` and `journey.decode_submit`. It was a gap in what the
  note cites and not in what it says: a description constrains nothing, and
  the schema accepts what it accepted at `v0.4.0` but for the two
  capabilities.
- **The submit schema's back request shape names `outcome` only to keep it
  out.** In `priv/schemas/submit.schema.json` at `f745baa` the shape for the
  back request names `outcome` once, under `not` with `required`, so a map
  that carries an `"outcome"` key, `null` included, does not satisfy it; it
  does not list `outcome` among its properties and does not require it. The
  submit shape requires `"outcome"` as a string, so no value satisfies both
  shapes and the two stay disjoint under `oneOf`. That is what lets the
  schema accept exactly what `decode_submit/1` answers `{:ok, _}` for: a map
  with no `"outcome"`, `"back"` true and a string `"screen"` is a back
  request, and a map with a string `"screen"`, a string `"outcome"` and a
  `"responses"` map is a submit, whatever else either carries. This was run
  at `f745baa` over every combination of a `"screen"` that is a string, an
  integer or absent, an `"outcome"` that is a string, `null`, an integer or
  absent, a `"back"` that is `true`, `false`, a string or absent, and a
  `"responses"` that is an object, an array or absent: the schema accepts a
  value exactly when `decode_submit/1` does. The Amendment of 2026-11-19 says
  the back request's shape "forbids no key it does not name"; it names
  `outcome`, so that holds.

This note decides nothing.

---

Noted 2026-11-20. The amendment above headed "the back request, and a
button's outcome is a string" moves from `proposed` to `accepted`, its Status
line flipped in place and nothing else in it reworded. The record's own
Status stays accepted, and its row in `docs/adr/README.md` is unchanged. The
flip was decided by the conductor under a standing consent, 2026-11-20.

It shipped in riddler 0.6.0, the commit tagged `v0.6.0` (`ebe975b`) and
published on Hex; its code half is `88648b0` (the decoder, its schema and its
corpus cases) and `f745baa` (the document finding). It was re-verified at the
tag, every cite re-located by anchor there; `main` is that commit. What was
read:

- `Riddler.Journey.decode_submit/1` answers each row of the amendment's
  table as written: a map with no `"outcome"`, `"back"` true and a string
  `"screen"` is `{:ok, %{"screen" => key, "back" => true}}`, every other key
  dropped, a `"responses"` included; with `"screen"` absent it is the one
  `submit.missing_field` on `"screen"`, and with `"screen"` not a string the
  one `submit.invalid_field` on `"screen"`, each with `node_key` and
  `position` nil. The private `back_request?/1` is the two-key rule, `"back"`
  exactly `true` and no `"outcome"` key.
- The two malformed shapes answer as in riddler 0.5.0: a map carrying
  `"outcome"` beside `"back"` true is decoded as a submit, `"back"` dropped
  (with `"outcome"` `null` it raises `submit.invalid_field` on `"outcome"`),
  and a `"back"` that is `false`, a string or absent leaves a map with no
  `"outcome"` a submit raising `submit.missing_field` on `"outcome"` with its
  other findings. A value that is not a map, or is a struct, still answers
  `submit.not_an_object` alone.
- `Riddler.Screens.Type.Button.validate/1` raises `document.invalid_outcome`
  for an `outcome` that is there and is not a string, `null` included (an
  admitted button keeps `outcome: nil`), its `field` `"outcome"` and its
  `node_key` the button's key, one per such button, beside
  `document.invalid_writes`, `document.invalid_style` and
  `document.invalid_validates`. A button with no `outcome` raises
  `document.missing_field` alone. Run at `ebe975b`, a screen with two
  buttons sharing a string outcome and a third whose `outcome` is `7` gives
  `document.invalid_outcome` before `document.duplicate_outcome`, and two
  buttons whose `outcome` is `7` give one `document.invalid_outcome` each and
  no `document.duplicate_outcome`. The `Riddler.Screens.Document` moduledoc
  lists the new finding and its `document.duplicate_outcome` bullet says a
  button raising it is not compared.
- `present/3` and `put_context/2` are as they were at `10fe9cd`: every change
  to `lib/riddler/journey.ex` since then serves the back request -
  `decode_submit/1` and its private helpers (the new `back_request?/1`, and a
  `shape` argument on `submit_findings`), the `back_request` type, and the
  moduledoc's back-request paragraph - and the private `outcomes/1` still
  lists only the
  outcomes that are strings. `Riddler.Finding` is unchanged, and the only
  change to `mix.exs` is `@version`.
- `priv/schemas/submit.schema.json` is a `oneOf` of the submit and the back
  request, the back request requiring `"screen"` a string and `"back"` the
  constant `true`; the dated Note above of this date, in its bullet on the
  back request shape, reads how it names `outcome`. The presented answer's
  schema and the screen document schema are unchanged since `10fe9cd`; the
  corpus case schema's capability enumeration is unchanged and only the
  description of `capability` gained the back request.
- `corpus/journey/decode_submit.json` holds the back request in the existing
  `journey.decode_submit` capability, and `corpus/screens/admit.json` holds
  `document.invalid_outcome`; no capability is added.
- The `back_request` and `submit` types and the `@spec` of `decode_submit/1`
  in `lib/riddler/journey.ex` are the record's; their `@typedoc` text is the
  code's own wording and constrains nothing.
- Every worked example was run at `ebe975b` and answers as written.

Two sentences are read, not changed:

- **What is described and not cited.** The amendment says nothing it adds is
  "citable from `lib/`, `priv/` or `corpus/` until they land". Both have
  landed, at the commits above, and the cites in this note are to them.
- **Its own status.** The amendment's opening paragraph calls its own part
  "written 2026-11-19 at `proposed`". It was written so; it now reads
  accepted, by this note.

This note decides nothing.

---

## Amendment, 2026-11-23: who may see and step a Journey, its scope, and the progress a host supplies

Status: proposed

Recorded 2026-11-23, bead rd-xea9. That the host contract for who may see
and step a Journey lives in this package as three modules,
`Riddler.Journey.Scope`, `Riddler.Journey.Access` and
`Riddler.Journey.Host`, shipping in riddler 0.7.0, and that a transport
built later consumes `Access` and `Host` as they are, was ruled by the
operator, 2026-11-23. So were: that a scope is one pair of strings, a kind
and an id, the kinds open, fixed when the Journey starts and never
interpreted here; that the host stores it on its own execution record and
this package stores nothing; that the scope kind a Path expects is
declared on the host's own Path record and checked by a pure function
here, with no change to the document format; that a renderer asks on
mount, on every submit and on every back, and that a Journey that does not
exist and a Journey that is not the asker's get one and the same refusal;
that progress is a screen option the host supplies, drawn only when it is
there, and that skip stays an authored button with no generic skip; and
that a renderer is a separate package and this one ships none. The rest -
the callbacks' names and what each answers, the refusals' spellings, what
the pure check does with an answer that is not `true`, the progress
option's shape and where it sits in the answer, and the corpus
capabilities - is this entry's own, written 2026-11-23 at `proposed`.

Every cite below of the package as it stands is read at `ba33a99`. The code
half is separate requests (bead rd-u3qf for the scope; rd-4bn8 for the
access behaviour, its check and the kind check; rd-1l4y for the host
behaviour; rd-w87s for progress). Nothing below is citable from `lib/`,
`priv/` or `corpus/` until they land, so what they add is described here,
not cited.

### What the record now decides

**A Journey has a scope: one kind and one id, both strings.**
`Riddler.Journey.Scope` is a struct of two fields, `kind` and `id`, each a
string of at least one byte. The kinds are open: `"patron"`, `"branch"` and
any other string a host names are all kinds, and this package lists none.
Neither string is read for what it means - not trimmed, not case-folded,
not parsed, not looked up - and two scopes are the same scope exactly when
both strings are equal byte for byte.

| Function | Answer |
|---|---|
| `Scope.new(kind, id)`, both strings of at least one byte | `{:ok, %Scope{kind: kind, id: id}}` |
| `Scope.new(kind, id)`, anything else | `{:error, :invalid_scope}` |
| `Scope.to_data(scope)` | `%{"kind" => kind, "id" => id}` |
| `Scope.from_data(data)`, a map whose `"kind"` and `"id"` are strings of at least one byte | `{:ok, %Scope{}}`, every other key of the map not read |
| `Scope.from_data(data)`, anything else, a struct included | `{:error, :invalid_scope}` |

`:invalid_scope` is spelled in the register of `:context_not_a_map`
(Decision 4). The data form is what a host keeps; how and where is the
host's, as Decision 6 says of storage.

**The scope is fixed when the Journey starts.** The host chooses it when it
starts the execution and keeps it on its own execution record beside
whatever else it keeps there. `Scope` has no function that changes a
scope, and no function here reads an execution to find one: the host
supplies the scope on every call that needs it. How a host's storage keeps
the scope for an execution it starts from another is the storage's, and
not this record's.

**`Riddler.Journey.Access` is the behaviour a host implements to say who
belongs to a scope.** Who is asking is the host's to represent, and is
called the actor below; this package passes it through and never reads it.

| Callback | What the host answers |
|---|---|
| `member?(actor, scope)` | `true` when the actor belongs to the scope, `false` otherwise |
| `scopes(actor)` | the scopes the actor belongs to, a list of `Scope` structs, for a host or a renderer that lists the Journeys an actor may resume |
| `allowed?(actor, scope, operation)`, optional | `true` when the actor may take that operation in that scope, `false` otherwise |

A host keeps `member?/2` and `scopes/1` in agreement: a scope is in
`scopes(actor)` exactly when `member?(actor, scope)` is `true`. This package
cannot check that, and does not call `scopes/1` itself.

**`Access.check/4` is the one question a renderer asks.**
`Riddler.Journey.Access.check(access, actor, scope, operation)` takes the
host's module implementing `Access`, the actor, the Journey's scope as the
host holds it, and the operation, one of `:present`, `:submit` and `:back`. It
answers `:ok` or `{:error, :no_such_journey}`, and nothing else:

| The call | Answer |
|---|---|
| `member?(actor, scope)` answers `true`, and `access` does not export `allowed?/3` | `:ok` |
| `member?(actor, scope)` answers `true`, and `allowed?(actor, scope, operation)` answers `true` | `:ok` |
| `member?/2` or `allowed?/3` answers anything other than `true`, `false` included | `{:error, :no_such_journey}` |
| `scope` not a `Scope` struct, `operation` outside the three, or `access` not an atom naming a module that exports `member?/2` | `{:error, :no_such_journey}` |

What `access` exports is read after `Code.ensure_loaded/1` on it, in every
row above, so a module not yet loaded is not taken for one that does not
export the callback; an `access` that is not an atom is refused without
being loaded. `allowed?/3` is called only after `member?/2` has answered
`true`. The refusal is spelled in the register of `:no_such_screen`
(Decision 3), and it does not say why: a renderer that asks for a Journey
that is not the actor's is answered exactly as it would be for a Journey
that does not exist, so a refusal tells the asker nothing about which
Journeys exist. Every doubt is a refusal: an answer that is not exactly
`true` refuses.

`check/4` is pure in this package's sense: it keeps no state, starts no
process and reads no store or execution. It calls the host's two callbacks
and nothing else, and what they read to answer is the host's. It does not
rescue a callback that raises: a callback that raises is the host's
defect, and this package does not rescue to a default (`CLAUDE.md`,
"Conventions", the first bullet).

**The scope kind a Path expects is the host's to declare and this
package's to check.** A host's Path record - its own, wherever it keeps
its Paths - names the one scope kind a Journey of that Path takes. The
document format does not change: no screen document carries a scope kind,
and `Riddler.Screens.Document.admit/1` and `validate/1` read none.
`Riddler.Journey.Access.check_kind(scope, expected_kind)` answers `:ok` when
`scope` is a `Scope` whose `kind` equals `expected_kind` byte for byte, and
`{:error, :wrong_scope_kind}` otherwise, an `expected_kind` that is not a
string of at least one byte included. It is pure and calls nothing. A host
calls it before it starts an execution, with the kind from its Path record;
what it tells the visitor when the answer is a refusal is its own.

**`Riddler.Journey.Host` is the behaviour for the host's own loop.** A
renderer drives any host through the same four callbacks, and this package
calls none of them: it steps nothing, keeps nothing and moves no Journey,
as Decision 6 says of the stepper. The Journey is named by a string the
host chooses, which this package never reads.

| Callback | What the host answers |
|---|---|
| `start(path, scope)` | `{:ok, journey, answer}` for the Journey it started, or `{:error, :no_such_journey}` |
| `present(journey)` | `{:ok, scope, answer}`, the Journey's scope beside where it is, or `{:error, :no_such_journey}` |
| `submit(journey, submit)` | `{:ok, answer}`, `{:error, findings}`, or `{:error, :no_such_journey}` |
| `back(journey, back_request)` | `{:ok, answer}`, `{:error, findings}`, or `{:error, :no_such_journey}` |

`answer` is what `Riddler.Journey.present/3` answers inside `{:ok, ...}`
for the status the host's engine gives; `submit` and `back_request` are
what `Riddler.Journey.decode_submit/1` answers inside `{:ok, ...}`; the
findings are `Riddler.Finding` structs, a submit's refused by
`decode_submit/1` or a screen's refused by
`Riddler.Screens.validate_screen/3,4`. `start/2` answers the refusal for a
Path the host does not have and for a scope whose kind is not the Path's;
the three others answer it for a Journey the host does not have. The
refusal is the one `check/4` gives, so a renderer shows one thing for
both. `present/1` answers the scope so that a renderer has it for its
check on mount, and holds it for the checks after, since a scope does not
change once the Journey starts.

**What a renderer asks, and when.** A renderer asks `check/4` with the
Journey's scope:

- before a start, with `:present` and the scope the Journey is to be
  started under, before `start/2` is called, so that no Journey is
  started under a scope the actor does not belong to;
- on mount, with `:present`, after `present/1` and before anything of the
  answer is shown;
- on every submit, with `:submit`, before `submit/2` is called;
- on every back, with `:back`, before `back/2` is called.

On `{:error, :no_such_journey}` it shows the one refusal, shows nothing of
the Journey, and calls no callback that would start or step it. It asks
again on every submit and every back rather than once, because whether an
actor belongs to a scope is the host's, and can change while a Journey is
open.
This package renders nothing and sees no renderer, so it cannot enforce
the order; it is stated here as the contract a renderer is built to, as
the fallback for an unknown node type is in the Amendment of 2026-11-18
above.

**Progress is a screen option the host supplies.** The screen status's map
(`{:screen, key, opts}`, the Amendment of 2026-11-18 above) gains a second
key beside `"back"`:

| Key | Value |
|---|---|
| `"progress"` | a map of `"step"` and `"of"`, each an integer of at least 1, with `"step"` not above `"of"` |

Where the host passes it, the screen answer carries it at the answer root,
beside `"screen"` and `"moves"`, as `%{"step" => n, "of" => m}`, and a key
the progress map carries beside those two is not read and not carried.
Where the host does not pass it, the answer has no `"progress"` key. A
`"progress"` that is not a map, or a struct, or lacks `"step"` or `"of"`, or
carries one that is not an integer, below 1, or a `"step"` above `"of"`,
makes the status one outside the shapes, and Decision 3's table answers it
on its row "anything else", `{:error, :unknown_status}`, as a `"back"` that
is not a boolean is answered (the private `back/1` in
`lib/riddler/journey.ex` at `ba33a99`). This package does not count steps
and does not compute progress: how far through a Path a visitor is, is the
host's engine's to know. A renderer draws progress only when the answer
carries it.

**Skip stays an authored button.** A screen a visitor may leave without
filling it carries a button raising its own outcome with `validates` false,
as a Back button does (the `Riddler.Screens.Type.Button` moduledoc at
`ba33a99`, "the opt-out is what lets a Back button leave a half-filled
screen without an error"). There is no generic skip: `"moves"` gains no key
for one, and no submit shape is added for one.

**The schemas and the corpus.** The presented answer's schema admits an
optional `"progress"` object on a screen answer, its `"step"` and `"of"`
integers of at least 1, in the release whose code presents it. The scope,
the access check and the kind check are held to the corpus by three new
capabilities, by Decision 5's convention, each with one case file. Each
existing capability id names an area and a function of it, as
`journey.present` names `present/3` and `screens.admit` names `admit/1`
(the enumeration under `capability` in
`priv/schemas/corpus-case.schema.json` at `ba33a99`), and the new ids
follow it: `journey.from_data` (`corpus/journey/from_data.json`,
`Scope.from_data/1`), `journey.check` (`corpus/journey/check.json`,
`check/4`) and `journey.check_kind` (`corpus/journey/check_kind.json`,
`check_kind/2`). Their input and answer are not `present/3`'s, so they are
capabilities of their own. The corpus case schema's capability enumeration
gains the three, and the description beside it, which says what each
capability exercises, gains a sentence for each; the description of a
case's input says what each of the three takes, as it does for the
existing ones.

A `journey.check` case runs against fixed test access modules the runner
supplies, as a `screens.seal_secrets` case runs against the one test
sealer, and a case states its answer as `{"ok": true}` or as
`{"error": "no_such_journey"}`. Its input carries `access`, `actor`,
`scope` and `operation`. `actor` is handed over as the case states it, any
JSON value. `scope` is handed over as the `Scope` that `Scope.from_data/1`
gives for it where that answers `{:ok, ...}`, and as the case states it
otherwise. `operation` is `present`, `submit` or `back`, handed over as
that operation, and any other value is handed over as itself, which is an
operation outside the three. `access` names one of the three test access
modules below, and any other value is handed over as itself, which is not
a module exporting `member?/2`. Every runtime supplies the three:

| Name | `member?(actor, scope)` | `scopes(actor)` | `allowed?(actor, scope, operation)` |
|---|---|---|---|
| `members` | `true` when `actor` is a list holding `Scope.to_data(scope)`, `false` otherwise | the items of `actor` that `Scope.from_data/1` admits, as `Scope` structs, in order; `[]` when `actor` is not a list | not exported |
| `present_only` | as `members` | as `members` | `true` when `operation` is `:present`, `false` otherwise |
| `not_boolean` | the string `"true"`, for every actor and scope | `[]` | not exported |

A refusal in the other two is stated as `{"error": reason}`, as Decision 5
states one. Progress is held in the
existing `journey.present` capability and its one case file,
`corpus/journey/present.json`, because it is a screen option `present/3`
reads.

### Typespecs

A contract for the code half, as the record's own typespecs are.

```elixir
# Riddler.Journey.Scope
@type t :: %Riddler.Journey.Scope{kind: String.t(), id: String.t()}

@spec new(term(), term()) :: {:ok, t()} | {:error, :invalid_scope}
@spec to_data(t()) :: %{required(String.t()) => String.t()}
@spec from_data(term()) :: {:ok, t()} | {:error, :invalid_scope}

# Riddler.Journey.Access
@type actor :: term()
@type operation :: :present | :submit | :back

@callback member?(actor(), Riddler.Journey.Scope.t()) :: boolean()
@callback scopes(actor()) :: [Riddler.Journey.Scope.t()]
@callback allowed?(actor(), Riddler.Journey.Scope.t(), operation()) :: boolean()
@optional_callbacks allowed?: 3

@spec check(term(), actor(), term(), term()) :: :ok | {:error, :no_such_journey}
@spec check_kind(term(), term()) :: :ok | {:error, :wrong_scope_kind}

# Riddler.Journey.Host
@type journey :: String.t()

@callback start(path :: String.t(), Riddler.Journey.Scope.t()) ::
            {:ok, journey(), Riddler.Journey.answer()} | {:error, :no_such_journey}
@callback present(journey()) ::
            {:ok, Riddler.Journey.Scope.t(), Riddler.Journey.answer()}
            | {:error, :no_such_journey}
@callback submit(journey(), Riddler.Journey.submit()) ::
            {:ok, Riddler.Journey.answer()}
            | {:error, [Riddler.Finding.t()]}
            | {:error, :no_such_journey}
@callback back(journey(), Riddler.Journey.back_request()) ::
            {:ok, Riddler.Journey.answer()}
            | {:error, [Riddler.Finding.t()]}
            | {:error, :no_such_journey}

# Riddler.Journey
@typedoc """
Optionally "back" => boolean() and "progress" => %{"step" => pos_integer(),
"of" => pos_integer()}. Other keys are not read.
"""
@type screen_opts :: map()
```

`check/4`'s access module, scope and operation, and `check_kind/2`'s two
arguments, are typed `term()` because a value outside the types is
answered with the refusal rather than left outside the function. `present/3`, `put_context/2`,
`decode_submit/1` and their specs are as the record and its Amendments give
them.

### Worked examples

**Patron registration, a returning patron.** The library's host scopes each
registration Journey to the patron it is for. A patron signed in as
`P-1001` resumes their own Journey; the host's access module,
`Library.PatronAccess`, answers `member?/2` from the patron's own id.
`ada` and `grace` below are the host's own values for two signed-in
patrons, `ada` being `P-1001`:

```elixir
{:ok, scope} = Riddler.Journey.Scope.new("patron", "P-1001")

Riddler.Journey.Scope.to_data(scope)
#=> %{"kind" => "patron", "id" => "P-1001"}

Riddler.Journey.Access.check(Library.PatronAccess, ada, scope, :present)
#=> :ok
```

Another patron opens the same Journey's link and is answered as if there
were no Journey there:

```elixir
Riddler.Journey.Access.check(Library.PatronAccess, grace, scope, :present)
#=> {:error, :no_such_journey}
```

The registration Path's record on the host says it takes the kind
`"patron"`, so the host checks the scope before it starts a Journey:

```elixir
Riddler.Journey.Access.check_kind(scope, "patron")
#=> :ok

{:ok, branch} = Riddler.Journey.Scope.new("branch", "B-12")
Riddler.Journey.Access.check_kind(branch, "patron")
#=> {:error, :wrong_scope_kind}

Riddler.Journey.Scope.new("patron", "")
#=> {:error, :invalid_scope}
```

**Patron registration, with progress.** The host's engine knows the
details screen is the first of three, and says so:

```elixir
Riddler.Journey.present(
  document,
  {:screen, "patron_details", %{"progress" => %{"step" => 1, "of" => 3}}},
  root
)
#=> {:ok,
#    %{
#      "state" => "screen",
#      "screen" => ...,
#      "moves" => %{"outcomes" => ["details_submitted"], "back" => false},
#      "progress" => %{"step" => 1, "of" => 3}
#    }}

Riddler.Journey.present(
  document,
  {:screen, "patron_details", %{"progress" => %{"step" => 4, "of" => 3}}},
  root
)
#=> {:error, :unknown_status}
```

The same call with no `"progress"` answers what riddler 0.6.0 answers for
it.

**The branch-library onboarding.** A branch library joins the network
through one Path: a screen asks which integrations the branch needs, and
the setup of each one it picked - a card reader, a catalogue sync, a
reading-list import - runs as a Path of its own. A librarian at branch
`B-12` works through it under the scope `{"branch", "B-12"}`, and the
host's access module answers `member?/2` from where the librarian works.
The setups' screens are under the same scope: the host supplies
`{"branch", "B-12"}` on every call for each of them, as it does for the
onboarding's own screens.

```elixir
{:ok, scope} = Riddler.Journey.Scope.new("branch", "B-12")

Riddler.Journey.Access.check(Library.StaffAccess, librarian, scope, :submit)
#=> :ok
```

The host's access module also implements `allowed?/3`, so that a volunteer
who belongs to the branch may look at the card reader setup but not
submit it:

```elixir
Riddler.Journey.Access.check(Library.StaffAccess, volunteer, scope, :present)
#=> :ok

Riddler.Journey.Access.check(Library.StaffAccess, volunteer, scope, :submit)
#=> {:error, :no_such_journey}
```

A setup step the branch may leave for later carries an authored button
raising `setup_deferred` with `validates` false; the host's engine decides
what that outcome does.

### Why an amendment and not a note

`docs/adr/README.md` states the test: an entry is an Amendment where "the
rule stated above answers a call one way, and this entry answers the same
call another". Decision 1 says "There is no behaviour for a host to
implement and no callback this package calls"; this entry adds two
behaviours, and `check/4` calls the host's `member?/2` and `allowed?/3`.
The Amendment of 2026-11-18 says a key the screen status's map carries
that its table does not name "is not read, and nothing of it reaches the
answer"; this entry reads `"progress"`, carries it onto the answer, and
refuses a malformed one. Decision 6 leaves identity undecided; this entry
decides it for an actor the host knows.

### What is unchanged

A host that implements neither behaviour and passes no `"progress"` key
sees every answer of riddler 0.6.0 unchanged, byte for byte: `present/3`
for every status, `put_context/2` and `decode_submit/1`, with their
refusals and findings. The screen document, its schema, `admit/1` and
`validate/1` are unchanged: no document carries a scope or a scope kind.
`Riddler.Finding` gains no field. `"moves"` is unchanged. Decision 6
stands for storage, the stepper and the transport: nothing here stores a
scope, steps a Journey, starts a process, keeps a session, renders or
transports. The runtime dependencies stay `predicator` and `solid`. The
vocabulary is the record's: `responses`, `context`, `outcome`, `writes`,
`nodes`, and a question owns its `answer_options`.

### What this decides of the open items

The Amendment of 2026-11-18 above leaves identity open under "What stays
open", as "which visitor, which execution, how a client names the Journey
it resumes"; that paragraph is not reworded. For an actor the host knows,
it is decided here: the host's access module says which actor belongs to
which scope, the Journey is named by the host's own string, and a renderer
resumes it through `Host.present/1`. Identity stays open only for the
anonymous visitor: one the host does not know, with no actor to pass.

### What this does not decide

- The anonymous visitor: how a Journey started by someone the host does not
  know is resumed, and by whom.
- Streaming.
- The transport: how a renderer reaches a host that is not in the same
  application, and how a refusal or a finding crosses it.
- A scope that changes after the Journey starts, and a Journey under more
  than one scope.
- How a storage package keeps the scope, for an execution and for one it
  starts from another.
- What a renderer shows for the refusal, and how it draws progress.
