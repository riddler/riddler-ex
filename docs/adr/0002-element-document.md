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

Status: accepted (2026-09-18)

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

Status: accepted (2026-09-18)

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
for another format, or for none, stays exactly what the note above already
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
above names one code each for, and it is stated in the same way, so that a
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
appears nowhere in what this record decided, nor in any note on it; once this
amendment lands it occurs in the record exactly once, in the sentence you are
reading, which is a report of the phrase and not a use of it. What the record
says is that "`pattern` is the expression the `pattern` format holds a
response to", that `pattern`, `min` and `max` "are
parameters of the validation formats the rule above delegates to", and that
"each is read only by the format that owns it, so a question declaring one
without the format that reads it declares something nothing consults" (the
note above, read at `27f9d91`). Every clause of that places the field on the
**format's** side and says nothing about this package compiling anything at
admit. The regular-expression wording is the code's, and at the SHA cited
above it is in two places rather than one: the moduledoc of
`Riddler.Screens.Type.TextQuestion`, and - the more telling of the two - the
text of the finding response validation raised, which is what a host's caller
actually read (`lib/riddler/screens/validation.ex`, the private
`pattern_finding/1`, read at `27f9d91`). Neither is this record deciding
anything: a sentence in a moduledoc and a sentence in a runtime message are
both the code describing itself, and the second is the code describing itself
to a visitor's host. That second occurrence is gone as this bead leaves the
tree - the same commit reworded that message, because after the move it only
ever answers a question declaring no pattern at all - so a reader looking for
it reads it at the SHA cited here rather than on the current default branch.

**The templates rule does not extend to it, and its next sentence says so.**
That rule reads in full, word for word, with the record's own bold on the
first sentence and the bold on the last sentence mine: "**`text`, `label` and
`placeholder` are templates in the ADR-0003 subset.** They are compiled by the
same code an editor calls, so a template this package refuses is refused at
admit time, with the node's key on the finding. **Any other string field in a
document is literal text.**" The record emphasises the rule; the emphasis
added here is on its limit, which is the clause the first attempt at this
change quoted around. A
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

**The test the record sets for itself is met.** The note above, deciding a
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
for the reason the note above gives for that division - the type that names
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

---

Noted 2026-09-17, campaign RF051, bead rd-mnp. One note by addition, read
against `main` at `4208433`. It re-labels three of this record's own citations
because the change that carries this note renames the file they cite; it
records nothing new about the document, changes nothing this record
decides, and changes nothing either amendment above decides.

**The document schema is cited three times above under the name it no longer
carries, and each citation is still sound.** The file those three cite was
named `priv/schemas/element-document.schema.json`, and the change that carries
this note renames it to `priv/schemas/screen-document.schema.json`. The rename
is recorded as a rename at full similarity: the schema's content is untouched
by it, so each SHA those citations name still reads exactly what they say it
reads, under the file's earlier name. From this change onward the path to read
it at is `priv/schemas/screen-document.schema.json`. The three, each located by
the passage it sits in rather than by a line:

- In the passage above beginning "The schema is the fourth reading and it is
  wider still", the citation "(`priv/schemas/element-document.schema.json`,
  read at `342c790`)" supports its reading that the schema "types
  `schema_version` as `integer` with no `const`".
- In the passage above headed "**Each is a shape check and none of them is a
  requiredness check.**", the citation
  "(`priv/schemas/element-document.schema.json`, read at `342c790`)" supports
  its reading that "the schema requires `screens` of a document and `nodes` of
  a screen and nothing else".
- In the amendment above titled "an uncompilable pattern is the document's
  defect", under "What the record now decides", the citation
  "(`priv/schemas/element-document.schema.json`, read at `27f9d91`)" supports
  its reading of what "the schema says of itself": the schema's own
  description, which that passage quotes as "is a finding a runtime raises
  against an admitted document, not a reason the value is not a document",
  and the conclusion that passage draws from it in its own words, that
  schema-valid means admitted.

Each reading stands as written. What moves is the path, and only the path: a
reader following any of the three at a tree carrying this note reads the same
schema at `priv/schemas/screen-document.schema.json`, and at `342c790` or
`27f9d91` reads it at the name those SHAs carry.

**Two other references to the earlier name are correct as they stand and are
deliberately untouched**, by both this note and the change that carries it:
this record's own filename, which is how a record is cited and is fixed by its
number, and the row that links to it from the index in `docs/adr/README.md`.
Neither names the schema; both name this record.

---

## Amendment, 2026-09-17: the per-button opt-out covers an undecidable condition

Status: accepted (2026-09-18)

Two amendments sit above this one. Every reference here to "the amendment
above" means the first of them, headed "the screen validated is the screen
shown"; the second, on an uncompilable pattern, is named in full where it is
cited.

The amendment above decides that a condition the root could not decide is a
finding rather than `:ok`. It states that rule without qualification and it
never names the per-button opt-out, so it left open what a press that declares
it does not validate answers for such a screen. This amendment decides that:
the opt-out covers it.

### What the record now decides

**A button declaring `validates` as `false` answers `:ok` for the screen it
submits even when that screen carries a condition the root could not decide.**
The finding the amendment above introduces is raised where the pressed button
validates. A press through a button that says nothing, and a press through a
key naming no button on the resolved screen, both still report it.

**One narrower case is named here rather than claimed away, and this amendment
decides nothing about it.** `validates` is read from the button the pressed
key names on the resolved screen, and a call naming no button passes a pressed
key of `nil`. A button node carrying `validates` as `false` and no `key` at all
therefore answers to that `nil`: a call naming no button is treated as a press
through it, and the screen answers `:ok`. This version admits such a document
and separately reports it as defective, because a button carries a key
(`document.invalid_key`, `lib/riddler/screens/document.ex`, read at
`4208433d6f318acd00870cf2b5929cb2ccd97a69`), so the case arises only for a
document a host has already been told is wrong, and nothing here is the reason
it behaves that way. Whether a keyless button should be able to opt out at all
is left open exactly as this amendment found it.

The Decision above already says what the opt-out is for: a button "may carry
`validates`, a boolean defaulting to true: a button that submits a screen
validates that screen's responses first, and the opt-out is what lets a Back
button leave a half-filled screen without an error." That sentence is about
navigation. A visitor pressing Back is leaving the screen, not submitting it,
and there is nothing yet to be right or wrong about.

### Why the opt-out wins here

The amendment above gives its own reason for the finding, and read closely that
reason is what carves this case out rather than what swallows it. It says:
"Once validation resolves against the host's real root, an undecidable
condition means the root the host handed in does not carry what the document
asks about - which is a defect in the call, not a property of the visitor."

A defect in the call is the host's. A Back press is the visitor's, and it is
their navigation rather than their submission. Holding a visitor at a screen
they are trying to leave, in order to report a mistake in the host's root,
charges the wrong party for it: the visitor cannot fix the root, cannot see the
finding, and has not claimed that anything on the screen is finished. The host
still learns of the defect, from the same finding, the moment a press that does
validate arrives - and from `resolve/2` and `resolve_screen/3`, which report
`undecidable_conditions` in their diagnostics on every call whatever is pressed.
Nothing is hidden by this; one door out of the screen stops being blocked.

The reading the other way is defensible and was implemented first. The
amendment's rule is stated flat; an undecidable condition is not something a
visitor typed their way into; and the sentence that follows the one quoted
above presses the point - "Answering `:ok` would return the package to the
behaviour this amendment removes, in a narrower case." What decides between
the two readings is what that removed behaviour was: a *submission accepted
unchecked*. A non-validating press accepts no submission, so answering `:ok`
to one does not return the package to it. That is the case the amendment's
reasoning does not reach, and the record above neither reached it nor said so.

It did not say so anywhere else either. The amendment above names `validates`
nowhere and the opt-out nowhere. A button reaches it twice and both times as
the `pressed_button_key` argument of the surface it declares - once in the
signature and once in the argument about which positions are taken - which is
an argument's name and not a rule about what pressing one does. Its
"What is unchanged" list - "The document, the node vocabulary, the resolved
shape, the `writes` and `outcome` fields, the lenient template rendering, the
`missing_variables` and `undecidable_conditions` diagnostics and what goes in
them, and the rule that checks run over the resolved screen and nothing else" -
does not name the opt-out among what it preserves. So the question was open in
both directions rather than decided in one, which is the condition this
amendment exists to end.

### Why an amendment and not a note

Because it changes what this record decides, which is the test this record
states for itself. The note above that decides what becomes of a node field
this version does not know declines to decide whether such a field should also
raise a finding, and gives its reason in these words: "naming a code for it
would change what this record decides, and that is an amendment's work, not a
note's." The operative clause is *changes what this record decides*, and this
entry does: the rule stated above answers a call one way, and this entry
answers the same call another.

**Deciding something the record left open is not by itself that test, and this
record refutes the confusion by example.** The `metadata` requiredness note
says of itself "This note decides the open reading rather than merely reporting
the code" - and remains a note. It sits in the same note block as the sentence
just quoted, at the end of the paragraph immediately before it, so a reader
following that citation lands beside it. It can remain a note because its
decided reading takes nothing away, and so changes nothing this record had
decided. Deciding an open question and changing what the record decides come
apart, and it is the second that governs.

The provenance lines the note blocks carry say the same thing from the other
side, each in its own words. The four-note block: they "record what this record
was silent on; none of them changes what it decides, and none of them bears on
the amendment above." The single-note block, of its own note: "it changes
nothing this record decides, and it does not bear on the amendment above."
This entry fails the operative clause in both spellings twice over. It changes
what the record decides, and it bears on the amendment above as directly as an
entry can, being a qualification of one of its rules.

The other test this record uses points the other way and is not the governing
one. The amendment on an uncompilable pattern asks whether a change is "a new
refusal of documents 0.1.0 admits". This is not: it takes nothing away that 0.1.0
allowed, and restores for one press exactly the `:ok` that 0.1.0 always
answered there. That test is a sufficient reason for an amendment, not a
necessary one, and a change can fail it and still be an amendment's work.

Two further reasons, both practical. This qualifies a rule stated by an
amendment that is itself at `proposed`; a note cannot be accepted or rejected
with the text it qualifies, while a second amendment beside the first can be
read and ruled on as one. And what it settles is a behaviour a host writes code
against, not a consequence of a rule already decided - the rule above and this
one give a different answer to the same call.

### What is unchanged

Everything the amendment above lists as unchanged, and the amendment itself
apart from the one qualification stated here: a validating press still answers
the finding, `missing_variables` still becomes no finding, a condition the root
*decides* false still hides its node silently, and the order of the findings is
untouched. `validates` keeps its default of true, its meaning, and its
admit-time shape check. `resolve/2` and `resolve_screen/3` are not touched *by
this amendment* - `resolve_screen/3`'s return is changed by the amendment
above, which states that and says why - and their diagnostics report an
undecidable condition whatever button is pressed, because no button is pressed
at resolution.

**One edge stays exactly where the amendment above left it, and this amendment
decides nothing about it.** A button's own `condition` may be the undecidable
one. Resolution then drops that button from the screen, so nothing on the
resolved screen declares `validates` at all, and the press falls to the
default: it validates, and the finding is raised. That the press validates is
what the `@doc` on `Riddler.Screens.validate_screen/4` already states for any
key naming no button on the resolved screen; that the finding then follows is
this amendment's rule applied to it, not something that `@doc` says. Neither is
changed here. Whether a press through a
button hidden by its own undecidable condition should reach the opt-out this
amendment carves out is a question this amendment does not answer.

**The public documentation of the opt-out needed no change.** The `@doc` on
`Riddler.Screens.validate_screen/4` (`lib/riddler/screens.ex`, read at
`4208433d6f318acd00870cf2b5929cb2ccd97a69`) and the matching passage in
`README.md` (read at the same SHA) both already say that a button declaring
`false` answers `:ok` without running a check, which is what lets a Back button
leave a half-filled screen. Under the first implementation of the amendment
above that sentence had become false. The code moving to what this amendment
decides is what makes it true again, so neither sentence is edited by the
commit this amendment lands in.

**The conformance corpus gains nothing and loses nothing here.** The one case
the finding's bead adds to `corpus/screens/validate_responses.json` presses no
button, so its stated answer is what this amendment leaves it. A case pressing
a non-validating button on a screen with an undecidable condition would pin
this amendment from the corpus side and is left for the corpus pass.

The code half is the same bead as the finding itself, whose commit is the one
that adds both the entry point taking the diagnostics behind the opt-out check
and the pair of tests pinning the two halves against one document, so neither
is citable at any earlier SHA. The behaviour is in `Riddler.Screens.Validation`,
which is `@moduledoc false` and no part of this package's surface, reached from
`Riddler.Screens.validate_screen/4` in `lib/riddler/screens.ex`.

---

Noted 2026-09-18. The three amendments above move from `proposed` to
`accepted`, each Status line flipped in place and nothing else in them
reworded. They are, in the order they appear: "the screen validated is the
screen shown", "an uncompilable pattern is the document's defect", and "the
per-button opt-out covers an undecidable condition".

Each was verified against `main` at `015f209` before the flip rather than
against the tree it was written on, because an amendment is accepted for what
the package does now. What was read, by anchor:

- The validation surface is `Riddler.Screens.validate_screen/3` and `/4`, taking
  `(document, screen_key, root, pressed_button_key \\ nil)` and resolving the
  screen against the root it is handed (`lib/riddler/screens.ex`, the two
  `validate_screen` clauses and their `@spec`s). `validate_responses/3` and `/4`
  are gone from the public surface; the name survives only as the corpus
  capability `screens.validate_responses` and its case file, which name a
  capability rather than a function.
- `resolve_screen/3` answers `{:ok, screen, diagnostics}`
  (`lib/riddler/screens.ex`, its `@spec` and body), so the single-screen call
  returns the diagnostics its resolution produced.
- An undecidable condition is the finding `response.undecidable` on the node
  carrying it, with `field` `"condition"`, reported wherever the pressed button
  validates (`lib/riddler/screens/validation.ex`).
- A `pattern` a question declares for the `pattern` format is held to being
  compilable at the document layer, as `document.invalid_pattern` on the field
  `pattern` and the node's key, and only where that format is declared
  (`lib/riddler/screens/type/text_question.ex`, `pattern_findings/1` and the
  private clauses under it). Response validation no longer reports that case and
  raises only for a question declaring the format and no pattern at all
  (`lib/riddler/screens/validation.ex`, the private `unreadable_pattern/1`). The
  shape check is the same code: a `pattern` that is not a string compiles to
  `:error` through the one compiler both layers share.
- A button declaring `validates` as `false` answers `:ok` for a screen carrying
  an undecidable condition, and a button that says nothing, or a key naming no
  button, still reports the finding (`lib/riddler/screens/validation.ex`, the
  pressed-button lookup defaulting `validates` to true). The keyless-button edge
  the third amendment names is still separately reported as
  `document.invalid_key` (`lib/riddler/screens/document.ex`).
- The `@doc` on `validate_screen/4` and the matching passage in `README.md` both
  still state the opt-out as the amendments say they do, and the schema's own
  description still reads as the second amendment quotes it, under the name the
  note above gives it, `priv/schemas/screen-document.schema.json`.

Two deferrals the amendments recorded have since been taken up or still stand,
and neither changes what is accepted here. The corpus case pair the third
amendment left "for the corpus pass" - a non-validating press and a validating
press on one screen carrying a condition the root cannot decide - is in
`corpus/screens/validate_responses.json`, stating exactly the rule that
amendment decides. The admit-side case for `document.invalid_pattern` that the
second amendment left for the same pass is not there yet; the response-validation
case whose pattern is `[0-9` states `ok: true`, as that amendment says it now
must.

One reading is recorded because it could have gone the other way. A separate
open defect has `Riddler.Template.compile/1` raising on some malformed input,
which sits under ADR-0003's compile contract. It does not bear on the second
amendment: the expression that amendment holds a document to is the `pattern`
format's, compiled by the one private regular-expression compiler in
`Riddler.Screens.Validation`, which answers `:error` rather than raising and
never reaches the template compiler. The two compile paths are distinct, and the
amendment's claim survives.

## Amendment, 2026-09-18: a keyless button cannot opt out, and a call naming no button never does

Status: proposed

Recorded 2026-09-18, campaign RF055, bead rd-ncs. The amendment above, on the
per-button opt-out, names one case and declines it in these words: "Whether a
keyless button should be able to opt out at all is left open exactly as this
amendment found it." This amendment closes that question, and closes it the
other way from the behaviour the package ships. Every cite below is read at
`543f35275f05f735a34e88777201fa2e4beb1016`. The code half is a separate bead
and a separate commit; nothing here is citable from `lib/` until it lands.

### What the record now decides

**`validates` as `false` is meaningful only on a button that carries a key,
and only to a press that names that key.** The opt-out is a property of a
press, not of a node sitting on a screen. A button with no key cannot opt out
of anything, because nothing can name it and so no press can arrive through
it.

**`Riddler.Screens.validate_screen/3` never opts out.** It names no pressed
button, so there is no press to read `validates` from, and it validates the
resolved screen in full. The same holds of `validate_screen/4` handed a
pressed key of `nil`: an absent pressed key names no button, whatever nodes
the screen carries.

What the package does today is the other reading, and this amendment is the
reason to change it. `Riddler.Screens.Validation` finds the pressed button with
`node[:type] == "button" and node[:key] == key`
(`lib/riddler/screens/validation.ex:101`, the private `button?/2`, read at
`543f35275f05f735a34e88777201fa2e4beb1016`), and the arity-3 clause passes a
pressed key of `nil` (`lib/riddler/screens.ex:305` and `:306`, read at the same
SHA). A button node carrying no `key` at all reads `node[:key]` as `nil` too,
so the two absences compare equal, the private `opted_out?/2`
(`lib/riddler/screens/validation.ex:94` through `:99`, same SHA) answers true,
and the call answers `:ok` with every finding on the screen silenced at once
(`lib/riddler/screens/validation.ex:39` through `:41`, same SHA, where the
opt-out stands in front of the checks).

**The case is narrower than a document carrying such a button, and the rule
above is what it is measured against rather than a count of the calls it
reaches.** `opted_out?/2` is handed one resolved screen, so a validation of any
other screen of the same document is untouched. It takes the *first* node the
match finds, so a keyless button earlier on the screen carrying the default
hides a later one declaring `false`. And a button whose own condition the root
decides false is dropped from the resolved screen before validation is reached
at all (`lib/riddler/screens.ex:382` and `:397`, same SHA), so it declares
nothing. What is fail-open is an arity-3 validation of a resolved screen whose
first keyless button node declares `validates` as `false`.

**That is a defect, and the rule above is what makes it one.** The code half
pins the rule with a test that is red before its change and green after: the
arity-3 call, against a document whose screen carries a button declaring
`validates` as `false` and no key, reports the screen's findings rather than
`:ok`. Nothing here enumerates the sites that implement the rule as a complete
list; the rule is what is decided, and the test is what holds the package to it.

### Why the fail-closed reading is the only one this record admits

*Two absences comparing equal is not a host naming a button.* The amendment
above states where `validates` is read from: "`validates` is read from the
button the pressed key names on the resolved screen". A call passing `nil`
names nothing. That it nonetheless finds a node is an artefact of how a missing
key and a missing argument are both spelled, not a host saying which button the
visitor pressed.

*The purpose the record gives the opt-out does not reach this case.* The
Decision above says what the opt-out is for - "the opt-out is what lets a Back
button leave a half-filled screen without an error" - and the amendment above
builds its whole argument on that: "A Back press is the visitor's, and it is
their navigation rather than their submission." A button with no key is not a
Back button anyone pressed. Nobody left the screen through it, because nobody
could. The reason the amendment above gives for answering `:ok` is simply
absent here, and with it the answer.

*Answering `:ok` here is the behaviour the first amendment removed.* The reason
that amendment gives for the finding is carried in the package's own words:
treating the node as hidden and answering `:ok` "would accept a submission
nobody checked" (`lib/riddler/screens.ex:252` through `:254`, the `@doc` on
`validate_screen/3`, read at `543f35275f05f735a34e88777201fa2e4beb1016`); the
amendment above names the same removed behaviour as "a *submission accepted
unchecked*". That amendment carved one case out of the rule, and the carve-out
held because a non-validating press accepts no submission. The
arity-3 call is not a press at all: it is a host asking whether a set of
responses is good. Answering `:ok` to that question, on the strength of a node
nobody pressed, is exactly the accepted-unchecked submission the record refuses
- and it is worse than the case the first amendment found, because it silences
every finding on the screen rather than one.

*The document being defective does not make the answer safe.* A button with no
key is reported as `document.invalid_key`, from the keyless clause of the
private `key_findings/2` (`lib/riddler/screens/document.ex:495` through `:503`,
read at the same SHA), reached through `Riddler.Screens.Document.validate/1`.
That is a different door. A host that validates responses without having walked
the document door - which this package admits, `admit/1` and `validate/1` being
separate calls - is told nothing, and is told `:ok`. The record's own framing
of admit findings is that a document carrying one is still a document; a rule
that is only safe for hosts who checked is not a rule this record can rest a
silent `:ok` on.

*The screen validated is the screen shown.* The first amendment's rule is that
a rule stated about the screen the visitor was shown holds of the screen
validated. A keyless button is on the resolved screen and can be rendered; what
it cannot do is be pressed, because a press is a key. Reading it as the pressed
button makes the validated screen behave as though a press arrived that the
shown screen had no way to send.

### Why an amendment and not a note

The test this record states for itself is whether an entry changes what the
record decides, and the counterweight it states just as plainly is that a
decided reading "can remain a note because its decided reading takes nothing
away". This one takes something away: an `:ok` the package answers today, on a
call the amendment above describes in its own words as answering `:ok`. A
reader of the record as it stands would write a host against that sentence. So
this is not the `metadata` requiredness case, where deciding the open reading
changed nothing the record had decided.

It also bears on the amendment above as directly as an entry can, being a
qualification of the rule that amendment states, which the record names
elsewhere as the mark of an amendment rather than a note. The other test this
record uses - the uncompilable-pattern amendment's "a new refusal of documents
0.1.0 admits" - is not met and does not need to be: no document is refused
here, and that test is a sufficient reason for an amendment rather than a
necessary one.

### What is unchanged

Everything the three amendments above list as unchanged, and each of those
amendments apart from the one question this entry closes for the third of them.
`validates` keeps its default of true, its meaning on a keyed button, and its
admit-time shape check. A press through a keyed button declaring `false` still
answers `:ok` without running a check, for an undecidable condition and for
every other finding, exactly as the amendment above decides. A key naming no
button on the resolved screen still validates, because validating is what a
button that is not there carries. `resolve/2` and `resolve_screen/3` are not
touched, and their diagnostics are what they were.

**No line of this record is edited by this amendment.** The paragraph in the
amendment above that describes a call naming no button as "treated as a press
through it" stays exactly as written. It is a true description of what the
package did when it was written and of why that amendment declined the
question; a record shows its reasoning as it went, and this entry adds the
answer at the foot rather than rewriting the paragraph that posed it.

**One sentence of the public documentation becomes false and is edited by the
code half, not here.** The `@doc` on `Riddler.Screens.validate_screen/3`
carries the exception as a live rule - a call through the arity-3 form reports
the finding "unless the screen carries a button declaring `validates` as
`false` and no key at all" (`lib/riddler/screens.ex:257` through `:261`, read
at `543f35275f05f735a34e88777201fa2e4beb1016`). Under this amendment there is
no such exception. The bead that changes the behaviour changes that sentence in
the same commit. The `@doc` on `validate_screen/4` and the matching passage in
`README.md` need no change: both state the opt-out for a button the press
names, which is what it now is.

**The conformance corpus states nothing this amendment changes.** Every button
in `corpus/screens/validate_responses.json` carries a key (read at
`543f35275f05f735a34e88777201fa2e4beb1016`), so no case presses, or fails to
press, a keyless one. A case pinning this rule from the corpus side - the
arity-3 capability against a screen carrying a keyless non-validating button -
is left for the corpus pass.

**One edge stays where the amendment above left it.** Whether a press through a
button hidden by its own undecidable condition should reach the opt-out is
still unanswered, and this amendment does not reach it: that button carries a
key, and the question there is about resolution rather than about naming.

---

Noted 2026-09-18, campaign RF055, beads rd-0yg, rd-uq9 and rd-pli. Three notes
by addition, each read against `main` at `9e5d667`. They narrow a claim an
amendment above makes about how far its own change reaches, say where the four
places the acceptance note lists as not yet lined up are now answered, and
record what a validation call does with the diagnostics of the resolution it
performs. None of them changes what this record decides, and none bears on the
amendment above.

**Three of the four things the first 2026-09-17 amendment names changed with
`resolve_screen/3`'s return, and one did not (rd-0yg).** That amendment's
section "A single-screen call returns its diagnostics" names four - that the
call is public, that it is "documented with executable examples that match on
`{:ok, screen}`", that it is "cited by ADR-0001 as the call that resolves one
named screen", and that it is "called inside this package by the corpus runner"
- and then says "Every one of those changes with the return." That holds of the
code and not of the record. In the one commit that carried the return
(`fc69b8d`), what changed was `resolve_screen/3`'s `@spec` and body and the one
`@doc` example that matched `{:ok, screen}`, which now matches
`{:ok, screen, diagnostics}` and asserts the diagnostics beside the screen
(`lib/riddler/screens.ex`, the `resolve_screen/3` `@doc`, `@spec` and clause,
read at `9e5d667`); the second example in the same `@doc`, which matches
`{:error, :no_such_screen}`, was untouched, that arm being unchanged. The corpus
runner's call changed too: it matches `{:ok, screen, _diagnostics}` and still
encodes the screen alone (`lib/riddler/corpus.ex`, the `"screens.resolve"`
clause, read at `9e5d667`). The list names one in-package caller and there are
two: `validate_screen/4` moved with the return in that same commit, matching
`{:ok, screen, _diagnostics}` at `fc69b8d` where it had matched
`{:ok, screen}`, while its own return was untouched. It binds those diagnostics
rather than dropping them today, which the third note below records
(`lib/riddler/screens.ex`, the `validate_screen/4` clause, read at `9e5d667`).
What is enumerated here is what moved with the return, not every line that
commit touched: it also added a sentence to this module's `@moduledoc` and a
paragraph to `resolve_screen/3`'s `@doc`, both stating the new return. ADR-0001
did not change with it, and the two citations it carried then had nothing to
change: that record named the call once as the function that "resolves one
named screen of it" and once in a provenance line naming the request that built
it beside `resolve/2`, and neither sentence states a return shape. That commit
touched `lib/riddler/screens.ex`, `lib/riddler/corpus.ex`, two test files and a
changelog fragment, and no file under `docs/adr/`. What ADR-0001 needed was an
entry of its own rather than a correction, and it has one: a dated note of
2026-09-18 on that record, which landed after the tree this entry was otherwise
read against and is read here at `a72788a`, draws the distinction as "Which
call resolves one named screen is unchanged; what that call returns is not what
it was when this record was accepted." The first of the four things listed is
the call's own public surface, and that did change: its `@spec` states the
return, and its being public is why the change is breaking rather than
internal. This record's own earlier sentences naming `resolve_screen/3` are
unchanged as well, and could not be otherwise: this record grows by addition, so
an amendment governs over them where it says it does and nothing above it is
reworded.

**The four places the acceptance note lists as not yet lined up are each
answered further down, and the list itself still reads as open (rd-uq9).** The
2026-09-15 acceptance note above opens that list "Four places where this record
and the code it describes do not yet line up are carried as notes by addition
rather than as corrections, each with a bead". Four is still the count at this
reading, and all four are answered below it. Nothing removes the list, because
this record grows by addition, so this note is the pointer the list cannot carry
itself. In the order the list gives them:

- The envelope shapes "stated here and not yet checked by `validate/1`" (rd-xxb)
  are answered by the entry opening "Noted 2026-09-17, campaign RF051, bead
  rd-xxb.", whose one note is headed "The envelope and boolean shapes this
  record states are checked, one code each, and only where the document carries
  the field."
- The unreachable variant candidate, "which this record describes as dead weight
  without saying it is refused" (rd-d8e), is answered by the note headed "An
  unconditional variant candidate that is not last is an admit finding." in the
  entry opening "Noted 2026-09-17, campaign RF051, beads rd-gwn, rd-d8e, rd-xvv
  and rd-xva."
- `resolve_screen/3` returning "a screen without the diagnostics its resolution
  produced, which this record does not decide either way" (rd-439) is decided by
  the amendment headed "Amendment, 2026-09-17: the screen validated is the
  screen shown", in its section "A single-screen call returns its diagnostics",
  which answers "It returns them."
- `metadata`'s `name`, `description` and `domain`, "named here as what the block
  carries without a requiredness rule" (rd-xvv), are answered by the note headed
  "None of `metadata`'s `name`, `description` and `domain` is required." in that
  same four-note entry of 2026-09-17.

Where a later entry answers an item on that list, that entry is where the answer
now is; the list stands as the account of what was open on 2026-09-15.

**A validation call returns no diagnostics, and the two halves of the
diagnostics its resolution produced go different ways (rd-pli).**
`Riddler.Screens.validate_screen/3` and `/4` answer
`:ok | {:error, [Finding.t()]} | {:error, :no_such_screen}`
(`lib/riddler/screens.ex`, both `@spec`s, read at `9e5d667`), and the arity-3
form is the arity-4 form called with no button named. Neither return carries
`missing_variables` or `undecidable_conditions`. That is not a discard. The
arity-4 body resolves through `resolve_screen/3`, takes the `diagnostics` beside
the screen and hands both to the check (`lib/riddler/screens.ex`, the
`validate_screen/4` clause, read at `9e5d667`), which turns each undecidable
condition into a `response.undecidable` finding on the node carrying it, with
`field` `"condition"`, and never reads `missing_variables` at all
(`lib/riddler/screens/validation.ex`, `validate/4` and the private
`undecidable_findings/1`, read at `9e5d667`). A press that opted out reaches
neither half and answers `:ok`, which is the qualification the third 2026-09-17
amendment records. That amendment's "What is unchanged" states the other half -
"`missing_variables` still becomes no finding" - and the reason is the lenient
rendering this record already decides: a variable a template wanted and the root
did not carry renders as the empty string, which the `@doc` on
`validate_screen/3` puts as "So is a variable a template wanted and the root did
not carry - that renders as the empty string, is reported in
`missing_variables`, and is no finding." Only a condition decides whether a
question was asked at all, and only that half bears on whether a visitor can be
held to an answer. So the decided reading is that a call returning no screen
surfaces the undecidable half as findings and lets the missing-variable half go
unreported, and a caller who wants a screen's diagnostics asks
`resolve_screen/3` for them, that being the call this record decides returns
them. This note states the contract the package ships and changes nothing.

---

Noted 2026-09-18, campaign RF055, beads rd-cay, rd-qr5 and rd-x6t. Three notes
by addition, read against `main` at `474a963`. Two of them settle and then
record the one case the pattern amendment above leaves with response
validation; the third re-states where a phrase the note above cites first
appears. None of them changes what this record decides, and none changes what
any amendment above decides.

**A format declared without the parameter it reads stays a response-time
finding (rd-cay).** The amendment above headed "an uncompilable pattern is the
document's defect" closes its section "One case stays with response validation"
on a question it declines: "Whether a format declared without the parameter it
reads should itself be a document finding is a question this amendment does not
decide." It is decided here, and the answer is no. A question that declares
`format` as `pattern` and declares no `pattern` at all raises nothing at admit,
exactly as that section describes, and response validation is where it is
reported. The reason is the mark that amendment sets for itself: a new admit
finding here would refuse documents this version admits, and would refuse them
for a defect the response-time clause already reports, with the field naming
the parameter the question left out. What is decided is only which layer
reports the defect, and that is the layer reporting it today. The decided
reading takes nothing away - no document that validates clean stops doing so,
no finding is renamed or moved, and no new code is named - so this is a note
and not an amendment, on the test the note above states when it declines to
name a code for a question this record leaves open: doing so "would change what
this record decides, and that is an amendment's work, not a note's". A recorded
no names no code and changes nothing this record decided.

**The finding that one case carries was reworded, and this is what it now says
(rd-qr5).** The move the amendment above records leaves response validation
answering a single case on the `pattern` field, and the wording that case
inherited described a pattern as unusable where there is no pattern to be
unusable. The change that carried the move reworded it. The finding is
`response.format`, its `field` is `pattern`, and its message reads, character
for character:

> this question asks for a response in the form of a pattern and declares none, so nothing can satisfy it

(`lib/riddler/screens/validation.ex`, the private `pattern_finding/1`, read at
`474a963`). The amendment above says response validation "answers
`response.format` with the field `pattern`", and says nothing about the
message; this note is where that text is recorded, because a host may match on
a message rather than on a code and this record is where a host reads what a
finding means. The field is what marks this case out rather than the code:
`response.format` is still what every other format check raises, and those
carry the field `format` (the same file, the private `format_finding/2`, read
at `474a963`), so the only response finding naming the field `pattern` is this
one. Nothing here changes a finding, a code, a field or a message.

**Where "schema-valid means admitted" first appears, and who adopts it
(rd-x6t).** The note above of 2026-09-17 closes its third bullet by calling
that phrase "the conclusion that passage draws from it in its own words, that
schema-valid means admitted". The attribution points one step downstream of
where the phrase originates. It is the document schema description's own
closing words, which read "A validator holding this schema and a runtime
admitting the same value therefore agree: schema-valid means admitted."
(`priv/schemas/screen-document.schema.json`, read at `474a963`; the same
sentence closes that description under the file's earlier name at both SHAs the
bullets around it cite, `342c790` and `27f9d91`). This record adopts the phrase
rather than coining it, and does so twice. The passage above beginning "The
schema is the fourth reading and it is wider still" attributes it where it
belongs, as "the thing the schema's own description already says"; the
amendment above, under "What the record now decides", carries it forward as
"so that schema-valid means admitted". So the chain reads: the schema's
description states it, two passages of this record adopt it, and the note above
cites the second of those two. Nothing that note presents as a quotation is
inexact and its substance stands; what is corrected is the one clause of
attribution, stated here once rather than adjusted again.

---

Noted 2026-09-18, campaign RF055, beads rd-5v2, rd-6kl and rd-hky. Three notes
by addition, read against `main` at `0214837`. The first two decide the two
questions the note above on shape checks carries as open, and decide both by
recording what this record and the code already do; the third says which block
an earlier reference names. None of them changes what this record decides, and
none changes what any amendment above decides.

**None of the schema version, the document id and a screen's title is required
(rd-5v2).** The note above headed "Each is a shape check and none of them is a
requiredness check" states the reading and carries the question open. It is
decided here, and the answer is that none of the three is required: a document
that omits any of them, or all three, is admitted and validates clean, exactly
as it does today. Three surfaces say so, and none of them is changed. The
schema requires `screens` of a document and `nodes` of a screen and nothing
else (`priv/schemas/screen-document.schema.json`, read at `0214837`). The
runtime's three checks each answer an absent field with no finding, by
matching `nil` in a clause head before they judge anything - the private
`schema_version_findings/1`, `id_findings/1` and `title_findings/1` in
`lib/riddler/screens/document.ex`, read at `0214837`, the first two reached
through `envelope_findings/1` and the third through `screen_findings/1`. And
this record, from this note's date, says the same rather than leaving the
question to be inferred from the other two. What the note above gives as its
reason for stopping is the reason for the answer: requiring a field this
record names would refuse documents riddler 0.1.0 and 0.2.0 admit, and a new
refusal is an amendment's work. A recorded no takes nothing away, names no
code and moves no finding, so this is a note. What it settles is that the
three surfaces now agree about presence as well as about shape - absent is
admitted, present is shape-checked - and a host that needs an id or a schema
version present enforces that itself, or holds the document to the schema.

**An explicit JSON `null` is admitted on the three envelope and screen fields
and refused on the three node fields, and both arms stay (rd-6kl).** The note
above states that split and carries open the question of which of the two
answers should hold for all six. It is decided here, and the decision is that
neither arm moves. The split was probed again rather than reasoned about, one
document per field through `Riddler.Screens.Document.admit/1` and then
`validate/1` at `0214837`: `"schema_version": null`, `"id": null` and a
screen's `"title": null` each validate clean, and `"required": null`,
`"validates": null` and `"style": null` each raise exactly one finding,
`document.invalid_required`, `document.invalid_validates` and
`document.invalid_style` respectively. The difference is the accessor and
nothing else. The three node checks read the field with `Map.fetch/2` and so
see `{:ok, nil}`, which is not what an absent key gives them (the private
`required_findings/1` in `lib/riddler/screens/type/text_question.ex`, and the
private `validates_findings/1` and `style_findings/1` in
`lib/riddler/screens/type/button.ex`, all read at `0214837`); the envelope and
title checks match `nil` in a clause head and cannot tell a declared `null`
from an omission.

Each arm stays for its own reason, and in neither case is the reason that the
split is tidy. Refusing a `null` on the envelope and screen fields would mean
`admit/1` recording absence separately from `nil` - a change to the admitted
struct, and a new refusal of documents 0.2.0 admits. Accepting a `null` on the
three node fields would remove three findings 0.2.0 ships. Each arm is
therefore the conservative one for the fields it governs, and recording them
is what this note does rather than making them agree.

The schema is stricter than the runtime on one half of the six and silent on
the other, which is worth stating because it is not what a reader expecting
the schema to be uniformly stricter would find. It types `id` and
`schema_version` and a screen's `title`, so an explicit `null` on any of those
three is not schema-valid and the runtime admits there what the schema
refuses. It does not describe `required`, `validates` or `style` at all - the
node definition names `condition`, `key`, `nodes` and `type`, and does not
close the object - so an explicit `null` on those three is schema-valid and
the finding is the runtime's alone (`priv/schemas/screen-document.schema.json`,
read at `0214837`). The schema stays what its own description says it is, the
statement of "exactly what makes a JSON value a screen document at all"; a
host that wants the envelope held to the types this record states validates
against the schema before it calls the runtime.

**Which block the opt-out amendment's single-note reference names (rd-hky).**
The amendment above headed "the per-button opt-out covers an undecidable
condition" writes, under "Why an amendment and not a note", the sentence "The
single-note block, of its own note:" and gives after it the quotation "it
changes nothing this record decides, and it does not bear on the amendment
above." Two single-note blocks stand above that reference, so its description
does not pick out one of them on its own. The block it names is the one
opening "Noted 2026-09-17, campaign RF051, bead rd-xxb. One note by addition,
read against `main` at `342c790`." The quotation that follows the description
resolves uniquely: the other single-note block, the one opening "Noted
2026-09-17, campaign RF051, bead rd-mnp. One note by addition, read against
`main` at `4208433`.", accounts for itself in different words, as recording
"nothing new about the document" and as changing "nothing either amendment
above decides". Nothing in that section's argument moves, and the
generalisation it draws holds of both blocks; no citation in it fails. What
is stated here is only which block it meant.

---

Noted 2026-09-18, campaign RF055, bead rd-7lu. One note by addition, read
against `main` at `3ff9a42`. It records a naming decision and what follows from
it for a host, and changes no answer this record gave.

**`response.undecidable` keeps its `response.` prefix by decision, and this one
is the recorded exception rather than the pattern.** The question the code's
name raised was whether it should move to a prefix naming the call, since the
finding is not about a response. It does not move, and the reason is that it is
published. The code string ships in riddler 0.2.0
(`lib/riddler/screens/validation.ex`, the private `undecidable_finding/1`, read
at the tag `v0.2.0`, `a3ee6e6`), where the `@doc` on
`Riddler.Screens.validate_screen/3` lists it beside its three siblings and calls
a finding's `code` "a stable `code`". It is also the expected `code` of three
cases in the conformance corpus, in `corpus/screens/validate_responses.json`,
among them the case named "A condition the root cannot decide is a finding, not
a silent pass: the question is neither held to its requirement nor let through"
and the case named "The validating button on that same screen returns the
finding the root could not decide" (read at `3ff9a42`; those two carry the code
at the tag `v0.2.0` as well, the third having been added since). A rename would
change a published finding code and restate what those cases assert, and would
buy a name and nothing else: no document would be admitted or refused
differently, and no host would read a finding it does not read today. The next
finding of this kind - one about the call rather than about the visitor - takes
a prefix naming the call when it is first written, while naming it is free.

**What the prefix does not tell a host.** A host that matches on the `response.`
prefix to decide that a finding belongs beside the field the visitor is editing
will pick this one up with the rest, and nothing the visitor types clears it: a
condition that could not be decided reports that the root the host handed in
does not carry what the document asks about, which the `@doc` above puts as "a
defect in the call rather than a property of the visitor". Its `field` is
`"condition"` rather than a field of the question
(`lib/riddler/screens/validation.ex`, `undecidable_finding/1`, read at
`3ff9a42`), and the passage of this record beginning "A validation call returns
no diagnostics" says where it comes from. A host that wants that placement
matches the code in full rather than its prefix.

**The siblings are not uniformly about the visitor either, so the prefix carries
less than it looks like it carries.** The three listed beside it in that `@doc`
are `response.required`, `response.format` and `response.out_of_range`. Two of
them are about what the visitor typed in every case they raise: `required` is
unanswered when the response is absent or is a string of whitespace, and
`out_of_range` is a number outside a bound the question declares
(`lib/riddler/screens/validation.ex`, the private `required_finding/1` and
`range_finding/5`, read at `3ff9a42`). `response.format` is about what the
visitor typed in every case but one: the case the note above headed "The finding
that one case carries was reworded, and this is what it now says" records, whose
`field` is `pattern` and which fires for a question declaring the `pattern`
format and declaring no pattern at all - a defect in the document, which no
response can satisfy. So the statement this record makes is the negative one: a
`response.` code does not by itself say that what the visitor typed is what the
finding is about, and two codes in that set already show it.

**Why a note and not an amendment.** The text above this entry decides nothing
about what a code's prefix means; it names codes one at a time and says of each
what it reports. So recording that the prefix does not partition findings by who
can clear them contradicts no rule stated above and takes nothing away: no
document that validates clean stops doing so, no code, field or message moves,
and no new refusal is added. A recorded decision to leave a published name
where it is changes no answer this record gave.

---

Noted 2026-09-18, campaign RF055, bead rd-d9n. Three notes by addition, read
against `main` at `90f5930`, with the code half that makes the first two true
in the same request at `b67dea5`. Nothing above is changed; each paragraph
below says what the text above means now.

**The three things that leave a condition undecided are one finding, by
decision.** The amendment above headed "An undecidable condition is a finding"
decides that a condition that cannot be decided against the root answers a
finding rather than `:ok`, and leaves "the finding's code to the bead that
raises it". The code that was raised, `response.undecidable`, is reached by
three unrelated things: a condition that compiles and that this root leaves
undecided, a condition that is not valid predicator at all, and a condition
that is not a string (`lib/riddler/screens/validation.ex`, the private
`cause/2`, read at `b67dea5`). It stays one code for all three, and the reason
is fail-closed rather than tidy. The second and the third are each already a
document finding, `document.invalid_condition` on the same node and the same
field (`lib/riddler/screens/document.ex`, the private `condition_findings/2`
and `compile_condition/2`, read at `b67dea5`), and that remains where an author
fixing the document is told about them. But nothing obliges a host to call
`Riddler.Screens.Document.validate/1` before it resolves, and a host that does
not is the one this check stands for: narrowing the code to the
genuinely-undecided case would let a document the parser refused resolve and
validate clean, which is the silent pass the amendment above removes. What
tells the three apart is the `message`, which now names which of them fired.
The `code`, the `field` `"condition"` and the `node_key` are what they were, so
a host switching on the code reads what it read before
(`lib/riddler/screens/validation.ex`, the private `undecidable_finding/2`, read
at `b67dea5`; the three are pinned one case apiece in
`test/riddler/screens/validation_test.exs`, the describe block "which of the
three things left a condition undecided", read at `b67dea5`).

**It carries the place it is given, and invents none.** Two of the three are
located by the package's dependency and one is not. A condition that does not
compile is located by the parser; a condition that compiles and names an
identifier the root does not carry is located by the evaluator; a condition
that compiles and reads a key missing from a map the root does hold is
undecided with no place named, and a condition that is not a string never
reached the parser and has none either. The finding carries the position in the
first two cases and `nil` in the last two, through
`Riddler.Finding.position/2`, which builds the map only from a positive line
and a positive column (`lib/riddler/finding.ex`, `position/2` and its fallback
clause, read at `b67dea5`). The message and the field cannot disagree about
whether there is one: the place is appended to the sentence from the position
rather than from the numbers it was built out of
(`lib/riddler/screens/validation.ex`, the private `span/1`, read at
`b67dea5`). Reading the condition a second time is what makes this possible,
and the validation entry point is handed the whole root rather than the
responses inside it so that the second reading runs against the same root the
first did (`lib/riddler/screens.ex`, the `validate_screen/4` clause, and
`lib/riddler/screens/validation.ex`, `validate/4`, both read at `b67dea5`). The
published diagnostics gain nothing: `undecidable_conditions` is still a list of
`%{key: ..., condition: ...}`, which is what the Typespecs section above states
and what `resolve_screen/3` answers, and a key added to it would be a new
public field for something only the response check reads.

**A count in ADR-0001 moves with this, and belongs to that record.** The note
in `docs/adr/0001-riddler-one-package.md` headed "`Riddler.Finding` carries a
source position, and this record is where that is decided" says under "Which
findings carry it" that three sites in `lib/` set the field and no others, and
names `response.undecidable` among the findings that leave it `nil`; the
amendment below it headed "a placeless parse refusal is a finding with a nil
position" restates that count as still three. After the change recorded above
there are four sites, and `response.undecidable` is the fourth. That record
also files the `nil` this change removes as one of three defects recorded
"rather than explained", on the ground that "a record cannot be made true about
behaviour that is wrong", so the count moving is what it anticipated rather
than something it decided against. Saying so is all this paragraph does:
ADR-0001 is where its own count is stated and where it is restated.

**Why a note and not an amendment.** The test the records state in their own
words is whether the entry changes an answer the record gave: an entry is an
amendment where "the rule stated above answers a call one way, and this entry
answers the same call another". No rule stated above answers a call one way and
is answered another here. This record decides that an undecidable condition is
a finding on the node carrying it, with `field` `"condition"`, reported wherever
the pressed button validates, and every one of those is what it was: no
document that validates clean stops doing so, no document that is refused stops
being refused, no code, field or node key moves, and no refusal is added. That
the catch-all was left as it stands is a recorded decision to leave behaviour
where it is, which the records treat as a note, and deciding a question the
record left open is not the test either: this record already says so, in the
sentence "Deciding an open question and changing what the record decides come
apart, and it is the second that governs." What is decided above stays a note
on the same ground the note above that sentence gives for itself, that "its
decided reading takes nothing away, and so changes nothing this record had
decided". One thing this entry does move is the
`message`, which the single-note block above it names among what it left where
it was; a message is not part of what this record decides, which names codes
and fields and never a sentence, and the block above accounts for its own entry
rather than for this one.
