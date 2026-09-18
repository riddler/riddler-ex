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
counting bytes, as the parser's own locations do. Every template refusal sets
it. The parser this package pins locates every error it reports -
`Solid.Parser.Loc` enforces a line and a column, both `pos_integer`, and
`Solid.ParserError`'s own typespec declares its metadata carries both - so a
template refusal with no place is not a state that arises at that version.
`Riddler.Finding.position/2` declines to build half a span anyway. That is
defence against a parser that stopped locating, not a fork in what this
package does; and that the parser always locates is an assumption about a
dependency rather than anything this package enforces, recorded here because
an upgrade could retire it without a line of this package changing. A document
finding coded `document.invalid_template` sets it when it wraps a refusal that
has
one: `lib/riddler/screens/document.ex` re-reports such a refusal against the
template a node writes, and it carries that refusal's position as well as
naming it in the sentence it builds, because the place is a place in source
text the document supplied.

The field is `nil` everywhere else, and the rule is which checks OBTAIN a place
rather than which inputs have source text. Those are not the same set, and
obtaining a place is not the same as carrying one either.
`document.invalid_condition` is built on two paths and only one of them obtains
a place. Where the condition is source the compiler refused and gave a place
for, `describe/1` in that same file takes the line and the column out of the
compiler's error to build the message, so the sentence ends in a place the
finding does not carry: that is a `nil` the field is OWED, named here so this
rule is not read as a claim that a condition has no place. Where the condition
is not source at all - a number where a string belongs, which is the malformed
document this check exists to refuse - there is no compiler error, no place to
take, and the message ends in the offending value instead; that is an ordinary
`nil`. One code, two paths, so a host reading the code alone is promised
neither. Everything else obtains no place at all: the checks about the document
as data, which is what most document findings are, exactly as `:node_key` is
`nil` for a template finding; a field refused for not being template source at
all, which also carries the code `document.invalid_template`, so a host
switching on that code alone is not promised a span by it; and the findings
about a visitor's responses - `response.required`, `response.format`,
`response.out_of_range` and `response.undecidable` - which report a submission
against a screen rather than refusing authored source. `response.undecidable`
is the one worth naming beside the condition cases above, because it too is a
check over a condition and a reader who stopped at those would expect it here:
it fires where a condition the document compiled cannot be DECIDED against the
root a host handed in, so nothing was refused at a place and there is no place
to obtain. Where there is a position the refusal's `:message` names
it too and goes on naming it: a person reading a finding reads one sentence,
and the field is the same fact in the form an editor can act on without parsing
that sentence. The field and the checks that pin it are added by this request
and so are citable at no earlier SHA; at `4208433` the struct carried four
fields and the line and column existed only inside the message, although
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
