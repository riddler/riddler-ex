# ADR-0002: The screen document v1

Status: accepted

## Context

ADR-0001 decided that the content document is the contract between a host and
this runtime, that it is JSON, that it carries a `schema_version`, and that a
content kind is a document shape, a resolved shape, a registry and a corpus
capability. This record decides the document of the one kind v1 ships, the
screens kind: the envelope, what a screen is, what a node is, and what a
resolved screen is. It decides nothing about any other kind.

A document exists so that a host can declare what a visitor is shown without
declaring how it is shown, and so that a second runtime in another language can
be held to the same answer. Everything below is therefore written as a rule
about the document, not about a renderer and not about Elixir.

The public fixture `priv/fixtures/signup_screens.json` in `statifier_examples`
(read at `9d288c9`) is the shape a host already authors by hand: an envelope, a
`metadata` block, three screens of a signup wizard, and eighteen nodes over four
types, with a key on every node, a condition on six of them, one `format`, and
Liquid output in four strings. It is the worked case this record has to admit.

The second piece of public evidence is `docs/spikes/SF040-element-editor.md` in
`statifier_blocks` (added by that repository's PR 465; present at `cdfbc6c`),
which re-authored that fixture in an editor vocabulary that had no screen
container and no per-node key, condition, write or format. Its measurement is
what makes this record's rules non-obvious: 64 fields walked, 39 carried, 25
lost, with the editor reporting zero findings for every loss. The losses were a
node key on anything that was not a question, every condition, every write,
the one `format`, and the screen container itself - the fixture is one document
holding three screens, and what came back was three documents, each rooted at a
heading, with each screen's key homeless and the envelope gone. Two smaller
findings in the same document bear on rules below: a required presentation field
the fixture had no value for, so buttons were given a style to clear a finding;
and one concept that survived under a different spelling, which is why the
vocabulary rules below are stated rather than assumed.

A vocabulary can lose a third of a document and say nothing. That is the failure
this record is written against: what a document may carry is enumerated, and
what it may not is refused loudly.

## Decision

**A document is a JSON object with an envelope and screens.** The envelope is
`schema_version`, an integer, `1` in this version; `kind`, a string, optional;
`id`, a string that names the document; and `metadata`, an object. `metadata`
carries `name`, `description` and `domain` as strings and is otherwise an open
map: a host may put what it likes beside them, and this package neither
interprets nor refuses the extras. A document with no `screens` is refused.

**`kind` names the content kind the document belongs to, and it defaults to
`screens` when absent.** A document that omits `kind` is a screen document, so
every document authored before kinds existed is still admitted unchanged. A
`kind` the registry of kinds does not know is an admit finding,
`document.unknown_kind`, naming the value; it is not passed through silently,
because a document resolved by the wrong kind's rules is worse than a document
refused. The decided `kind` is carried through to the resolved document, so a
host holding a resolved document can tell what it is holding without the
document it came from.

**`screens` is the screens kind's body key, and every other kind carries its
own.** The key that holds a kind's content is the kind's to name; nothing here
reserves a shared body key across kinds, and a second kind's record names its
own.

**A screen is `key`, `title` and `nodes`.** `nodes` is an ordered list, and the
order is the order the visitor is shown. A screen with an empty `nodes` list is
admitted: a screen whose every node is conditional may legitimately resolve to
nothing, and refusing the empty list at admit time would refuse it at authoring
time too.

**Every node has a `type`, and `type` is an open string in the schema while the
Elixir registry refuses a type it does not know.** Those are the two halves of
one rule. The schema does not enumerate types, because a schema that did would
have to be revised in `riddler_spec` before a type could be added here, and
because a host that carries a document through a pipe should not have it
rejected by a validator older than the type. The registry does enumerate them,
so an unknown `type` is an admit finding naming the type and the node, never a
node silently passed through.

**Every node has a `key`.** It matches `[a-z][a-z0-9_]*`. Every key in a
document - a screen's or a node's - is unique across the whole document, not
merely within its screen. The key is how a diagnostic names a node, how a
response is addressed, and how a host correlates a resolved node with the node it
was authored from; a vocabulary that gives keys only to the nodes it thinks need
them has already lost the ability to say which node a finding is about.

**A node may carry a `condition`, and a condition is a `predicator` expression
over `context.*` and `responses.*`.** Three cases, and they are different
things. A condition that does not parse is an admit finding: it is wrong about
the document, and the author should be told before a visitor arrives. A
condition that parses but cannot be evaluated at resolve time - a variable the
context does not carry - hides the node and reports it in the resolved document's
diagnostics. A condition that evaluates false hides the node silently, because
that is not an error, it is the condition doing its job.

**The node vocabulary, `responses`, buttons, `outcome` and `writes` are the
screens kind's and no other's.** They exist because a screen is shown to a
visitor who fills it in and presses something; a kind with no visitor and no
submission carries none of them, and a kind that wants one of them says so in
its own record rather than inheriting it from this one. What is shared across
kinds is the template subset, conditions, containers, diagnostics and findings,
and those rules are written below for screens and generalised by the
forthcoming ADR-0004.

**The v1 types are `heading`, `text`, `text_question`, `button` and `variant`.**
Their fields are:

`heading` carries `level`, an integer from 1 to 6, and `text`.

`text` carries `text`.

`text_question` carries `label`; and optionally `placeholder`, `required` (a
boolean, default false) and `format` (a string naming a validation format the
package knows; `email` is the one the fixture uses). `answer_options` is the
field name reserved for the select question types - a choice question, a multi-select -
and those types are not built in this version. Naming the field now is what keeps
a later select question from arriving under a second spelling.

`button` carries `label` and `outcome`; `outcome` is required. It may carry
`writes`, a map whose keys are `responses.<path>` and whose values are the
two-element form `["const", value]`. It may carry `style`, a string from an open
set the renderer owns, with `primary` and `secondary` named here so that a host
has something to render and an editor has something to offer; a style this
package does not recognize is passed through, not refused, because presentation
is not this package's to enumerate. And it may carry `validates`, a boolean
defaulting to true: a button that submits a screen validates that screen's
responses first, and the opt-out is what lets a Back button leave a half-filled
screen without an error.

`variant` carries `nodes`, a list of candidate nodes. First match wins: the
candidates are considered in order and the first whose condition holds is the
winner. A candidate with no condition is unconditional and wins if it is reached,
so the last candidate with no condition is the default; a candidate with no
condition that is not last makes every candidate after it dead. The winner
replaces the container in the resolved output, so a host that can render a
document can render a resolved one and nothing downstream needs to know a
container was ever there. A `variant` with no candidates is an admit finding.

**`text`, `label` and `placeholder` are templates in the ADR-0003 subset.**
They are compiled by the same code an editor calls, so a template this
package refuses is refused at admit time, with the node's key on the finding.
Any other string field in a document is literal text.

**The host-supplied root is `context` and what a visitor submits is
`responses`.** A response is addressed `responses.<key>`, where the key is the
key of the question node it belongs to; that is the whole of the correspondence, and
there is no second naming scheme for a field. Both roots are readable by a
condition and by a template.

**The vocabulary is fixed here for every document, case and schema downstream.**
The field a button carries is `outcome`; a document that spells it `action` is
refused. The field that records what a control sets is `writes`; a document that
spells it `payload` is refused. The root a visitor's submissions live under is
`responses`; a document that spells it `answers` is refused. These are refusals,
not renames: nothing is accepted and rewritten, because a document that is
accepted under two spellings will be authored under both.

**A resolved screen is the same shape as the screen it came from.** Same
envelope, same screen `key` and `title`, nodes in the same order, with four
differences and one addition. No node carries a `condition`: every condition has
already been decided, and a node that is present is a node that is shown.
Hidden nodes are absent rather than flagged. Variants are collapsed to their
winner. Every template field has been rendered to text. `writes` is carried
through unchanged, because it is what the host applies when the visitor presses
the button and is not this package's to resolve.

**A resolved document carries `diagnostics`.** It has `missing_variables`, a
list naming each template variable that was absent together with the key of the
node whose template wanted it, and `undecidable_conditions`, a list naming each
node key whose condition could not be evaluated. A resolved document with a
non-empty `diagnostics` is still a resolved document: resolution reports, it does
not refuse. Refusal is admit's job.

**Enumeration is delegated to the code half's tests.** The exact finding
messages, the full list of validation formats, and the field-by-field admission
rules are `Riddler.Screens.Document`'s tests and the corpus emitted from them.
This record asserts what the categories are; a list in prose and a list in code
drift apart, and only one of them runs.

## Consequences

Three code halves follow, each with the enumerating tests this record delegates
to. One builds `Riddler.Screens.Document.admit/1` and `validate/1` with the type
registry, and is held to admitting the fixture named in the Context with zero
findings. One builds `Riddler.Screens.resolve/2`, which produces the resolved
document described above, diagnostics included. One builds
`Riddler.Screens.validate_responses/3` and its arity-4 form, which is where
`required` and `format` are enforced and where a button's `validates` is
consulted.

The first release of this package named those modules `Riddler.Elements`, after
the nodes inside a screen rather than after the kind they belong to. The code
half renames the tree to `Riddler.Screens` and the corpus capabilities from
`elements.*` to `screens.*` with 0.1.0, and adds the `kind` envelope field and
its `document.unknown_kind` finding at the same time; no `Riddler.Elements`
name and no `elements.*` capability survives that release.

The shared rules this record states - key uniqueness, conditions, the variant
container, diagnostics and findings - are written here for screens because
screens is the only kind v1 ships. They are generalised to every kind by
ADR-0004, the shared content machinery, which is forthcoming and precedes the
first non-screen kind's record. Until then a reader looking for a shared rule
reads this record, and that is the reason ADR-0004 exists.

The JSON Schema for this document is written from this record, in the draft the
corpus test validates against, and lives beside the corpus. It enumerates the
envelope, the screen and the common node fields, and leaves `type` an open
string, exactly as the rule above says: the registry, not the schema, is what
refuses an unknown type.

Renderers own `style` and own everything else about presentation. This package
neither validates a style value nor ships a default for one.

Nothing here decides transport, authentication, streaming, the identity or
durability of a visitor's execution, or the editor; ADR-0001 left those open and
this record leaves them open. Nothing here decides the select question types: the field
name is reserved, the behavior is not.

## Typespecs

Minimal, and a contract for the code half rather than a second source of truth.

```elixir
@type document :: %{
        schema_version: pos_integer(),
        kind: String.t(),
        id: String.t(),
        metadata: %{optional(String.t()) => term()},
        screens: [screen()]
      }

@type screen :: %{key: String.t(), title: String.t(), nodes: [node_t()]}

@type node_t :: %{
        :type => String.t(),
        :key => String.t(),
        optional(:condition) => String.t(),
        optional(atom()) => term()
      }

@type resolved :: %{
        schema_version: pos_integer(),
        kind: String.t(),
        id: String.t(),
        metadata: %{optional(String.t()) => term()},
        screens: [screen()],
        diagnostics: diagnostics()
      }

@type diagnostics :: %{
        missing_variables: [%{key: String.t(), variable: String.t()}],
        undecidable_conditions: [%{key: String.t(), condition: String.t()}]
      }
```

## Worked examples

One per type. The two domains are the signup wizard the fixture authors and a
multi-tenant host application that processes credit-card payments.

`heading`, from the signup wizard:

```json
{ "type": "heading", "key": "account_heading", "level": 1, "text": "Create your account" }
```

`text`, from the payments host - a template field, rendered before the visitor
sees it:

```json
{
  "type": "text",
  "key": "card_intro",
  "text": "Charging {{ context.tenant_name }} for {{ responses.seats }} seats."
}
```

`text_question`, from the payments host, with a format and a condition:

```json
{
  "type": "text_question",
  "key": "billing_email",
  "condition": "context.send_receipts == true",
  "label": "Where should the receipt go?",
  "placeholder": "billing@example.com",
  "required": true,
  "format": "email"
}
```

`button`, from the signup wizard, writing a response and naming what it raises:

```json
{
  "type": "button",
  "key": "plan_business",
  "condition": "responses.seats > 1",
  "label": "Take the business plan",
  "outcome": "business_chosen",
  "writes": { "responses.plan": ["const", "business"] },
  "style": "primary"
}
```

A Back button on the same screen is where `validates` earns its place:

```json
{
  "type": "button",
  "key": "plan_back",
  "label": "Back",
  "outcome": "went_back",
  "validates": false
}
```

`variant`, from the payments host - the first candidate whose condition holds
wins, and the last candidate carries no condition, so it is the default:

```json
{
  "type": "variant",
  "key": "card_notice",
  "nodes": [
    {
      "type": "text",
      "key": "card_notice_declined",
      "condition": "context.last_charge_status == 'declined'",
      "text": "The card on file was declined. Try another one."
    },
    {
      "type": "text",
      "key": "card_notice_expiring",
      "condition": "context.card_expires_within_days < 30",
      "text": "The card on file expires soon."
    },
    {
      "type": "text",
      "key": "card_notice_default",
      "text": "We will charge the card on file."
    }
  ]
}
```

A resolved screen. Take the signup wizard's plan screen, resolved against a
context and a set of responses in which `responses.seats` is `3` and
`responses.first_name` is `Ada`. The conditional hint is shown, the personal-plan
button is hidden because its condition is false, and the business-plan button and
the Back button are shown; every template has been rendered and no condition
survives:

```json
{
  "schema_version": 1,
  "kind": "screens",
  "id": "edoc_signup_screens",
  "metadata": { "name": "Signup screens", "description": "...", "domain": "signup" },
  "screens": [
    {
      "key": "plan",
      "title": "Pick a plan",
      "nodes": [
        { "type": "heading", "key": "plan_heading", "level": 1, "text": "Pick a plan" },
        {
          "type": "text",
          "key": "plan_intro",
          "text": "You can change this later. Nothing is charged today."
        },
        {
          "type": "text_question",
          "key": "seats",
          "label": "How many seats?",
          "placeholder": "1",
          "required": false
        },
        {
          "type": "text",
          "key": "plan_business_hint",
          "text": "More than one seat puts you on the business plan, Ada."
        },
        {
          "type": "button",
          "key": "plan_business",
          "label": "Take the business plan",
          "outcome": "business_chosen",
          "writes": { "responses.plan": ["const", "business"] }
        },
        { "type": "button", "key": "plan_back", "label": "Back", "outcome": "went_back" }
      ]
    }
  ],
  "diagnostics": { "missing_variables": [], "undecidable_conditions": [] }
}
```

---

Recorded 2026-09-14, campaign RF049, bead rd-n0j. Rewritten in place while
still proposed on 2026-09-15, campaign RF049, bead rd-9wd: the record is now
the screens kind's document, the envelope carries an optional `kind`, and the
rules that are screen-only are named as such.

Accepted 2026-09-15, campaign RF049, bead rd-5c3, after a claim-by-claim
reading against `main` at `b790db1` (riddler 0.1.0, published). The code halves
that built what this record decides: `Riddler.Screens.Document.admit/1`,
`validate/1` and the type registry (PR 6), `resolve/2` and `resolve_screen/3`
(PR 7), and `validate_responses/3` and `/4` (PR 8), with the corpus and its
`screens.*` capabilities (PR 9) and the rename and the `kind` envelope field
(PR 15). The paragraph above, recording a rewrite made before this record was
accepted, describes the state this Note ends: the record is accepted from this
date, and a further change to what it decides is an amendment, not an edit in
place.

Four places where this record and the code it describes do not yet line up are
carried as notes by addition rather than as corrections, each with a bead:
the envelope shapes this record states - `schema_version` an integer, `id` a
string, `required` and `validates` booleans, `style` a string - are stated here
and not yet checked by `validate/1`, which is a gap in the code and not in this
record (rd-xxb); the code raises a finding for an unreachable variant candidate,
which this record describes as dead weight without saying it is refused
(rd-d8e); `resolve_screen/3` returns a screen without the diagnostics its
resolution produced, which this record does not decide either way (rd-439); and
`metadata`'s `name`, `description` and `domain` are named here as what the block
carries without a requiredness rule, and none is required in the code (rd-xvv).

## Amendment, 2026-09-17: the screen validated is the screen shown

Status: proposed

This record decided what a screen document is, what a resolved screen is, and
that a set of responses is checked against the resolved screen and nothing
else. That last rule is right. What v1 shipped got it wrong in one place, and
this amendment changes what the record decides there.

### What the record now decides

**Validation resolves the screen against the same root the host resolved
with.** A check on a visitor's responses takes the `context` and the
`responses` the host had in hand when it showed the screen, resolves that
screen against them, and checks what comes back. The empty `context` is not
the contract. A screen resolved for validation and the screen the visitor was
actually shown are the same screen, and a rule stated about one holds of the
other.

The principle this record already carries - that a node a condition hid is a
node the visitor never saw and cannot be held to - is unchanged and is the
reason for the amendment rather than a casualty of it. Hiding is decided by
the host's root, because that is the root the visitor was shown through.

### What v1 did, and why it was wrong

`Riddler.Screens.validate_responses/3` and `/4` built their own root out of
the responses they were handed and an empty `context`
(`lib/riddler/screens.ex`, in the arity-4 body, read at
`e7d76bf07f43e1ff0473d511857e42ff2b770b3e`). The module documentation stated
that as the intent: a screen whose question is conditional on `context` was
said to resolve the way it would for a visitor the host knows nothing about.

The consequence is a false pass, and it is reproducible. Take a screen with
two required text questions: `full_name`, unconditional, and `vat_id`, carrying
the condition `context.is_business == true`. A host resolves that screen under
the root `%{"context" => %{"is_business" => true}, "responses" => %{}}`. Both
questions come back, with clean diagnostics, and the visitor is shown both. The
visitor fills in `full_name`, leaves `vat_id` blank, and submits. Validation
answers `:ok`.

It answers `:ok` because validation did not resolve the screen the visitor saw.
It resolved a different screen, against a root whose `context` is empty, on
which `context.is_business == true` cannot be decided; an undecidable condition
resolves to hidden; and a hidden question cannot fail. The same blank on
`full_name`, which no condition guards, answers
`{:error, [%Riddler.Finding{code: "response.required"}]}` - so the check works,
and only the conditional question slips through it.

The signal that something was wrong was already being produced and thrown away.
Resolving against that internally built root yields
`undecidable_conditions: [%{key: "vat_id", condition: "context.is_business == true"}]`.
`resolve_screen/3` discards the diagnostics it computes into an
underscore-bound tuple element, so validation never sees them. The node was
hidden from the validator, not from the visitor, and nothing on the return
distinguished those two cases.

This was not a gap in the rules this record states. It was a defect, in that
the code did not resolve against the root the record's own reasoning assumes,
and a defect in this record too, in that it did not say which root validation
resolves against and so left the empty one defensible. This amendment says it.

### The surface

The function is named `validate_screen`, and it takes the same root that
`resolve/2` and `resolve_screen/3` take:

    validate_screen(document, screen_key, root, pressed_button_key \\ nil)

`root` carries `context` and `responses`, exactly as it does everywhere else in
this package. The responses being checked are the ones inside that root; there
is no second place to put them.

**`validate_responses/3` and `/4` are removed, not deprecated.** Two reasons,
and the first is the weaker one. A new positional argument cannot be added to
the existing name: `validate_responses/4` already takes a bare guarded `map()`
in the third position, so a root map added as a fourth positional would be
indistinguishable from the pressed button key at the call site, and a root map
added as a third would be indistinguishable from the responses map. The arity
is taken. That forces a new name; it does not by itself force the old name out.

What forces the old name out is that a lenient twin of a sound function invites
exactly the mistake this amendment fixes. `validate_responses/3` is the shorter
call, the one already in the documentation, and the one a host reaches for when
it has responses and has not thought about the root. Keeping it alive under a
deprecation notice keeps the false pass available to every caller who does not
read the notice, and the failure mode is silent: a required question is not
asked about, and the submission is accepted. A deprecation warning is the wrong
instrument for a check that wrongly answers `:ok`. This package is at 0.1.0 and
a breaking change before 1.0 is the cheap moment to make it, so the removal is
the whole change and there is no transitional surface.

This is a breaking change to a public function of 0.1.0. It ships in the next
release cut after it lands.

### An undecidable condition is a finding

When the screen resolved for validation carries a condition that cannot be
decided against the root it was given, validation answers a finding rather than
`:ok`. It does not answer `:ok` by treating the node as hidden, and it does not
answer `:ok` by treating the node as shown.

This follows from the amendment above rather than standing beside it. Once
validation resolves against the host's real root, an undecidable condition
means the root the host handed in does not carry what the document asks about -
which is a defect in the call, not a property of the visitor. Answering `:ok`
would return the package to the behaviour this amendment removes, in a narrower
case. The diagnostic already exists at the point it is currently discarded; the
change is to surface it rather than to compute it.

The code half is a separate bead (`rd-4a2` for the surface, and the finding
itself behind it); this record decides that the behaviour is a finding and
leaves the finding's code to the bead that raises it. This record does not
introduce a finding-code registry: `Riddler.Finding` carries a `code` string and
no enumeration, and nothing here changes that.

### A single-screen call returns its diagnostics

This record's foot note carried an open question: whether `resolve_screen/3`
returns the screen's diagnostics beside the screen, which the record did not
decide either way (`rd-439`). The question can no longer be deferred, because
the validation surface this amendment decides is itself a single-screen call
that now has diagnostics it must either return or drop, and dropping them is
what produced the defect above.

**It returns them.** A single-screen call answers with the screen and the
diagnostics its resolution produced, so a caller is never handed a screen whose
resolution reported something without being handed the report. `resolve_screen/3`
answers `{:ok, screen, diagnostics}`, with `diagnostics` the same shape
`resolve/2` already carries on its resolved document: `missing_variables` and
`undecidable_conditions`.

**This is a second breaking change in the same release, and it is recorded here
so that it is not discovered as a surprise.** `resolve_screen/3` is public, is
documented with executable examples that match on `{:ok, screen}`, is cited by
ADR-0001 as the call that resolves one named screen, and is called inside this
package by the corpus runner. Every one of those changes with the return. The
alternative - leaving `resolve_screen/3` alone and giving only the new
validation call its diagnostics - was rejected because it leaves two
single-screen calls in one module disagreeing about whether a caller is told
what resolution found, and that disagreement is the shape of the defect this
amendment exists to close.

### What is unchanged

The document, the node vocabulary, the resolved shape, the `writes` and
`outcome` fields, the lenient template rendering, the `missing_variables` and
`undecidable_conditions` diagnostics and what goes in them, and the rule that
checks run over the resolved screen and nothing else. `resolve/2` keeps its
arity and its return. Earlier prose in this record and in ADR-0001 that names
`validate_responses` describes what v1 did and stays as the historical record
of it.

---

Noted 2026-09-17, campaign RF051, beads rd-gwn, rd-d8e, rd-xvv and rd-xva.
Four notes by addition, each read against `main` at `7a2dd8f`. They record
what this record was silent on; none of them changes what it decides, and
none of them bears on the amendment above.

**A decoded document reaches the runtime atom-keyed, except `metadata`.** The
Typespecs section above writes `metadata` as `%{optional(String.t()) =>
term()}` while a screen and a node are atom-keyed, and never says which of
those two forms a host's decoded JSON arrives in. Both do, and the boundary
is `admit/1`. What a host hands in is the decoded JSON map, string keys
throughout, as `Jason.decode!/1` gives it; what the rest of the package reads
is the struct `admit/1` builds (`lib/riddler/screens/document.ex`, `admit/1`,
read at `7a2dd8f`). In that struct the envelope fields, every screen
(`%{key: ..., title: ..., nodes: [...]}`) and every node are atom-keyed, and
`metadata` alone is carried through with its string keys exactly as written.
The reason for the exception is the envelope rule above that `metadata` is an
open map: a host may put what it likes beside `name`, `description` and
`domain`, so its keys are not drawn from any vocabulary this package knows,
and string keys are the only form that can hold them without this package
turning host input into atoms. The typespec is right as it stands; this note
says which side of `admit/1` each form lives on. The same reasoning is why no
unrecognized node field becomes an atom either: `admit/1` copies a field onto
a node only when that field's own name, as a string, is a key of the raw
node, so every atom in an admitted node comes from this package's vocabulary
and none from the document.

**An unconditional variant candidate that is not last is an admit finding.**
The variant rule above says such a candidate makes every candidate after it
dead and stops there, while the empty variant beside it is explicitly a
finding. This note decides that the unreachable case is one too, on the
reasoning the Context already gives: the loss is silent, and a vocabulary
that can lose part of a document without saying so is what this record is
written against. The code is `document.unreachable_variant_candidate`, one
finding per unconditional candidate that is not last, carrying the variant's
own key as the node key and `nodes` as the field, with the buried candidate
named in the message - the variant is the node the author has to fix. It is
raised by `Riddler.Screens.Type.Variant.validate/1`
(`lib/riddler/screens/type/variant.ex`, the private `unreachable/2`, read at
`7a2dd8f`), listed with the other codes in `Riddler.Screens.Document`'s
moduledoc (`lib/riddler/screens/document.ex`, read at `7a2dd8f`), and pinned
by a test and by the corpus case "An unconditional candidate that is not last
is refused, because it buries every candidate after it"
(`corpus/screens/admit.json`). The record and the code already agreed on the
behaviour; what this note closes is that the record did not say it.

**None of `metadata`'s `name`, `description` and `domain` is required.** The
envelope rule above names the three as what the block carries and types them
as strings without stating a requiredness rule, which leaves a reader free to
read the naming as a requirement. It is not one. A document with no
`metadata` at all is admitted, and so is one whose `metadata` carries none of
the three: `admit/1` takes the block whole when it is a map and substitutes
the empty map when it is absent (`lib/riddler/screens/document.ex`,
`admit_metadata/1`, read at `7a2dd8f`), and `validate/1` raises no finding
about `metadata`, having no check over the block at all. The three names are
a convention this record offers so that hosts and editors spell one idea one
way, not a schema this package enforces; a host that needs one of them
present enforces that itself. This note decides the open reading rather than
merely reporting the code: requiring any of the three would be a new refusal
of documents 0.1.0 admits, and the reason this record gives for naming them -
so that an editor has something to offer - is served without one.

**A node field this version does not know is dropped at admit, with no
finding.** This record enumerates each type's fields and is silent on what
becomes of a field outside that enumeration on a node whose `type` is known.
It is dropped: `admit/1` copies the common fields and the fields the type's
own `fields/0` names, and nothing else reaches the admitted node
(`lib/riddler/screens/document.ex`, `admit_typed/3` and the private `take/2`,
read at `7a2dd8f`); `validate/1` raises nothing about it. That is the narrow
counterpart of the loud refusal of an unknown `type` rather than an exception
to it: an unknown type means this package cannot say what the node is, while
an unknown field on a known type is a field this package can say is no part
of the type. Dropping it rather than carrying it is also what keeps host
input out of the atom table. `metadata` is the declared place for what a host
wants to keep beside the vocabulary. Whether such a field should in addition
raise a finding is left open here exactly as it was before this note: naming
a code for it would change what this record decides, and that is an
amendment's work, not a note's.

`answer_options` is that rule's likeliest case, and this note names it. While
the select question types are unbuilt, a document carrying `answer_options` on
a `text_question` is admitted and the field is dropped, with no finding: the
reservation above reserves the spelling, not a behaviour. A host authoring
choices before those types exist is authoring something this version will not
show and will not mention.

The same enumeration under-names `text_question` in one further way, which
this note closes. That type also admits `pattern`, `min` and `max`
(`lib/riddler/screens/type/text_question.ex`, `fields/0`, read at `7a2dd8f`).
They are parameters of the validation formats the rule above delegates to -
`pattern` is the expression the `pattern` format holds a response to, and
`min` and `max` are the bounds the `integer` and `number` formats hold one
between - and each is read only by the format that owns it, so a question
declaring one without the format that reads it declares something nothing
consults.

---

Noted 2026-09-17, campaign RF051, bead rd-xxb. One note by addition, read
against `main` at `342c790`. It records the codes that check the envelope and
boolean shapes this record already states; it changes nothing this record
decides, and it does not bear on the amendment above.

**The envelope and boolean shapes this record states are checked, one code
each, and only where the document carries the field.** The Decision above
types `schema_version` as an integer and `1` in this version, `id` as a string
that names the document, a screen's `title` as a string, `required` and
`validates` as booleans, and `style` as a string from an open set the renderer
owns; the Typespecs section writes the first three as `pos_integer()` and
`String.t()`. v1 carried every one of them from the decoded JSON onto the
admitted struct without reading it, so a document declaring a `schema_version`
of 2, an `id` of 7 or a screen titled with a number validated clean. It no
longer does. The codes are `document.invalid_schema_version` for a
`schema_version` that is not the one this package implements,
`document.invalid_id` for an `id` that is not a string,
`document.invalid_title` for a screen `title` that is not a string,
`document.invalid_required` for a question's `required` that is not a boolean,
`document.invalid_validates` for a button's `validates` that is not a boolean,
and `document.invalid_style` for a button's `style` that is not a string. The
first two carry the field and no node key, because the envelope is the
document's and not any one node's; `document.invalid_title` carries the
screen's key, because the screen is what the author has to fix; the other
three carry the node's key. Each check is added by this bead's own commit, so
none of them is citable at the `342c790` this note was read against: the
envelope and title checks are `Riddler.Screens.Document`'s (the private
`envelope_findings/1` and `title_findings/1` in
`lib/riddler/screens/document.ex`), and the three field checks belong to the
types that name the fields (the private `required_findings/1` in
`lib/riddler/screens/type/text_question.ex`, and the private
`validates_findings/1` and `style_findings/1` in
`lib/riddler/screens/type/button.ex`). That is the same division that already
puts a heading's level range in the heading and a format's name in the
question (`lib/riddler/screens/type/heading.ex`, `validate/1`, and
`lib/riddler/screens/type/text_question.ex`, the `format` branch of
`validate/1`, both read at `342c790`).

**Three passages state the schema version, and the check took the narrowest
of them.** The Decision above says `schema_version` is "an integer, `1` in
this version"; the Typespecs section writes `pos_integer()`; and the gap Note
above, in the sentence that names this bead, lists "the envelope shapes this
record states - `schema_version` an integer, `id` a string, `required` and
`validates` booleans, `style` a string - are stated here and not yet checked
by `validate/1`". Two of those three say only that it is an integer.
`document.invalid_schema_version` implements the narrowest reading: an integer
other than 1 carries the finding. **The implementation therefore went
narrower than the sentence that commissioned it**, and this note records that
rather than leaving a reader to discover it from the code. The Decision is
what governs where the three differ, on the Typespecs section's own terms - it
opens by calling itself "Minimal, and a contract for the code half rather than
a second source of truth" - and the gap Note's list is a summary of what was
unchecked rather than a fourth statement of the contract. A version that is
the runtime for a second schema version widens the check by amending the
Decision, which is the passage that decides. That same list names five of the
six shapes checked here; a screen's `title` is the sixth, and it comes from
the screen rule in the Decision and from the `screen` type in the Typespecs
rather than from that list.

The schema is the fourth reading and it is wider still: it types
`schema_version` as `integer` with no `const`
(`priv/schemas/element-document.schema.json`, read at `342c790`), so a
document declaring 2 is schema-valid and carries a finding here. That is not a
disagreement between the schema and the runtime but the thing the schema's own
description already says, that a validator holding it and a runtime admitting
the same value agree because schema-valid means **admitted** - not that an
admitted document is free of findings. `kind` is the standing precedent: an
open string in the schema, enumerated by the runtime, and a kind no runtime
knows is schema-valid and a finding.

**Each is a shape check and none of them is a requiredness check.** A field
this record types but the document omits raises nothing: the schema requires
`screens` of a document and `nodes` of a screen and nothing else
(`priv/schemas/element-document.schema.json`, read at `342c790`), so a
document with no `schema_version`, no `id` or no screen `title` is a document
this version admits and validates clean, exactly as before. That is the same
reading the note above takes for `metadata`'s three names, and for the same
reason: requiring a field this record names would be a new refusal of
documents 0.1.0 admits, which is an amendment's work and not a note's; the
question is carried as rd-5v2. One
consequence is worth stating, because the struct cannot see it and because it
is not symmetrical across the six. On the envelope and on the screen an
omitted field and a field written as JSON `null` both reach the runtime as
`nil`, so a `null` `schema_version`, `id` or `title` reads as an absent one
and raises nothing, while the schema above types each of the three and refuses
the null. The three node fields answer the other way: `required`, `validates`
and `style` are read with `Map.fetch/2` from a node that carries only the
fields it declared, so an explicit `null` arrives as a value that is present
and is neither a boolean nor a string, and each raises its own finding. The
same `null` is therefore refused on three of the six fields and accepted on
the other three in one call - probed on all six rather than reasoned about.
Which of the two answers should hold for all of them is carried as rd-6kl and
is not settled here, because making them agree either adds a refusal or
removes one. A host that wants a field present enforces that itself, or holds
the document to the schema.

**`style` is checked for being a string and for nothing more.** The rule above
that a style this package does not recognize is passed through rather than
refused is unchanged: `primary` and `secondary` are named there so that a host
has something to render, and any other name reaches the renderer untouched.
What the check adds is that the name is a name - a renderer handed a number
has nothing to look up - and it is the narrow counterpart of the open set
rather than an exception to it.

The Consequences section above has to be read with this note beside it. It
says that renderers own `style` and that "this package neither validates a
style value nor ships a default for one", and from this note's date that
sentence is true of only half of the distinction drawn here: **which** style a
value names is still never validated - no name is refused, no default is
supplied, and `primary` and `secondary` stay offers rather than an enumeration
- while **that** the value is a name at all now is. A reader arriving at that
sentence should read "validates a style value" as "judges which style it is",
which is what it was written to promise and what the check leaves untouched.
The gap Note above already authorizes the check, by listing `style` a string
among the shapes this record states and the code did not check and naming this
bead for it; what it did not do, and what this paragraph does, is say that the
Consequences sentence reads the other way.

**Nothing in the conformance corpus changes.** Every case in the three
screens capability files was enumerated field by field - 71 of them, 70 with
an object for a document and one whose input is not an object at all. All 70
declare `schema_version` 1 and a string `id`, every screen title in them is a
string, and not one `required`, `validates` or `style` in them is off-shape,
so no case's stated answer moves and the case counts are untouched. The corpus gains no case here. The shapes are pinned by the suite
instead, by seven tests this bead's commit adds to
`test/riddler/screens/document_test.exs`: one per shape, each red before the
check it names existed, plus one that holds the checks to saying nothing about
a field the document omits.

---

## Amendment, 2026-09-17: an uncompilable pattern is the document's defect

Status: proposed

This record decided which string fields of a document this package compiles,
and it decided that a validation format's own check belongs to response
validation. A `pattern` sits between those two rules, and v1 read it as
entirely the second one's. This amendment changes what the record decides
about one half of it.

### What the record now decides

**A `pattern` a question declares for the `pattern` format is an expression
the document is held to being compilable, and one that is not is refused at
admit, as `document.invalid_pattern` carrying the field `pattern` and the
node's key.** Refused at admit means an admit-time finding and not a refusal
to admit: `admit/1` is unchanged, a document carrying such a pattern is still
a document, and the finding comes from `validate/1`. That is what this record
means by an admit finding throughout, and it is what the schema says of
itself - everything a document can be wrong about "is a finding a runtime
raises against an admitted document, not a reason the value is not a
document", so that schema-valid means admitted
(`priv/schemas/element-document.schema.json`, read at `27f9d91`).

**Response validation no longer reports that case.** A defect reported from
two layers is worse than one reported late, and the response was never what
was wrong: nothing a visitor could type satisfies an expression that does not
compile.

**The check follows the format, not the field.** It raises only where the
question declares `format` as `pattern`. A `pattern` on a question that asks
for another format, or for none, stays exactly what the note below already
says it is - a field nothing consults - and carries no finding at either
layer. This amendment deliberately decides the narrower thing: it moves
which layer refuses an expression the `pattern` format cannot use, and it
does not widen which patterns are looked at.

**The shape check is part of it, and is named here rather than left to the
code.** A `pattern` that is not a string at all - a number, a boolean, or a
JSON `null`, which reaches an admitted node as `nil` - is not an expression
either, and it carries the same code and the same field. One code covers both
because they are one defect from the document's side: the question declares
something nothing can compile. This is the same kind of shape check the note
below names one code each for, and it is stated in the same way, so that a
reader learns it from the record rather than from a clause of the
implementation.

**One case stays with response validation.** A question that declares
`format` as `pattern` and declares no `pattern` at all. There is no
expression for the document check to read, so it raises nothing, and response
validation answers `response.format` with the field `pattern` - a response
cannot be in a form the question never states. Whether a format declared
without the parameter it reads should itself be a document finding is a
question this amendment does not decide.

### Why an amendment and not a note

Because this reverses the layer the Decision assigns, and because it refuses
documents this version admitted. Three passages have to be read to see that,
and the first attempt at this change rested on two of them misread; they are
set out plainly here so that the next reader does not have to rediscover it.

**The record does not say a `pattern` is a regular expression.** The phrase
appears nowhere in it. What it says is that "`pattern` is the expression the
`pattern` format holds a response to", that `pattern`, `min` and `max` "are
parameters of the validation formats the rule above delegates to", and that
"each is read only by the format that owns it, so a question declaring one
without the format that reads it declares something nothing consults" (the
note below, read at `27f9d91`). Every clause of that places the field on the
**format's** side and says nothing about this package compiling anything at
admit. The regular-expression wording is the code's, in
`Riddler.Screens.Type.TextQuestion`'s own documentation, and a sentence in a
moduledoc is not this record deciding something.

**The templates rule does not extend to it, and its next sentence says so.**
That rule reads in full: "`text`, `label` and `placeholder` are templates in
the ADR-0003 subset. They are compiled by the same code an editor calls, so a
template this package refuses is refused at admit time, with the node's key on
the finding. **Any other string field in a document is literal text.**" A
`pattern` is another string field. Read whole, that passage does not license
treating a `pattern` as compiled-at-admit - it classes it as literal text as
far as the document is concerned, which is the opposite. So this amendment
does not extend an existing rule by analogy. It carves a third kind of string
out of that sentence: not a template, not literal text, but an expression one
format compiles, which the document is held to having written compilably. The
templates rule stands unchanged for the three fields it names, and "any other
string field is literal text" now has this one stated exception.

**And the Consequences section assigns the other side to response
validation:** it commissions the half that builds
`Riddler.Screens.validate_responses/3` "and its arity-4 form, which is where
`required` and `format` are enforced". The compilability of a `pattern` was
part of enforcing `format` there, and this amendment takes it out. v1
implemented exactly what that sentence said: a question whose `pattern` was
`[0-9` validated clean as a document and answered `response.format` with the
field `pattern` against whatever the visitor typed
(`lib/riddler/screens/validation.ex`, the private `pattern/2` and
`pattern_finding/1`, read at `27f9d91`).

**The test the record sets for itself is met.** The note below, deciding a
narrower question, states it: requiring a field this record names "would be a
new refusal of documents 0.1.0 admits", and naming a code for a question this
record leaves open "would change what this record decides, and that is an
amendment's work, not a note's". A document whose pattern does not compile
validated clean in 0.1.0 and now carries a finding. That is a new refusal of
a document this version admitted, and it changes which layer the record
assigns a check to. It is an amendment's work on both counts, and it lands at
proposed.

### What is unchanged

A compilable `pattern` is enforced at response validation exactly as before,
against the whole response, anchored at both ends. `admit/1` refuses nothing
new. No other format's parameters are read at admit: `min` and `max` are
untouched, and a question declaring them without the formats that read them
still declares something nothing consults. The fixture this record is held to
still admits and validates with zero findings. Nothing about
`resolve/2`, the resolved document, or the diagnostics it carries is touched.

### Consequences

The check is `text_question`'s, beside the `format` and `required` checks and
for the reason the note below gives for that division - the type that names
the field owns the check on it. It compiles through the same function the
format compiles through rather than carrying a second copy of the anchors,
because a document check holding an expression to anchors the format did not
apply would admit a pattern the format cannot use, or refuse one it can, which
is this defect reintroduced from the other end. That function is in
`Riddler.Screens.Validation`, which is `@moduledoc false` and no part of this
package's surface, as its own documentation says. Both are added by this
bead's own commit and so are citable at no earlier SHA.

**One conformance case changes side, and the corpus gains none.** The response
validation corpus stated `ok: false` with a `response.format` finding for a
checkout document whose `card_last_four` pattern was `[0-9`. That capability
now answers `ok: true` for it, so the case states that and its name says why.
No case is added and no case count moves. A case stating
`document.invalid_pattern` against the admit capability would pin the other
half of this boundary and is left for the corpus pass.
