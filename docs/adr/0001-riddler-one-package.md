# ADR-0001: Riddler is one package that consumes the statifier family, and the element document is its contract

Status: proposed

## Context

Riddler is a runtime for dynamic content and forms: a host application declares
what a visitor is shown, and something has to decide what that declaration
means. The statifier family already decides a different question - a chart
decides what happens next, and `statifier-ex`, `statifier_blocks` and their
siblings own that. The two meet in a host application, where a workflow reaches
a screen and a screen has to be resolved into the elements a visitor sees.

Which way that arrow points is the question this record settles, and it has to
be settled before any module exists, because the answer decides what may appear
in `mix.exs`. A dependency added for convenience is very hard to remove once a
second package relies on the coupling it creates.

Two pieces of public evidence bound the answer. The fixture
`priv/fixtures/signup_screens.json` in `statifier_examples` (read at `9d288c9`)
is an element document written by hand: three screens of a signup wizard, each
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

**Riddler ships as one hex package, `riddler`.** Elements, the template subset
and, later, feature flags are modules in that package rather than packages of
their own. The package is split along one of its seams only when a consumer
needs that piece without the others; a seam that no consumer has asked to use
alone is a module boundary, not a package boundary.

**The element document is the contract.** It is JSON, it carries a
`schema_version`, and it is what both sides of the boundary agree on - not a
struct, not a function signature, not a wire format negotiated per host. A
change to what the document admits is a change to the contract and is breaking
for every host holding one.

**This package is the reference implementation of that contract, and it resolves
server-side.** Resolution happens here, against a host-supplied `context`;
rendering happens in the host. Nothing in this package renders, stores, or
assumes a browser. A second runtime in another language is held to this
package's behavior, not the reverse.

**The public runtime is three pure functions over decoded data.**
`Riddler.Elements.Document.admit/1` and `Riddler.Elements.Document.validate/1`
say what the vocabulary admits and why a document is refused;
`Riddler.Elements.resolve/2` resolves a document against a context;
`Riddler.Elements.validate_responses/3`, and its arity-4 form taking options,
say what a set of responses has to satisfy before a host accepts it. They are
pure: same inputs, same outputs, no process state, no I/O. Surface beyond those
functions is added by a record, not by a commit.

**The conformance corpus is authored in this repository and emitted into
`riddler_spec`.** The cases live beside the code that has to satisfy them; a
mix task emits them, with provenance naming the commit they were emitted from,
and a drift check in this repository's CI fails when the emitted corpus and the
cases disagree. A corpus file is never edited by hand in `riddler_spec`: the
emitted copy is an artifact, and an artifact that can be edited is not a
conformance corpus.

**The core never depends on the block editor or on any statifier package.**
No statifier package appears in this repository's `mix.exs` or `mix.lock`. An
editor that authors element documents is served by a later adapter package that
depends on both sides; it is not served by a dependency here.

**`predicator` and `solid` are the runtime dependencies, and they are the only
ones.** `predicator` evaluates the conditions a document declares; `solid`
parses the template subset. A third runtime dependency is a decision to record.

**A container's winner replaces the container in the resolved output.** A
resolved document is the same shape as the document it came from, with the
containers gone: a host that can render a document can render a resolved one,
and nothing downstream needs to know a container was ever there.

## Consequences

Renderers, persistence, scheduling and the admin are the host's, or later
packages'. A feature this package could plausibly grow - a renderer, a store, a
transport - is out until a record puts it in.

Two records follow from this one and are forthcoming. ADR-0002 decides the
element document v1: the envelope, what a screen is, the node vocabulary, keys,
conditions, `writes`, outcomes, the variant container, and what a resolved
screen is. ADR-0003 decides the template subset: the allowlist, compile-time
refusal, text-only output, and the render modes. This record delegates every
enumeration to them and to the tests of the code halves that implement them; it
enumerates nothing itself.

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
to it. ADR-0002 and ADR-0003 carry the typespecs for the document and the
template subset.

One sentence needs illustrating - that the element document, not a struct, is
the contract. The public fixture `statifier_examples`
`priv/fixtures/signup_screens.json` (at `9d288c9`), in outline with its
`metadata` block and its node lists elided, is:

```json
{
  "schema_version": 1,
  "id": "edoc_signup_screens",
  "screens": [{ "key": "account", "title": "Create your account", "nodes": [] }]
}
```

That is what a host authors and what this package is given. It is JSON on both
sides of the boundary: no host constructs an Elixir struct to talk to this
package, and no runtime in another language is disadvantaged by the fact that
the reference implementation is written in Elixir.

---

Recorded 2026-09-14, campaign RF049, bead rd-1dt.
