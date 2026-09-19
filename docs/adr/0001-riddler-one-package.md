# ADR-0001: Riddler is one package: a dynamic content runtime that consumes the statifier family, and the content document is its contract

Status: accepted

## Context

Riddler is a dynamic content runtime: a host authors content as JSON documents -
screens now; emails, images and feature flags forthcoming - and Riddler resolves
each against a visitor's context; the host renders, sends or serves what comes
back. Something has to decide what such a declaration means. The statifier
family already decides a different question - a chart decides what happens next,
and `statifier-ex`, `statifier_blocks` and their siblings own that. The two meet
in a host application, where a workflow reaches a screen and a screen has to be
resolved into the nodes a visitor sees.

Which way that arrow points is the question this record settles, and it has to
be settled before any module exists, because the answer decides what may appear
in `mix.exs`. A dependency added for convenience is very hard to remove once a
second package relies on the coupling it creates.

Two pieces of public evidence bound the answer. The fixture
`priv/fixtures/signup_screens.json` in `statifier_examples` (read at `9d288c9`)
is a screen document written by hand: three screens of a signup wizard, each
a list of nodes with keys, carrying a `schema_version` and a `metadata` block,
and explicitly not a block document - the chart that drives it is a separate
fixture beside it. It is the shape a host already wants to author. The findings
document `docs/spikes/SF040-element-editor.md` in `statifier_blocks` (added by
that repository's PR 465; present at `cdfbc6c`) weighs, against two spikes,
whether the block editor should emit that shape itself, and separates the cost
of the emit seam from the cost of the element vocabulary it emits. Both are
public; neither is a decision, and this record does not treat them as one.

Prior generations of this product exist in history. They are not evidence for
anything decided here, and nothing below is justified by them.

## Decision

**Riddler consumes the statifier family; the family does not consume Riddler.**
A workflow engine calls into this runtime when it reaches a screen, and this
runtime never calls into a workflow engine. Charts stay in statifier: nothing
in this package interprets, executes or re-implements a chart, and a need to do
so is a decision to record before it is code to write.

**Riddler ships as one hex package, `riddler`.** The content kinds, the
template subset and the shared machinery are modules in that package rather
than packages of their own. The package is split along one of its seams only
when a consumer needs that piece without the others; a seam that no consumer
has asked to use alone is a module boundary, not a package boundary.

**The content document is the contract.** It is JSON, it carries a
`schema_version`, and it is what both sides of the boundary agree on - not a
struct, not a function signature, not a wire format negotiated per host. A
change to what the document admits is a change to the contract and is breaking
for every host holding one. A screen document is this version's instance of
that contract.

**A content kind is a document shape, a resolved shape, a registry and a corpus
capability.** Those four are what makes a kind a kind: the shape a host
authors, the shape resolution returns, the registry that says what may appear
inside the document and refuses what it does not know, and the corpus
capabilities a second runtime is held to. A proposal that supplies fewer than
all four is not a kind yet.

**v1 ships exactly one kind, `screens`.** Emails, images and feature flags are
forthcoming kinds, and each is decided by its own record before it is code. A
kind is added by a record, never by a commit.

**Kinds share the template subset, conditions, containers, diagnostics and
findings, and never depend on one another's documents.** The shared machinery
is written once and each kind uses it; no kind's document, registry or resolved
shape is reachable from another kind's. A kind that needs to read another
kind's document is a coupling to record, not a module to write.

**Each kind exposes admit and validate over a raw document, and resolve over a
document and a context, as pure functions, plus at most one kind-specific
check.** The screens kind's one check is `validate_responses`, which is what a
host calls before it accepts what a visitor submitted. A kind that wants a
second check is a record, because a kind with an open-ended API is not a
contract a second runtime can be held to.

**This package is the reference implementation of that contract, and it resolves
server-side.** Resolution happens here, against a host-supplied `context`;
rendering, delivery and serving happen in the host. Nothing in this package
renders a view, sends a message, serves a byte, stores anything, or assumes a
browser. For a kind whose resolved document is itself the deliverable - an SVG,
an email's text part - resolution is the last step this package takes, and what
the host does with the result is still the host's. A second runtime in another
language is held to this package's behavior, not the reverse.

**The public runtime of the screens kind is pure functions over decoded data.**
`Riddler.Screens.Document.admit/1` and `Riddler.Screens.Document.validate/1`
say what the vocabulary admits and why a document is refused;
`Riddler.Screens.resolve/2` resolves a document against a context, and
`Riddler.Screens.resolve_screen/3` resolves one named screen of it;
`Riddler.Screens.validate_responses/3`, and its arity-4 form naming the button
that was pressed, say what a set of responses has to satisfy before a host
accepts it. They are pure: same inputs, same outputs, no process state, no I/O.
Surface beyond those functions is added by a record, not by a commit.

**A kind's modules sit under the kind's own namespace, and the shared machinery
does not.** This kind is `Riddler.Screens`; the forthcoming kinds are
`Riddler.Emails`, `Riddler.Images` and `Riddler.Flags`. `Riddler.Template`,
`Riddler.Finding` and the condition and container machinery are shared and
carry no kind in their names. The first release of this package named the
screens kind `Riddler.Elements`, after the nodes inside a screen rather than
after the kind; the rename to `Riddler.Screens` lands with 0.1.0 and no
`Riddler.Elements` name survives it.

**A corpus capability is named `<kind>.<function>`.** This version emits
`screens.admit`, `screens.resolve` and `screens.validate_responses` for the one
kind, and `templates.render` for the shared template subset; forthcoming kinds
emit `emails.*`, `images.*` and `flags.*` under the same rule. A capability
name is how a second runtime dispatches a case, so it is part of the contract
and changes only by a record.

**The conformance corpus is authored in this repository and emitted into
`riddler_spec`.** The cases live beside the code that has to satisfy them; a
mix task emits them, with provenance naming the commit they were emitted from,
and a drift check in this repository's CI fails when the emitted corpus and the
cases disagree. A corpus file is never edited by hand in `riddler_spec`: the
emitted copy is an artifact, and an artifact that can be edited is not a
conformance corpus.

**The core never depends on the block editor or on any statifier package.**
No statifier package appears in this repository's `mix.exs` or `mix.lock`. An
editor that authors content documents is served by a later adapter package that
depends on both sides; it is not served by a dependency here.

**`predicator` and `solid` are the runtime dependencies, and they are the only
ones.** `predicator` evaluates the conditions a document declares; `solid`
parses the template subset. A third runtime dependency is a decision to record.

**A container's winner replaces the container in the resolved output.** A
resolved document is the same shape as the document it came from, with the
containers gone: a host that can render a document can render a resolved one,
and nothing downstream needs to know a container was ever there.

## Consequences

Renderers, delivery, persistence, scheduling and the admin are the host's, or
later packages'. A feature this package could plausibly grow - a renderer, a
mailer, a store, a transport - is out until a record puts it in.

Two records follow from this one. ADR-0002 decides the screen document v1 - the
document of the one kind this version ships: the envelope, what a screen is,
the node vocabulary, keys, conditions, `writes`, outcomes, the variant
container, and what a resolved screen is. ADR-0003 decides the template subset:
the allowlist, compile-time refusal, the output mode, and the render modes.
This record delegates every enumeration to them and to the tests of the code
halves that implement them; it enumerates nothing itself.

A further record, ADR-0004, decides the shared content machinery - what
conditions, containers, diagnostics and findings mean for every kind rather
than for screens alone - and it precedes the first non-screen kind's record.
Until it exists those rules live in ADR-0002, where they were first written,
and a kind added before ADR-0004 would be reading a screens record for shared
rules, which is the reason ADR-0004 comes first.

Nothing here decides transport, authentication, streaming, the identity or
durability of a visitor's execution, or the editor. Those remain open, and a
commit that assumes an answer to one of them is out of scope until a record
closes it.

The vocabulary is fixed by this record for everything downstream of it: a
document declares `writes`, a control names an `outcome`, what a visitor
submits is `responses`, and the host-supplied root is `context`. The spellings
`payload`, `action` and `answers` are named here once, to state that they are
not used.

## Typespecs and worked example

This record names no types; it asserts rules about a package boundary and a
contract, and the typespecs section this family's records carry does not apply
to it. ADR-0002 and ADR-0003 carry the typespecs for the screen document and
the template subset.

One sentence needs illustrating - that the content document, not a struct, is
the contract. The public fixture `statifier_examples`
`priv/fixtures/signup_screens.json` (at `9d288c9`), in outline with its
`metadata` block and its node lists elided, and with the `kind` ADR-0002 adds
to the envelope written out rather than defaulted, is:

```json
{
  "schema_version": 1,
  "kind": "screens",
  "id": "edoc_signup_screens",
  "screens": [{ "key": "account", "title": "Create your account", "nodes": [] }]
}
```

That is what a host authors and what this package is given. It is JSON on both
sides of the boundary: no host constructs an Elixir struct to talk to this
package, and no runtime in another language is disadvantaged by the fact that
the reference implementation is written in Elixir.

---

Recorded 2026-09-14, campaign RF049, bead rd-1dt. Rewritten in place while
still proposed on 2026-09-15, campaign RF049, bead rd-9wd: the record now
frames Riddler as a dynamic content runtime with content kinds, names the
screens kind's modules and corpus capabilities, and delegates the screen
document to ADR-0002 and the shared machinery to a forthcoming ADR-0004.

Accepted 2026-09-15, campaign RF049, bead rd-v1w, after a claim-by-claim
reading against `main` at `0d1979b` (riddler 0.1.0, published). The code halves
that built what this record asserts: the package boundary and the two runtime
dependencies (PR 1), the template subset (PR 5), `Riddler.Screens.Document`
and its registry (PR 6), `resolve/2` and `resolve_screen/3` (PR 7),
`validate_responses/3` and `/4` (PR 8), the corpus and its four capabilities
(PR 9), the emitter and the drift check (PR 10), and the rename to
`Riddler.Screens` (PR 15). The paragraph above, recording a rewrite made
"while still proposed", describes the state this Note ends: the record is
accepted from this date, and a further change to what it decides is an
amendment, not an edit in place. Two sentences it states as rules are still
prospective at 0.1.0 and are carried as notes by addition rather than as
corrections: the shared condition and container machinery it says carries no
kind in its name still lives under `Riddler.Screens` (rd-2b2), and the
`<kind>.<function>` capability rule wants a clause for the shared
`templates.render` (rd-c6t).

Noted 2026-09-17, campaign RF051, beads rd-2b2, rd-c6t, rd-aya and rd-cpx, and
one item carried out of the direction review of ADR-0002's amendment of the same
date. Five notes by addition, each read against `main` at `27faac3`. Nothing
above is changed; each paragraph below says what the text above means now.

**The shared condition and container machinery still sits under the kind's
namespace.** The module-layout rule above says that `Riddler.Template`,
`Riddler.Finding` and the condition and container machinery are shared and carry
no kind in their names. At `27faac3` the first two hold and the last two do not
yet: condition evaluation lives in `Riddler.Screens` (`lib/riddler/screens.ex`,
the private `evaluate/4` that calls `Predicator.evaluate/2`) and in
`Riddler.Screens.Document` (`lib/riddler/screens/document.ex`,
`compile_condition/2`), and the one container this version ships is
`Riddler.Screens.Type.Variant` (`lib/riddler/screens/type/variant.ex`). Read that
sentence prospectively: it states where the machinery belongs once it is shared,
and lifting it out of the kind's namespace is work for the forthcoming ADR-0004,
which the Consequences section already names as the record that decides the
shared content machinery. `Riddler.Template`, `Riddler.Template.Compiled` and
`Riddler.Finding` are the parts of it that carry no kind today (rd-2b2).

**The capability-naming rule covers shared machinery under its own prefix.** The
rule above is written `<kind>.<function>` and is immediately followed by
`templates.render`, which is the shared template subset and not a content kind.
The rule in full: a capability is named `<prefix>.<function>`, where the prefix
is the kind for a kind's capability and the machinery's own name for shared
machinery. The names ship as they are - at `27faac3` this version emits
`screens.admit`, `screens.resolve` and `screens.validate_responses` under
`corpus/screens/`, and `templates.render` in `corpus/templates/render.json` - and
a shared-machinery prefix, like a kind's, is part of the contract and changes
only by a record (rd-c6t).

**The packages the no-statifier rule excludes, named.** "No statifier package
appears in this repository's `mix.exs` or `mix.lock`" excludes the statifier
family's own packages: `statifier` (the `statifier-ex` repository),
`statifier_blocks`, `statifier_persistence`, `statifier_oban`,
`opentelemetry_statifier`, `statifier_ui`, `statifier_datamodel` and
`statifier_examples`. `predicator` and `solid` are outside that set and are the
two runtime dependencies this record names; `predicator` is developed alongside
the statifier family but is not one of its packages, and the rule does not reach
it. At `27faac3` the rule holds literally: `mix.exs` names `predicator` and
`solid` as the runtime dependencies, its one occurrence of the word "statifier"
is the deps comment restating this prohibition, and `mix.lock` carries no package
of that set (rd-aya).

**The worked example elides two of the fixture's three screens.** The fixture is
a signup wizard of three screens, keyed `account`, `plan` and `confirm` (read at
`9d288c9`). The outline above shows `account` alone; `plan` and `confirm` are
elided along with the `metadata` block and the node lists (rd-cpx).

**`validate_responses/3` and its arity-4 form are removed by ADR-0002's
amendment of 2026-09-17.** Two places above name them as current: the paragraph
on the public runtime of the screens kind, and the sentence naming
`validate_responses` as that kind's one kind-specific check. Both describe what
0.1.0 shipped. That amendment decides that a check on a visitor's responses
resolves the screen against the same root the host resolved with, names the
replacement `validate_screen/3` and its arity-4 form naming the button that was
pressed, and removes `validate_responses/3` and `/4` rather than deprecating
them; it says in as many words that prose in this record naming
`validate_responses` describes what v1 did and stays as the historical record of
it. Read those two places here as history from that date. The removal is a
breaking change to a public function of 0.1.0 and ships in the next release cut
after its code half lands; at `27faac3` that code half has not landed and
`Riddler.Screens.validate_responses/3` and `/4` are still present in
`lib/riddler/screens.ex`.

Noted 2026-09-17, campaign RF051, bead rd-9j0. One note by addition, read
against `main` at `6658ae4`. Nothing above is changed.

**`Riddler.Corpus` and the `mix riddler.corpus` task ship in the Hex tarball,
and that is the decision, not an accident.** Both are files under `lib/`
(`lib/riddler/corpus.ex` and `lib/mix/tasks/riddler.corpus.ex`, read at
`6658ae4`), and `package/0`'s `files:` list in `mix.exs` names the whole `lib`
directory, so a `mix hex.build` of 0.1.0 at that commit puts both in the
package. They stay: they are small, they document to a reader of the published
package what this package's conformance corpus is and how it reaches
riddler_spec, and excluding individual `lib/` files by enumerating paths in
`files:` is a list that has to be maintained against every future file under
`lib/` (rd-9j0).

Noted 2026-09-17, campaign RF051, bead rd-pqf. One note by addition, read
against `main` at `0d51acc`. Nothing above is changed.

**The provenance an emitted case file carries names the source file and
nothing else: no version, no commit.** The corpus paragraph above says that a
"mix task emits them, with provenance naming the commit they were emitted
from, and a drift check in this repository's CI fails when the emitted corpus
and the cases disagree." That clause was already inaccurate at 0.1.0 in the
noun it used: at `0d51acc` the emitter stamped the package VERSION, not the
commit - `Riddler.Corpus.generated_by/1` in `lib/riddler/corpus.ex` answered
the word `riddler`, the package version, the word `from` and the
repository-relative source path. From this date the header carries neither.
It is the word `riddler`, a space, the word `from`, a space and the source
path, so an emit is byte-identical across commits AND across releases, and a
difference the drift check reports is a difference in the corpus rather than
in when or from what version it was emitted. In the corpus, not in the cases
alone: `Riddler.Corpus.drift/1` walks `files/0`, which is the case files and
the schemas together (`lib/riddler/corpus.ex`, read at `0d51acc`), so a
schema that differs or is absent is reported exactly as a case file is - and
a missing schema is what that check reports on the request carrying this
note. The clause's second half holds unchanged: the drift check still fails
when the emitted corpus and the cases disagree. Read its first half as
history: what 0.1.0 emitted was the version, not the commit that clause
names.

**Why no `corpus_version` field and why no commit stamp.** Neither was taken,
and each fails for its own reason. A `corpus_version` key does not exist: no
case file, schema or module in either repository carries one, and the corpus
case schema's own description says the emitter "adds its own provenance header
beside them, which is why this schema does not forbid further keys at the top
level" - permission to add a key, not a key already there. Adding one would
be introducing a field to an emitted format, which is a decision about the
contract and not a fix to a header. A commit stamp fails harder: it would
rewrite every emitted file on every commit to this repository, where the
version stamp rewrote them only on a release. The property the header exists
to have is that re-emitting an unchanged corpus writes the same bytes, so
that the drift check reports a real difference rather than the passage of
time; stamping the commit would trade a drift-per-release for a
drift-per-commit and leave the drift check reporting the history of this
repository instead of the content of the corpus. The version and the commit
an emit ran from are recorded in the request that carries the emit, where
they do not travel into the artifact.

**The key stays; only its value changes.** `riddler_spec`'s `bin/lint`
requires `generated_by` on every case file among its required top-level keys
(read at `riddler_spec` `84d7a3e`), and it checks that the key is present and
not what its value says. Removing the key would turn that repository's gate
red; a corpus emitted under this note passes it unchanged. The package
version itself is not removed and is not hidden: `Riddler.Corpus.version/0`
survives, and `mix riddler.corpus` still names the version on the console for
whoever is running an emit. Console output is not an emitted byte, and a
person running the task is entitled to know which checkout is writing.

**Why a note and not an amendment.** The test `docs/adr/README.md` states is
that "an amendment changes what the record decides and a note does not: a
note records where something already decided renders, or what a sentence
already accepted was about." This entry does not change what this record
decides. The proposition the corpus paragraph asserts in bold - that the
conformance corpus is authored in this repository and emitted into
`riddler_spec` - is word for word what it was and is as true after this
change as before. What moves is a subordinate clause describing how the
emitter labels what it writes, and even that clause's truth value does not
move: it named the commit while the emitter stamped the version, so it was
inaccurate before this change and is inaccurate after it. What this record
DECIDED names no `generated_by` and states no header shape: at `0d51acc` the
word does not occur in this file at all. Where it occurs as this note lands,
and where the header's shape is spelled out, is in the paragraphs of this
note, which report the header rather than decide it. And the record does not
put the header inside the contract it decides; the contract it decides is the
content document. The note above headed "**`Riddler.Corpus` and the `mix
riddler.corpus` task ship in the Hex tarball, and that is the decision, not
an accident.**" is the precedent this follows - a deliberate choice about the
emitter, locked in where a reader of the record will meet it, without
amending anything. By contrast the sibling record ADR-0002 took THREE
amendments the same day, and each of the three cleared the bar for a reason
this entry has no counterpart to. The first says of itself that "this
amendment changes what the record decides there", which is the test in the
record's own words. The second, because it "reverses the layer the Decision
assigns" and "refuses documents this version admitted". The third, because
"the rule stated above answers a call one way, and this entry answers the same
call another". All three read at `0d51acc`, and all three name a call the
record answered one way and now answers another. This entry names none,
because it changes no answer the record gave. That a ruling was taken is not
the test; if it were, every commit made under one would amend a record.

This note is recorded with the code half that makes it true, in one request:
at `0d51acc` the emitter still stamps the version, and the request carrying
this note is the one that stops it (rd-pqf).

Noted 2026-09-17, campaign RF051, bead rd-0pi. One note by addition, read
against `main` at `63c432f`. Nothing above is changed.

**`Riddler.Finding` carries a source position, and this record is where that
is decided.** The struct gains a fifth field, `:position`, which is either
`nil` or a map `%{line: line, column: column}` with both numbers one-based and
counting bytes, as the parser's own locations do. Where a finding carries a
position its `:message` names it too and goes on naming it: a person reading a
finding reads one sentence, and the field is the same fact in the form an
editor can act on without parsing that sentence.

**Which findings carry it.** Three sites in `lib/` set the field and no others:
the two clauses of `Riddler.Template` that build a template refusal, and the
`document.invalid_template` finding in `lib/riddler/screens/document.ex` that
re-reports a template refusal against the template a document node writes,
which carries the position of the refusal it wraps. Every other finding this
package builds leaves it `nil`: the document checks; the field refused for not
being template source at all, which carries the `document.invalid_template`
code as well, so that code alone does not tell a host whether a span is there;
and the four response findings, `response.required`, `response.format`,
`response.out_of_range` and `response.undecidable`.

**Why some of those `nil`s are the way they are is filed rather than
explained.** Three of them are defects in this package and not decisions of
this record, and a record cannot be made true about behaviour that is wrong:
`document.invalid_condition` obtains a place for a condition the compiler
refused and does not carry it, and `document.invalid_pattern`'s place is
discarded a layer below the finding (both rd-ai1); `response.undecidable`
fires for several unrelated causes and discards a position it is handed
(rd-d9n); and a template refusal whose parser metadata is malformed raises
before any finding is built rather than producing one without a place
(rd-9cc). That last one is why "every template refusal carries a position" is
worth stating carefully: it is what this package's checks and a fuzz of 19,683
templates and 43,253 adversarial inputs established, finding no template
finding with a `nil` position, and not a guarantee the parser makes. A
metadata carrying a line and no column would reach `Riddler.Finding.position/2`
and yield `nil`; no input has been found that produces one.

The field and the checks that pin it are added by this request and so are
citable at no earlier SHA; at `4208433` the struct carried four fields and the
line and column existed only inside the message, although
`lib/riddler/template.ex` already carried them as a pair through its refusal
tuples and formatted them in at the end.

**Why this record and not ADR-0002 or ADR-0003.** The rule on module layout
above names `Riddler.Template`, `Riddler.Finding` and the condition and
container machinery as the shared machinery that carries no kind in its names,
and the rule on the public runtime of the screens kind says that surface
beyond the functions it names is added by a record and not by a commit. A
field on the struct every refusal in this package returns is that surface, and
this is the record that owns the shared machinery it sits on. The two records
that decide behaviour producing findings do not own its shape: ADR-0003 names
`Riddler.Finding` nowhere, and ADR-0002 mentions it twice - once as an example
usage, and once to say in as many words that it does not introduce a
finding-code registry and that nothing there changes what the struct carries.
Neither enumerates the fields as a decision, so neither is amended by adding
one; the addition is recorded here, where the struct's ownership is stated.

**Why a map and not a tuple, a nested struct or two flat fields.** A host
matches `%Riddler.Finding{position: %{line: line, column: column}}` and reads
the two numbers by name. A `{line, column}` tuple would be positional, so a
reader has to know which number is which, and it has no JSON form, while this
package's conformance encoder turns every answer it emits into JSON for a
second runtime. Two flat fields would make "there is no source span" two facts
that can disagree, where one nullable field makes it one. A nested struct
would be a second public module for a pair of integers, and gains a host
nothing a map with those keys does not already give it.
`Riddler.Finding.position/2`, which is `@doc false` and no part of this
package's public surface, turns a line and a column into the map and answers
`nil` unless both are positive integers, so a parser error reported without a
place could not put half a span on a finding. It is the same device, in the same
module, and for the same reason, as
`Riddler.Finding.node_key/1`, the `@doc false` coercion this package's findings
already go through; each is `def` rather than `defp` because the checks that
build findings call it from another module. The map's shape carries a name of
its own: this addition exports the type `Riddler.Finding.position/0`, defined as
`%{line: pos_integer(), column: pos_integer()}`, and the struct's `:position`
is typed `position() | nil` (rd-0pi).

## Amendment, 2026-09-18: a placeless parse refusal is a finding with a nil position

Status: accepted (2026-09-18)

This record decided that a finding's `:position` is `nil` or a map of a line
and a column, and it stated carefully that every template refusal carries a
position - carefully, because the statement rested on a fuzz rather than on a
guarantee, and because the one input class that would have falsified it raised
instead of producing a finding at all. That raise is now gone. This amendment
changes what the record decides about the shape a template refusal can take.

The change it records is the one riddler-ex pull request 45 makes. At writing
that request is open and held, and every cite below is read at its head
`3ca3d745099636ee3e8f3468d467263fcaa3c34b`; the amendment lands at proposed
and is flipped once both it and that request are on `main`.

### What the record now decides

**A template the parser refuses without saying where is a finding with no
position.** The refusal reaches a host as the ordinary parse-failure finding,
`template.parse_error` with `position: nil` and a message that names no place,
from `Riddler.Template.compile/1`
(`lib/riddler/template.ex:166`, the `{:error, :placeless}` clause at `:180`);
and as `document.invalid_template` with `position: nil` at the document door,
where the wrapping finding carries the position of the refusal it wraps and
that position is now legitimately absent
(`lib/riddler/screens/document.ex:586` and `:590`). Both are pinned by tests,
and the first by a corpus case in `corpus/templates/render.json` that expects a
refusal naming no place.

**A `nil` position is a reachable shape, not only an unreached one.**
`Riddler.Finding.position/2` is where it is answered: it builds the map only
when both the line and the column are positive integers and answers `nil`
otherwise (`lib/riddler/finding.ex:97` and the fallback clause at `:101`). It
is reached with no line at all, because the parser can refuse a source without
locating it and one call into the parser -
`Riddler.Template`'s private `parse/1` at `lib/riddler/template.ex:210`, which
wraps exactly `Solid.parse(source)` and names the two exceptions the parser
raises inside its own line arithmetic, `ArithmeticError` and `CaseClauseError`
(`:213`) - turns that into a refusal rather than an exception. The message and
the field cannot disagree about it: the span is appended from the position
rather than from the numbers it was built out of
(`lib/riddler/template.ex:538` and `:539`).

**The rule is restated.** "Every template refusal carries a position" no
longer holds and is replaced by: every template refusal is a finding, and a
position is present when the parser gave one.

### What v1 said, and why it is now history

Two sentences of this record are about the state before that change, and are
read as history rather than as what the record decides.

The first named the raise as an open defect of this package:

> and a template refusal whose parser metadata is malformed raises before any
> finding is built rather than producing one without a place (rd-9cc).

That defect is resolved by the request above, and the bead is no longer open
against this record. The other defects that paragraph files - the condition
and pattern places discarded a layer below the finding, and the undecidable
response finding's several causes - are untouched by it and stand as written.

The second grounded the absence of a `nil` position in the fuzz rather than in
a guarantee:

> it is what this package's checks and a fuzz of 19,683 templates and 43,253
> adversarial inputs established, finding no template finding with a `nil`
> position, and not a guarantee the parser makes. A metadata carrying a line
> and no column would reach `Riddler.Finding.position/2` and yield `nil`; no
> input has been found that produces one.

The care in that sentence was warranted and the sentence is now overtaken:
inputs that produce a template finding with a `nil` position are known, named
in the tests and in the corpus, and `{% render %}` is one of them. What the
fuzz established remains true of the code it ran against; it is not a
statement about the code this amendment records.

**The count of sites is unchanged.** "Which findings carry it" says three
sites in `lib/` set the field and no others, and after the change it is still
three: the two clauses of `Riddler.Template` that build a template refusal
(`lib/riddler/template.ex:518` and `:529`) and the `document.invalid_template`
finding that re-reports one (`lib/riddler/screens/document.ex:590`). The
guard added at the one call into the parser routes a placeless refusal through
the first of those clauses rather than adding a fourth site; what changed is
what that clause can produce, not how many places produce it.

---

Noted 2026-09-18. The Amendment above, "a placeless parse refusal is a
finding with a nil position", moves from `proposed` to `accepted`, its Status
line flipped in place and nothing else in it reworded.

It was verified against `main` at `a3ee6e6` before the flip rather than
against the tree it was written on: it cites the head of riddler-ex pull
request 45, which has since merged as `f9cb9c8`, and riddler 0.2.0 has moved
`main` on top of it. Every cite was re-located by anchor at that SHA and each
still reads as the amendment states, at the same line:

- `Riddler.Template.compile/1` and its `{:error, :placeless}` clause
  (`lib/riddler/template.ex:166` and `:180`).
- The one call into the parser, `Riddler.Template`'s private `parse/1`, and
  the two named exceptions it rescues, `ArithmeticError` and `CaseClauseError`
  (`lib/riddler/template.ex:210` and `:213`).
- `Riddler.Finding.position/2`, building the map only for two positive
  integers, and its fallback answering `nil`
  (`lib/riddler/finding.ex:97` and `:101`).
- The document door re-reporting a refusal as `document.invalid_template` and
  carrying the wrapped finding's position, absent and all
  (`lib/riddler/screens/document.ex:586` and `:590`).
- The span appended from the position rather than from the numbers it was
  built out of (`lib/riddler/template.ex:538` and `:539`).
- The count of sites setting `:position` in `lib/` is still three:
  `lib/riddler/template.ex:518`, `:529` and
  `lib/riddler/screens/document.ex:590`.

Both doors are still pinned by tests, and the suite is green at that SHA (38
doctests, 194 tests, 0 failures): the template door by "a template the parser
refuses without a place is a finding, not a raise" and "a refusal the parser
did not locate names no place in its message"
(`test/riddler/template_test.exs`), and the document door by the
`document.invalid_template` case asserting a `nil` position
(`test/riddler/screens/document_test.exs:462`). The corpus case the amendment
names is in `corpus/templates/render.json`, "A template the parser refuses
without saying where is refused as a parse error, and the finding names no
place".

---

Noted 2026-09-18, campaign RF055, beads rd-54p, rd-5eq and rd-xhv. Three notes
by addition, each read against `main` at `9e5d667`. Nothing above is changed;
each paragraph below says what the text above means now.

**The rule that a kind exposes at most one kind-specific check stands; only the
screens kind's instance of it is history.** The Decision above says that each
kind exposes admit and validate over a raw document, and resolve over a document
and a context, "plus at most one kind-specific check", and the sentence after it
names the instance: "The screens kind's one check is `validate_responses`, which
is what a host calls before it accepts what a visitor submitted." The note of
2026-09-17 headed "**`validate_responses/3` and its arity-4 form are removed by
ADR-0002's amendment of 2026-09-17.**" reads both of the places it names as
history from that date, and one of the two carries a live rule alongside the
dated instance. Read as history only the naming of the instance: the screens
kind's one kind-specific check is now `Riddler.Screens.validate_screen/3` and
its arity-4 form naming the button that was pressed. The rule itself is
untouched and in force: a kind exposes at most one kind-specific check, and the
sentence the Decision puts immediately after it still holds of every kind. "A
kind that wants a second check is a record, because a kind with an open-ended
API is not a contract a second runtime can be held to." ADR-0002's amendment
replaced the instance rather than removing the rule: it decides that
"`validate_responses/3` and `/4` are removed, not deprecated", names
`validate_screen` as the function that takes their place, and says nothing about
how many kind-specific checks a kind may expose. At `9e5d667` the instance reads
as this note states it: `lib/riddler/screens.ex` defines `validate_screen/3`
(`@spec` at `:303`, body at `:305`) and `validate_screen/4` (`@spec` at `:340`,
body at `:342`), and no `validate_responses` function is part of this package's
public surface. The spelling survives inside `lib/` in two places that are not
that surface: the corpus capability `screens.validate_responses` and its case
file (`lib/riddler/corpus.ex:28` and `:121`), which name a capability rather
than a function, and the private runner helper of the same name
(`lib/riddler/corpus.ex:149`), which builds the case's root and calls
`Riddler.Screens.validate_screen/4` when the case names a pressed button
(`:158` and `:159`) and `validate_screen/3` when it does not (`:161` and
`:162`) (rd-54p).

**The list of excluded statifier packages illustrates the rule; it does not
define it.** The note of 2026-09-17 headed "**The packages the no-statifier rule
excludes, named.**" introduces those packages with a colon, and a list
introduced that way reads as a closed definition. Read it open. What the
Decision above excludes is the statifier family's own packages - "No statifier
package appears in this repository's `mix.exs` or `mix.lock`" - and the packages
that note names are that family's members as of the date it was written. A
package that joins the family after that date is excluded by the rule as it
stands, without an edit to the list; a package that is not one of the family's
own is outside the rule whether or not the list happens to name it, which is why
that note names `predicator` and `solid` as outside it. The enumeration stays
rather than reverting to a `statifier*` glob, because the glob states the rule
wrongly: it does not reach `opentelemetry_statifier`, whose package name does
not begin with the word, and it selects by spelling where the rule selects by
membership of the family. At `9e5d667` the rule still holds literally:
`mix.exs` names `predicator` (`:104`) and `solid` (`:105`) as the runtime
dependencies, its one occurrence of the word "statifier" is the deps comment
restating this prohibition (`:95`), and `mix.lock` carries no package of that
family (rd-5eq).

**`resolve_screen/3` answers the screen and the diagnostics its resolution
produced.** The paragraph above on the public runtime of the screens kind names
"`Riddler.Screens.resolve_screen/3`" as the call that "resolves one named screen
of it". Which call resolves one named screen is unchanged; what that call
returns is not what it was when this record was accepted. ADR-0002's amendment
of 2026-09-17, "the screen validated is the screen shown", decides the return
under its section "A single-screen call returns its diagnostics", in these
words:

> **It returns them.** A single-screen call answers with the screen and the
> diagnostics its resolution produced, so a caller is never handed a screen whose
> resolution reported something without being handed the report. `resolve_screen/3`
> answers `{:ok, screen, diagnostics}`, with `diagnostics` the same shape
> `resolve/2` already carries on its resolved document: `missing_variables` and
> `undecidable_conditions`.

That amendment names this record as one of the places the change reaches:
"`resolve_screen/3` is public, is documented with executable examples that match
on `{:ok, screen}`, is cited by ADR-0001 as the call that resolves one named
screen, and is called inside this package by the corpus runner." Its `Status:`
line reads accepted (2026-09-18), and the dated Note that flipped it records the
code half read by anchor at `015f209`: "`resolve_screen/3` answers
`{:ok, screen, diagnostics}` (`lib/riddler/screens.ex`, its `@spec` and body),
so the single-screen call returns the diagnostics its resolution produced." At
`9e5d667` it still reads that way: the `@spec` is
`resolve_screen(Document.t(), term(), map()) :: {:ok, Resolved.screen(),
Resolved.diagnostics()} | {:error, :no_such_screen}` (`lib/riddler/screens.ex:206`
and `:207`), and the body answers `{:ok, resolved, order(diagnostics)}` (`:215`)
for a screen it finds and `{:error, :no_such_screen}` (`:211`) for one it does
not. Read the sentence above as naming which call resolves one named screen, and
ADR-0002 as deciding what that call returns (rd-xhv).

---

## Amendment, 2026-09-18: the conformance corpus lives in this repository

Status: proposed

This record decided that the conformance corpus is authored here and emitted
into a separate corpus repository, and it made that emitted copy part of how
the corpus reaches a second runtime: a mix task writes it, and a drift check in
this repository's CI fails when the copy and the cases disagree. That separate
repository is archived. It was a mirror with no consumer and no package of its
own, and the drift check turned every corpus-changing request here red until a
second request landed in a repository nobody read. This amendment changes what
the record decides about where the corpus is and how a second runtime gets it.

Recorded for campaign RF055, bead rd-4lk, against `main` at `a72788a`. The
request carrying this amendment removes the drift job in the same commit; it
changes nothing under `lib/`, `test/`, `corpus/` or `priv/`.

### What the record now decides

**The conformance corpus lives in this repository.** The cases are in
`corpus/` and the JSON schemas are in `priv/schemas/`, beside the code that has
to satisfy them, and that is where they are read from. There is no second
repository holding a copy that this repository is obliged to keep in step with,
and no record, gate or job here depends on one. The paragraph above headed
"**The conformance corpus is authored in this repository and emitted into
`riddler_spec`.**"
is read under this amendment: the authoring half stands, the emitting half no
longer names a destination this package depends on, and the drift check that
sentence promises is gone.

**A second runtime vendors the corpus from a tag of this repository and
records the tag it took.** That is how a runtime in another language is held
to these cases: it copies `corpus/` and `priv/schemas/` out of a named tag,
writes down which tag, and re-vendors deliberately when it means to move. The
sibling condition package is the precedent - its corpus is in its own
repository and its TypeScript sibling vendors it at a tag - and the same shape
applies here. A vendored copy is an artifact of the tag it was taken from, and
a vendoring consumer that does not record the tag has no way to say which
contract it implements.

**The corpus runner and its tests are the gate.** `Riddler.Corpus` runs each
case through the function its `capability` names and compares the answer to
the one the case states (`lib/riddler/corpus.ex`, its authored case and schema
file lists at `:25` and `:32`, read at `a72788a`), and
`test/riddler/corpus_test.exs` runs every one of those files that way as part
of `mix quality` (its file lists at `:30`, `:37` and `:38`, same SHA). A case
this implementation does not satisfy is a red suite here. That is the whole
check that the corpus describes the reference runtime, and it runs inside this
repository against nothing outside it.

**No cross-repository job gates this package.** The `drift` job the sentence
above promised is removed from `.github/workflows/ci.yml` by the request that
carries this amendment. The full quality gate is what CI runs, and it answers
about this repository alone.

### Why an amendment and not a note

The test `docs/adr/README.md` states is whether the entry changes an answer the
record gave. It does, twice over. The record answered where the corpus is
emitted with a named second repository, and answers it here with: nowhere as
a matter of record; a consumer vendors it from a tag. The record also answered
what notices when the cases and the contract a second runtime is held to come
apart with a drift check in this repository's CI, and answers it here with:
the corpus runner and its tests, and the tag a consumer recorded. A reader who
followed this record to the other repository was following a sentence this
record decided, and that sentence sends them somewhere archived. This is not a
reading of an already decided sentence, which is what a note records; it is the
sentence answering differently.

### What is unchanged

**The cases and the schemas.** Not one file under `corpus/` or `priv/schemas/`
changes with this amendment, and no case is added, removed or reworded by it.

**Every capability name, and the rule that governs them.** The paragraph headed
"**A corpus capability is named `<kind>.<function>`.**" stands exactly as
written, including its rule that a capability name "is part of the contract and
changes only by a record". Nothing here renames anything.

**That a corpus file is never edited by hand.** The record's reason - that a
copy is an artifact, and an artifact that can be edited is not a conformance
corpus - is unchanged; it now applies to a vendored copy rather than to an
emitted mirror. The authored cases in `corpus/` were always the authored side
and are still edited here, by a request, like any other file.

**The export task.** `mix riddler.corpus` is not changed by this amendment. It
keeps `--to PATH`, `--check` and its environment fallback, it still runs every
case through this implementation and refuses on the first red case before it
writes, and what it writes is still byte-stable. What changes is its standing:
it is an export tool a consumer may use, not a step this package's CI depends
on. Whether its default target and its documentation should still name the
archived repository is left to a later request.

**The earlier notes that quote the archived repository are history.** Two dated
Note entries above name it. The one opening "Noted 2026-09-17, campaign RF051,
bead rd-9j0." says the corpus module and the task ship in the Hex tarball and
describes how the corpus reaches that repository; the one opening "Noted
2026-09-17, campaign RF051, bead rd-pqf." quotes that repository's `bin/lint`
read at a SHA there, in support of keeping the `generated_by` key. Read both as
history from this date: what they decided about this package - that the two
files stay in the tarball, and that the key stays while its value changes - is
untouched and in force; what they report about a repository that is now
archived is a record of how things stood, not a destination. Neither is edited.

**The sibling records' single mentions.** ADR-0002 names the archived
repository once, in the paragraph on an open `type` in the schema, and ADR-0003
names it once, in its Context. Neither is edited here. On this amendment's
acceptance both are read under it, by the precedence rule in
`docs/adr/README.md`: where each says the schema or the cases would have to be
revised in, or are emitted into, that repository, read the schema and the cases
as the ones in this repository, at `priv/schemas/` and `corpus/`. What each
sentence is there to say - that the schema does not enumerate node types so
that a type can be added without revising a schema first, and that a non-Elixir
runtime is held to these cases - is unaffected by where the files sit.

---

Noted 2026-09-18, campaign RF055, beads rd-7l8, rd-q5d and rd-2x5. Four notes
by addition, each read against `main` at `9ec64e7`. Nothing above is changed.

**The conformance corpus does not carry a finding's position, and a second
runtime is not held to one.** The note above headed "**Why a map and not a
tuple, a nested struct or two flat fields.**" argues in part from the fact that
a tuple "has no JSON form, while this package's conformance encoder turns every
answer it emits into JSON for a second runtime". Read that clause as being
about what a HOST reads, and about what the corpus would need if the field were
ever emitted: this package's own conformance encoder does not emit the field
today. It encodes a finding as exactly `code`, `field` and `node_key` and drops
`:position` (`encode_findings/1` in `lib/riddler/corpus.ex` at `:206-210`, read
at `9ec64e7`), for the reason the comment above it gives at `:199-205` in the
same file at the same SHA - "the code is the stable thing a host switches on".
Nothing in that note says the corpus carries the position, and the shape
decision it supports holds on the host-facing reason alone. It is decided here
that the corpus does not gain the field. A position is exactly what two
implementations compute differently: bytes against characters for a column,
one-based against zero-based counting, and where a construct spanning several
lines is said to start. So the contract holds a runtime to `code`, `field` and
`node_key` and to no more, and the position stays a host-facing field that the
reference implementation fills and that a second runtime may fill without being
held to it either way (rd-7l8).

**One corpus case name claims more than the corpus can pin, and is left as it
stands.** The case named "A template the parser refuses without saying where is
refused as a parse error, and the finding names no place"
(`corpus/templates/render.json`, its `name` at `:564`, read at `9ec64e7`)
states an expected answer byte-identical to the case above it, named "An
unterminated output tag is refused as a parse error, and the finding names no
field" (same file, its `name` at `:548`): each expects `compiled` false and one
finding of code `template.parse_error` with a null `field` and a null
`node_key`. Since a finding in the corpus carries no position, nothing in that
expectation distinguishes a refusal that names no place from one that does.
What pins the claim its name makes is a unit test rather than the corpus: "a
template the parser refuses without a place is a finding, not a raise" and "a
refusal the parser did not locate names no place in its message", both in
`test/riddler/template_test.exs` (at `:340` and `:353`, read at `9ec64e7`),
which assert the nil position and the absence of a line and a column from the
message. The case is named here rather than renamed or changed: the name is
accurate about the behaviour, and over-promises only about which of the two
checks does the pinning (rd-7l8).

**Two cross-file cites in the note of 2026-09-17 on the emitter's provenance
header are labelled here with their repository and a SHA.** That note carries
two citations a reader cannot resolve inside this file and that landed without
the label its neighbours carry. The first is the corpus-case schema's own
description, quoted in its paragraph headed "**Why no `corpus_version` field
and why no commit stamp.**": it is `priv/schemas/corpus-case.schema.json` in
THIS repository, its `description` at `:29`, read at `9ec64e7`, where the
quoted words "adds its own provenance header beside them, which is why this
schema does not forbid further keys at the top level" stand. That paragraph's
phrase "either repository" meant, on the date it was written, this repository
and `riddler_spec`, which then held a copy of the same schema; the amendment
above records that the separate corpus repository is archived, so on that
amendment's acceptance read the phrase as a record of how things stood and this
repository's `priv/schemas/` as the live source. The second is the
note-versus-amendment test, cited in the paragraph headed "**Why a note and not
an amendment.**" as "The test `docs/adr/README.md` states": that is
`docs/adr/README.md` in this repository, under its "Note or Amendment" heading,
read at `9ec64e7`. The already-labelled `riddler_spec` `bin/lint` cite at
`84d7a3e` in the same note is read under the amendment above, on its
acceptance, as history too: it is why the `generated_by` key stayed, not a live
gate this package depends on. The note's quotations of passages of this record
itself carry no SHA and need none: what a label is for is a cite a reader
cannot resolve inside this file (rd-q5d).

**The conformance corpus does not ship in the Hex tarball, and that is decided,
not an omission.** The note above headed "**`Riddler.Corpus` and the `mix
riddler.corpus` task ship in the Hex tarball, and that is the decision, not an
accident.**" settles the two `lib/` files and says nothing about the cases. The
cases do not ship, and do not gain a place in the package: `package/0`'s
`files:` list in `mix.exs` is `~w(lib priv/schemas mix.exs .formatter.exs
README.md LICENSE CHANGELOG.md)` (at `:84`, read at `9ec64e7`), and `corpus/`
is not among its entries. Three reasons hold it there. A runtime in a second
language takes the corpus from a tag of this repository and records the tag,
which is how the amendment above says, on its acceptance, that such a runtime
is held to these cases; that route needs git, and an installed package is not a
tag. A host needs the schemas at runtime, which is why `priv/schemas` is in
that list, and a host never runs the cases. And a copy of the cases inside the
tarball would be a second source of them per release, going stale against
`corpus/` on any release cut that did not refresh it, for a reader who has the
better route already. `mix.exs` is not changed by this entry (rd-2x5).

---

Noted 2026-09-18, campaign RF055, bead rd-ai1. Two notes by addition, plus the
paragraph that accounts for the instrument. The five sites enumerated below
were read at `8331e97`, this request's code commit rather than a SHA on `main`,
and no later commit of this request changes any of them. The cites below that
are not to those sites are accounted for as follows. `Riddler.Finding.position/2`
is unchanged by this request, which touches no line of its definition. `span/1`,
named in the first site's bullet, is `lib/riddler/template.ex`'s, and no commit
of this request touches that file at all. `error_position/1` in
`lib/riddler/screens/validation.ex` is read at `8331e97`, the commit that
promoted it, and is unchanged after it. The comment above `compile_pattern/1` in
that same file is read at `6fd2a53`, a later commit of this request, which
rewrote it; the function under it is unchanged by this request. Every code cite
below names the function, the clause or the comment it is about and resolves by
that anchor rather than by a line number, which is also what a rebase merge
rewriting either SHA calls for.
Nothing above is changed; each paragraph below says what the text above means
now.

**Five sites in `lib/` set `:position`, and the count moving is what this
record anticipated.** The note above headed "**`Riddler.Finding` carries a
source position, and this record is where that is decided.**" says under
"**Which findings carry it.**" that "Three sites in `lib/` set the field and no
others", and the amendment below it headed "a placeless parse refusal is a
finding with a nil position" restates that under "**The count of sites is
unchanged.**" Both sentences were true of the code they were read against.
`docs/adr/0002-element-document.md` then recorded, under "**A count in ADR-0001
moves with this, and belongs to that record.**", that `response.undecidable`
had become a fourth site, and said of this record that it "is where its own
count is stated and where it is restated". This is that restatement, and the
count is five. Every occurrence of a `:position` key on a `Riddler.Finding`
literal in `lib/` was enumerated at `8331e97`, and these are all of them:

- The two clauses of `Riddler.Template` that build a template refusal: the
  parse-failure clause,
  `defp finding({line, column, @parse_error, nil, reason})`, which carries the
  position it built and appends the same place to its message through `span/1`,
  and the subset clause, `defp finding({line, column, code, name, lead})`,
  which takes the pair through `Riddler.Finding.position/2`
  (`lib/riddler/template.ex`, the `position:` assignment in each).
- The `document.invalid_template` finding that re-reports a template refusal
  against the template a document node writes, carrying the position of the
  refusal it wraps (`lib/riddler/screens/document.ex`, the `%Finding{}` built
  inside `defp refusals(source, field, key) when is_binary(source)`, its
  `position: finding.position`).
- The `document.invalid_condition` finding, which is the site this request adds
  (`lib/riddler/screens/document.ex`,
  `defp invalid_condition(detail, key, position)`).
- The `response.undecidable` finding
  (`lib/riddler/screens/validation.ex`,
  `defp undecidable_finding(%{key: key, condition: condition}, root)`).

`document.invalid_condition`, the third bullet above and the fourth of the five
sites, is what this request adds. The paragraph above headed
"**Why some of those `nil`s are the way they are is filed rather than
explained.**" says "Three of them are defects in this package and not decisions
of this record", on the ground that "a record cannot be made true about
behaviour that is wrong", and the three `nil`s it names are
`document.invalid_condition`, `document.invalid_pattern` and
`response.undecidable`, alongside a fourth defect that is a raise rather than a
`nil`. Of those three, `response.undecidable`'s was resolved by the earlier
request and recorded on `docs/adr/0002-element-document.md`, and the raise by
the amendment above. What this request does with the other two is the rest of
this entry. The first is named there as
"`document.invalid_condition` obtains a place for a condition the compiler
refused and does not carry it". That one is fixed here.
The condition compiler locates a condition it refuses, and the place now
reaches the finding through `Riddler.Finding.position/2` by way of
`error_position/1` in `Riddler.Screens.Validation`, the same helper the
response check reads it with, which is `@doc false` as `compile_pattern/1` in
that module already is and no part of this package's documented surface. A
condition that is not a string never reached the parser, has no place, and
still carries none. The rule this record states is untouched: the field is set
by which checks carry a place, and a check that has one now carries it.

**`document.invalid_pattern` carries no place, and that is a recorded ground
here rather than a filed defect.** The paragraph above files the second of the
three as "`document.invalid_pattern`'s place is discarded a layer below the
finding". What is discarded is an offset, and an offset is not a place.
`compile_pattern/1` in `Riddler.Screens.Validation` is the one function in this
package that turns a `pattern` source into a regular expression, and it
compiles the author's expression inside the anchors that format applies, so
what `Regex.compile/1` hands back on a refusal is a reason and a byte count
into that anchored string. What the count counts to is not one thing. Ten
refusals were run against `Regex.compile/1`, and these are the runs made
rather than a classification of every refusal that compiler can answer. The
offset column is the raw one, against the author's expression alone; the
anchored column is the same source through the form `compile_pattern/1`
compiles, which adds five bytes in front and three behind.

| source | bytes | reason | offset | anchored |
|---|---|---|---|---|
| `"x)y"` | 3 | unmatched parentheses | 1 | 8 |
| `"a{2,1}bcd"` | 9 | numbers out of order in {} quantifier | 5 | 10 |
| `"ab[z-a]cd"` | 9 | range out of order in character class | 5 | 10 |
| `"ab\nc**d"` | 7 | nothing to repeat | 5 | 10 |
| two two-byte characters, then `"(?<n>x)(?<n>y)tail"` | 22 | two named subpatterns have the same name | 15 | 20 |
| `"(?Pxyz)tail"` | 11 | unrecognized character after (?P | 3 | 8 |
| `"a(b"` | 3 | missing ) | 3 | 11 |
| `"abc\n[def"` | 8 | missing terminating ] for character class | 8 | 16 |
| two two-byte characters, then `"[a"` | 6 | missing terminating ] for character class | 6 | 14 |
| `"a\\"` | 2 | \ at end of pattern | 2 | 10 |

What the ten show is this. For the first six the offset lands at the defect or
at the character that closes it: the unmatched `)` is at byte 1 and the answer
is 1; `{2,1}` closes at byte 5 and the answer is 5; `[z-a]`'s out-of-order
bound is at byte 5; the doubled `*` on the second line is at byte 5; the
repeated group name closes at byte 15; and the character `(?P` does not admit
is at byte 3. For the last four - three unterminated constructs and a trailing
backslash - the answer is the end of the input instead, equal to the byte
length in each case, the defect being detected only when the scan runs out.
And the count is bytes and not characters: the duplicate-name run answers 15
where the character count to the same place is 13, and the unterminated class
after two two-byte characters answers 6 where that source is 4 characters
long.

The anchoring is not a constant shift either. It moves five of the first six
by exactly the five bytes it adds in front, which is what the table's last two
columns show for every row but the first and the last four; the unmatched `)`
moves by seven, because the offset relocates onto the closing parenthesis of
the wrapper rather than staying on the author's; and the trailing backslash
comes back under a different reason as well, "missing )" where the raw form
said the backslash was at the end of the pattern.

So a line and a column derived from that offset would be right for some
refusals and wrong for others, all under one finding code, and a field a host
can trust for some findings of a code and not for others is worse for that
host than a field that is never there. On that ground the position stays
`nil`, the sentence goes on naming no place, and the runs are recorded in
`lib/` in the comment above `compile_pattern/1` so that a later reader does
not take the offset for a place. Whether the refusals whose offset does land
at the defect should carry one anyway is a question for a record to settle and
not for this request. Of the three `nil`s that paragraph files as defects,
then: one was resolved by the earlier request, one is resolved by this
request's code half, and this one is not a defect of the shape that paragraph
describes - read that clause as history from this date, and the `nil` as
decided on the ground above.

**Why a note and not an amendment.** The test these records state in their own
words is whether the entry changes an answer the record gave: an entry is an
amendment where "the rule stated above answers a call one way, and this entry
answers the same call another". What this entry restates is a count of where a
rule renders in `lib/`, and it is the enumeration that moves and not the rule.
The field is still `nil` or a map of a line and a column; it is still set by
which checks carry a place rather than by which inputs have source text; it is
still built only by `Riddler.Finding.position/2`; and no code, field or node
key moves, no refusal is added, and no document that validates clean stops
doing so. This record anticipated the move in the same paragraph that files
three of these `nil`s as defects rather than explaining them, and
`docs/adr/0002-element-document.md` read it that way for the fourth site, "so
the count moving is what it anticipated rather than something it decided
against". The two marks these records name as sufficient for an amendment are
absent: nothing here is a new refusal, and nothing here qualifies a rule an
amendment states. The amendment of 2026-09-18 says "**The count of sites is
unchanged.**" of its own change, and that stays true of it - the guard it
records added no site, and the sites added since are two later requests' and
not its. The paragraph on `document.invalid_pattern` is the other half of the
same answer: it records a status quo, and `docs/adr/README.md`, setting out the
test, says a decided reading stays a note when "its decided reading takes
nothing away, and so changes nothing this record had decided" - the words are
ADR-0002's, said there of itself, and what carries over here is the test and
not the referent. That the code half changes what a host reads
on one finding is not the test either, as this record says of itself elsewhere:
"That a ruling was taken is not the test; if it were, every commit made under
one would amend a record."

---

Noted 2026-09-18, campaign RF055, bead rd-hdm. One note by addition, read
against `f2b4b2a`, this request's code commit rather than a SHA on `main`.
Nothing above is changed; the paragraph below says where two functions the
text above cites now live.

**Two helpers the entries above cite moved to a neutral home.**
`compile_pattern/1`, with the comment above it recording what was run against
`Regex.compile/1`, and `error_position/1` are now in
`Riddler.Screens.Compilers` (`lib/riddler/screens/compilers.ex`, both functions
and that comment read there at `f2b4b2a`), a `@moduledoc false` module neither
the document check nor the response check owns, and both layers call them
there. Nothing else moved with them: the clauses, the specs, the `@doc false`
and the comment are unchanged, and no documented surface was added. The entries
above name both functions, and that comment, in
`lib/riddler/screens/validation.ex`, which is where they were at the SHAs those
entries label; `docs/adr/0002-element-document.md` names the pattern compiler
in that same module as well, and the same holds of it. A cite whose file moved
settles nothing by itself. The test these records state is whether an entry
changes an answer the record gave, and this one changes none: no finding code,
field, position or refusal moves with the file, and what each of those passages
says is as true of the functions in their new module as it was in their old
one. Read each as naming the function and the comment, which is the anchor it
resolves by, rather than the file it was in on its date.

---

## Amendment, 2026-09-18: the screens kind's corpus capability is `screens.validate_screen`

Status: proposed

Recorded for campaign RF055, bead rd-78k, against `main` at `8a86030`. The
request carrying this amendment makes the rename in its code commit, `e0f79df`;
every code cite below is read at that commit and resolves by the anchor it
names rather than by a line number.

### What the record now decides

**The screens kind's validation capability is named `screens.validate_screen`.**
The paragraph above headed "**A corpus capability is named `<kind>.<function>`.**"
enumerates what this version emits: "This version emits
`screens.admit`, `screens.resolve` and `screens.validate_responses` for the one
kind, and `templates.render` for the shared template subset". Read that
enumeration as `screens.admit`, `screens.resolve`, `screens.validate_screen`
and `templates.render`. The rule the same paragraph states is untouched, and it
is the ground for the move rather than a casualty of it: a capability is named
`<kind>.<function>`, and the function the third name spelled is not in this
package. ADR-0002's amendment of 2026-09-17 decides that
"`validate_responses/3` and `/4` are removed, not deprecated", and names
`validate_screen/3` and its arity-4 form naming the button that was pressed as
what takes their place. A capability spelled for the removed pair named nothing.
That a ruling was taken to rename it rather than to let the name stand for the
behavior is not what makes this an amendment; what makes it one is under "Why
an amendment and not a note" below.

**The cases move with the name.** `corpus/screens/validate_responses.json` is
`corpus/screens/validate_screen.json`, its `capability` member reads
`screens.validate_screen`, and the `capability` enum in
`priv/schemas/corpus-case.schema.json` carries the new string in place of the
old one. The runner dispatches on it (`Riddler.Corpus`, its
`defp run("screens.validate_screen", input)` clause and the private helper that
clause calls, `defp validate_screen(document, input)`, in
`lib/riddler/corpus.ex`), and the authored file lists in that module, in
`test/riddler/corpus_test.exs` and in `test/mix/tasks/riddler_corpus_test.exs`
name the renamed file. The note of 2026-09-18 above, in its paragraph headed
"**The rule that a kind exposes at most one kind-specific check stands; only
the screens kind's instance of it is history.**", reports the spelling
surviving inside `lib/` in the capability, its case file and "the private
runner helper of the same name". Read that report as history from this date:
none of those three carries the spelling at `e0f79df`.

**The retired string is an unknown capability, not an alias.** The runner
carries one clause per capability and no fallback clause, so a case file naming
`screens.validate_responses` raises where a case would have run. That is what
this amendment decides and not merely what the code happens to do: two live
names for one behavior would be two contracts, and a second runtime dispatching
on the retired one would be held to a name this record no longer emits. The
refusal is pinned by "the capability string this version retired is an unknown
capability, not an alias" in `test/riddler/corpus_test.exs`, read at `e0f79df`.

**A runtime already held to this corpus has to move, and none is.** The rename
is breaking for any implementation dispatching on the capability string or
reading the case file by name: such an implementation dispatches on
`screens.validate_screen` and reads `corpus/screens/validate_screen.json`
instead. No implementation in another language is held to this corpus at this
date, so nothing is broken by it in fact. The archived sibling repository that
once received an emitted copy is not written to by this request, and the copy
standing there names the corpus as it stood before this date.

### Three corpus wordings corrected in the same request

These change what the corpus claims about itself, not what it asserts about
this package. One is a description in the corpus-case schema and two are case
names. No case answers anything at `e0f79df` that it did not answer before, and
the per-file counts are unchanged.

**The corpus-case schema's `input` description no longer ties the `context` key
to a condition reading it.** It said the capability takes "context where a
condition reads it". That is false as a rule: cases in
`corpus/screens/validate_screen.json` read a `context` path and carry no
`context` key on purpose: the presses among them that validate expect the
`response.undecidable` finding, and the press that declares it validates
nothing expects `ok`, which is what a condition nobody is held to comes to.
The description now says the half appears where the case supplies one,
and that a half the case leaves out is read as an empty map, so a path into it
is undecidable like any other path the root lacks. Description text only: no
type, no required list and no enum but the capability value moves.

**The admit case for a question carrying `answer_options` claims only what the
admit capability compares.** It was named "A question carrying answer_options,
the field reserved for the select question types, is admitted with no finding
and the field is dropped". `screens.admit` compares `admitted` and `findings`
and nothing else, so a second runtime that carried the field through would pass
the case while failing the claim in its name. The name now ends at "is admitted
with no finding". The drop itself stays pinned, by "does not carry
answer_options, the field reserved for question types this version does not
build" in `test/riddler/screens/document_test.exs`, read at `e0f79df`, which
refutes the key on the admitted node.

**A validation case names its screen by what the screen carries rather than by
the case before it.** The case named "The validating button on that same screen
returns the finding the root could not decide" took "that same screen" from its
neighbor, which is true of the file as it stands and stops being true the next
time a case is inserted between them. It is now named "The validating button on
a screen carrying a condition the root cannot decide returns the finding". The
note of 2026-09-18 on `docs/adr/0002-element-document.md` that quotes the old
name quotes both it and `corpus/screens/validate_responses.json` at the SHA it
labels, `3ff9a42`, where both stand. It is not edited, and what it records
there - that `response.undecidable` is the expected code of that case - is
unaffected by what the case and its file are called after this date. The same
reading applies to every other place in that record naming the case file by
its old path: each is read at the SHA it was written against, and the cases it
points at are the ones in `corpus/screens/validate_screen.json` from this date.

### Why an amendment and not a note

The test `docs/adr/README.md` states, under its "Note or Amendment" heading, is
whether the entry changes an "answer the record gave". This entry changes one.
The record answered what this version emits for the one kind by naming the
capabilities, and one of the names it gave is not a name this version emits
after this request. That is the enumeration answering differently, not a
reading of it: a second runtime that dispatched on the name this record printed
would find no case file under it and no clause in the reference runner for it.

The mark `docs/adr/README.md` names as sufficient without being necessary is
present as well. "One is a new refusal", and this entry records one: a case file
naming `screens.validate_responses` is refused by the runner where before it
ran. A note would not carry it, because a note is where "its decided reading
takes nothing away", and this takes a capability name away from a second
runtime.

### What is unchanged

**The rule that names capabilities.** "A corpus capability is named
`<kind>.<function>`", and a capability name "is part of the contract and
changes only by a record". Both stand, and this entry is the record the second
sentence asks for. The amendment above headed "the conformance corpus lives in
this repository" says under its own "What is unchanged" that the capability
paragraph "stands exactly as written" and that "Nothing here renames anything";
that remains a true account of that amendment, which renamed nothing. This one
does, and by the route that paragraph names.

**Every other capability, and every case's answer.** `screens.admit`,
`screens.resolve` and `templates.render` are untouched, and no case in any file
answers anything it did not answer before. What a host calls is untouched too:
`Riddler.Screens.validate_screen/3` and its arity-4 form are not changed by this
request, and no public function of this package is added, removed or altered by
it.

**Where the cases live and how they are read.** This entry decides a name, not
a location: the cases stay in `corpus/`, the schemas in `priv/schemas/`, and
the corpus runner and its tests remain what holds this package to them.

**That prose above naming `validate_responses` is history.** The note of
2026-09-17 headed "**`validate_responses/3` and its arity-4 form are removed by
ADR-0002's amendment of 2026-09-17.**" already reads the two places that name
the removed functions as history from that date, and the note of 2026-09-18
quoted above reads the naming of the instance the same way. Neither is edited
here, and this entry adds the capability to what those two places are read as
history about.

---

## Amendment, 2026-09-18: a position's column counts in the unit of the parser that located it

Status: proposed

Recorded for campaign RF058, bead rd-i3a, against `main` at `66749fe`. The
request carrying this amendment makes its moduledoc and typedoc text and adds
its tests in its code commit, `a3a134d`; every code cite below is read at that
commit and resolves by the anchor it names rather than by a line number.

### What the record now decides

**A finding's column counts in the unit of the parser that located it, and
this package converts neither.** The note of 2026-09-17 headed
"**`Riddler.Finding` carries a source position, and this record is where that
is decided.**" gives the field as a map of a line and a column "with both
numbers one-based and counting bytes, as the parser's own locations do". Read
that as: both numbers one-based, and the column counting in the unit of the
parser whose location it is. A column the template parser gave counts bytes. A column the condition
compiler or the evaluator gave counts characters. When that note was written
every site took its place from the template parser, so the two halves of its
clause agreed; the sites the condition compiler and the evaluator locate came
later, and with them the halves came apart. The two units give the same column
where no multi-byte character stands before the place on its line, and differ
by the extra bytes of each one that does.

**Which finding gives which.** These are the sites in `lib/` that set
`:position` at `a3a134d`, and the unit each one's column counts:

| site | finding code | column counts |
|---|---|---|
| the parse-failure clause of `finding/1` in `Riddler.Template` | `template.parse_error` | bytes |
| the subset clause of that same function | `template.tag_not_allowed`, `template.filter_not_allowed` | bytes |
| the re-wrap in `refusals/3` in `Riddler.Screens.Document` | `document.invalid_template` | bytes, being the wrapped refusal's |
| `invalid_condition/3` in `Riddler.Screens.Document` | `document.invalid_condition` | characters |
| `undecidable_finding/2` in `Riddler.Screens.Validation` | `response.undecidable` | characters |

The list is kept by a test rather than by this record. "every site in lib/
that sets a position is named here with its unit", in
`test/riddler/finding_position_units_test.exs` (read at `a3a134d`), reads each
`Riddler.Finding` literal carrying `:position` out of the syntax tree of the
files under `lib/` and fails when the sites it finds and the sites it names
with a unit differ. A site added later fails that test until it is named there with its
unit.

**Each unit is pinned where it is given.** The tests under "a column the
template parser gave counts bytes" and "a column the condition compiler or the
evaluator gave counts characters", in the same file at the same SHA, put two
two-byte characters before the defect at each site and assert the column its
unit gives, after asserting that the two units disagree on that input. The
subset clause is put to each route its place arrives by: the parser refusing a
tag it does not know, the allowlist walk reading a filter's location and a
tag's, and the check that locates a liquid tag. `response.undecidable` is put
to the compiler's place and to the evaluator's.

**The units are the dependencies'.** They are what `solid` 1.3.4 and
`predicator` 9.4.1 answer, the versions `mix.lock` resolves (read at
`a3a134d`). A release of either that changed its unit turns the tests above
red rather than moving a host's columns without a word.

**The module text says the same.** The `:position` bullet of
`Riddler.Finding`'s moduledoc and the typedoc of `Riddler.Finding.position/0`
(`lib/riddler/finding.ex`, read at `a3a134d`) name the unit per parser, and
the bullet names it per site.

### Why an amendment and not a note

The test `docs/adr/README.md` states, under its "Note or Amendment" heading,
is whether the entry changes an "answer the record gave". This entry changes
one. The record answered what a column counts with bytes, for every finding
carrying one. For `document.invalid_condition` and `response.undecidable` this
entry answers characters. A host that read the record and mapped a condition
finding's column onto an editor as a byte offset read an answer that this
entry takes back. That the code does not change is not the test either, in
the same way that changing it is not: no finding carries a number after this
request that it did not carry before it, and the entry is an amendment for
what it answers, not for what it does.

### What is unchanged

**The numbers.** No site converts, and no finding's position or message names
a different line or column than it did at `66749fe`. Converting one unit into
the other is not decided here: a column in a single unit would be a behaviour
change for every host reading the sites that convert.

**The field.** It is still `nil` or a map of a one-based line and column,
still built only by `Riddler.Finding.position/2`, and still set by which
checks carry a place. `document.invalid_pattern` still carries none; the byte
offset the note of 2026-09-18 on it tabulates is not a position, and this
entry gives it no unit.

**The corpus.** The note of 2026-09-18 that decides the conformance corpus
does not carry a finding's position names "bytes against characters for a
column" among what two implementations compute differently. That decision
stands. This entry says what the reference implementation fills the field
with; it holds no second runtime to it.
