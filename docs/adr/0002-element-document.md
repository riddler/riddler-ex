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
