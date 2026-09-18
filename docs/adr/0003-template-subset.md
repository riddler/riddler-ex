# ADR-0003: The template subset

Status: accepted

## Context

A content document carries authored prose that is not fixed text: a node's
label greets the visitor by the name they just gave, a summary line reads back
what they chose. The public fixture `priv/fixtures/signup_screens.json` in
`statifier_examples` (read at `9d288c9`) already writes it that way - four of
its strings interpolate `responses.first_name` and `responses.email` in Liquid
output tags - so the question is not whether documents carry templates but
which templates they may carry.

Liquid is the language, and `solid` (hex, `1.3.4` as this repository's
`mix.lock` resolves it) is the parser. Liquid as a whole is larger than this
runtime should promise. Three forces narrow it.

Renderers are the host's. ADR-0001 fixed that resolution happens in this
package and rendering does not, so what a template produces crosses a boundary
into code this package does not own and cannot inspect. What crosses has to be
safe to hand to any renderer - a browser, a native view, a PDF, an email body -
without that renderer knowing which of them it is.

A second language has to reproduce the corpus. The cases are authored here and
emitted into `riddler_spec`, and a non-Elixir runtime is held to them. Every
construct this package accepts is a construct that runtime must implement
identically, and every construct it refuses is one that runtime need not build
at all. A large accepted surface is a large porting bill, paid by whoever ports.

An editor validates at authoring time. A host authoring a content document
wants to be told that a template is wrong while the author is looking at it,
not when a visitor reaches the screen. That is only possible if the answer is
knowable before any context exists.

## Decision

**The subset is an allowlist, not a denylist.** What this package accepts is
enumerated; everything else is refused, including constructs Liquid or `solid`
may add later. A denylist would silently admit whatever a dependency upgrade
introduced, and a conformance corpus cannot be written against a surface that
grows on its own.

**The allowlist is: output, a fixed set of tags, and a fixed set of filters.**
Output tags carry a variable path and a chain of filters. The admitted tags are
`if`, `elsif`, `else` and `unless`; `case` and `when`; `for`, including its
`limit` and `offset` arguments; `assign`; `capture`; `comment`; and `raw`. The
admitted filters are the standard string, number, array and date filters,
together with `default`, less the escaping filters the output-mode rule below
refuses. Adding to this list is a change to this record.

**The exclusion list is: `include`, `render`, `increment`, `decrement`,
`cycle`, `tablerow`, `liquid` and `echo`, and every vendor-specific
construct.** `include` and `render` reach for a file that a content document
does not have and a second runtime would have to invent a filesystem to serve.
`increment` and `decrement` and `cycle` carry state between renders, which
makes a rendered document depend on how many times it was rendered. `tablerow`
emits markup, which the output-mode rule below forbids in v1's text mode.
`liquid` and `echo` are alternate spellings for constructs already in the
allowlist and would double every corpus case that uses them. A vendor construct
is by definition one no second runtime can be held to.

**Anything outside the allowlist fails at compile, never at render.** A
template is compiled once, without a context, and a template holding a refused
construct is refused there - so the editor's authoring-time answer and the
runtime's answer are the same answer, reached by the same code. A construct
that parsed cleanly and then failed when a visitor arrived would be a defect in
this rule, not an accepted behavior.

**Compilation reports one finding per refused construct, not the first.** An
author fixing a template learns everything wrong with it in one pass.

**The output mode is declared by the content kind, not by the template.** v1
has one mode, text: a template produces a string that means exactly the
characters in it, this package emits no markup, and it escapes nothing, because
escaping is the act of something that knows what it is rendering into and a
text mode is not rendering into anything. The absence of autoescape is
therefore not a hole in this record: a host that renders text into HTML escapes
what it is given, exactly as it escapes any other untrusted string. A markup
kind - an email's HTML part, an SVG - declares an escaping mode in its own
record, and in such a mode an interpolated value is escaped by default. What
never changes is that the author does not choose: `escape`, `escape_once`,
`newline_to_br` and `strip_html` stay refused in every mode, because escaping
is the mode's job and a template that escapes by hand is a template that
double-escapes under a mode that escapes for it.

**There are two render modes, lenient and strict; they differ only in what a
missing thing does, and they are the caller's choice.** In lenient mode a
missing variable renders as the empty string and the render returns the list of
what was missing. In strict mode a missing variable or a missing filter is an
error and the render returns it. The two modes agree on every template where
nothing is missing: mode is not a second dialect. Each content kind's record
names its default: screens render lenient at runtime, because a visitor should
see a screen rather than an error page when an optional field has not been
filled, and strict is for preview and for the corpus, because an author and a
conformance case both need to be told. A kind for which a missing variable is a
defect rather than a blank - an email, a feature flag - will name strict, and
naming it is that kind's record's job, not this one's.

**`default` is the authored answer for an optional field.** A template whose
variable may be absent says so with `default`, and then it is not missing in
either mode. Lenient mode's empty string is the fallback for what an author did
not anticipate, not the way to write an optional field.

**A host-registered filter contract is part of this version and ships empty.**
A host may need a filter this package does not carry - a currency format, a
domain-specific abbreviation. The shape is fixed now: a registered filter is a
name plus one implementation per runtime, declared to this package so that
compilation accepts the name, with the second runtime obliged to supply its own
implementation of the same name. No filter is registered in this version, and
the registry ships empty; designing the seam now is what keeps a later host
need from becoming a change to the allowlist rule.

**The exact filter list is delegated to the code half's tests.**
`Riddler.Template` and its test file are the enumerating surface: the tests
name every admitted filter and every refused construct, and the corpus emitted
from them is what a second runtime is held to. This record asserts what the categories
are and does not enumerate their members, because a list in prose and a list in
code drift apart and only one of them is executable.

## Consequences

The code half builds `Riddler.Template.compile/1`, which takes template source
and returns either a compiled template or the findings that refuse it, one per
refused construct, without a context; and `Riddler.Template.render/3`, which
takes a compiled template, a context and a mode, and returns the rendered text
together with what was missing in lenient mode or the error in strict mode. Its
tests enumerate the filters.

The corpus carries at least one refusal case per excluded construct, and every
render case is stated in both modes, so a second runtime cannot pass by
implementing only the forgiving half.

A second runtime implements exactly the allowlist. It may use any Liquid
library it likes, provided that library's extra constructs are refused at
compile: passing the corpus means refusing what the corpus says is refused, not
only rendering what it says renders.

An editor can validate a template with nothing but the template, which is what
makes authoring-time validation possible at all.

Nothing here decides how a document declares which of its strings are
templates, what a node is, or when a template is evaluated during resolution.
That is ADR-0002, the screen document. Nothing here decides transport,
authentication, streaming, the identity of a visitor's execution, or the
editor; ADR-0001 left those open and this record leaves them open. Nothing here
decides a markup kind's escaping mode either: the rule above says such a mode
is declared by the kind and escapes by default, and which kind declares which
mode is that kind's record's.

The vocabulary of ADR-0001 holds: a screen document declares `writes`, a
control names an `outcome`, what a visitor submits is `responses`, and the
host-supplied root is `context`, which every kind carries. A template path
reads from those roots.

## Typespecs and worked example

The types are the code half's. This record names no struct and no typespec:
what `compile/1` returns, what a finding is made of, and how a mode is spelled
are `Riddler.Template`'s to declare, and a typespec written here would be a
second source of truth for something the compiler already checks.

One sentence needs illustrating: that a refusal is reached before any context
exists. Take the signup wizard the fixture authors. An allowed template on the
confirmation screen is

```liquid
We will send a verification link to {{ responses.email | default: "your inbox" }}.
```

It compiles: an output tag, a variable path under `responses`, and `default`
from the allowlist. It renders the same text in both modes, because `default`
means nothing is missing either way.

A refused template on the same screen is one that pulls a shared fragment in -
an author's attempt to reuse a footer by naming another file with `include`.
Compilation refuses it with one finding, which names the construct `include`,
says it is not in the allowlist, and points at where in the source it appeared.
That answer is available to the editor the moment the author stops typing: no
visitor, no responses, no context was needed to reach it.

---

Recorded 2026-09-14, campaign RF049, bead rd-61p. Rewritten in place while
still proposed on 2026-09-15, campaign RF049, bead rd-9wd: the text-only rule
became the output-mode rule, which each content kind declares, and each kind's
record now names its own render-mode default.

Accepted 2026-09-15, campaign RF049, bead rd-x59, after a claim-by-claim
reading against `main` (riddler 0.1.0, published). The code half that built
what this record decides is `Riddler.Template.compile/1` and `render/3` behind
the allowlist (PR 5), with the `templates.render` corpus (PR 9); the
output-mode rule and the per-kind render-mode default arrived with the
content-runtime reframe (PR 14). The paragraph above, recording a rewrite made
before this record was accepted, describes the state this Note ends: the record
is accepted from this date, and a further change to what it decides is an
amendment, not an edit in place.

The reading found no claim this record makes that the code does not hold to,
and both of the Consequences claims about the corpus check out: there is a
refusal case for every excluded construct, and every render case is stated in
both modes except the missing-variable pair, which is the one case the modes
are defined to answer differently. One question this record leaves open is
carried as a note by addition: strict mode is stated for a missing variable
and a missing filter, and a variable used only as an `if` or `unless` condition
is neither plainly one nor plainly outside the rule (rd-1jj).

Note, 2026-09-17, campaign RF051, bead rd-1jj. The question the paragraph above
carries by addition - whether a variable that appears only as an `if` or
`unless` condition is a missing variable under strict mode - is decided here.

**Strict mode covers output and iteration positions. A condition operand is a
truthiness test: a variable used only in a condition is not missing when the
root does not carry it, it is `false`.** A template reading
`{% if responses.newsletter %}...{% endif %}` against a root without
`responses.newsletter` renders the branch that holds, in strict mode exactly as
in lenient mode: no error, and nothing named in either mode's missing list.

The rule is positional, not expressional. The condition of an `if`, an `elsif`
or an `unless` is one position, whatever expression stands in it: a bare path, a
comparison such as `{% if responses.plan == "business" %}`, a chain joined by
`and` or `or`. A path the root does not carry, anywhere inside such a condition,
is `false` there and the condition is evaluated with it. `unless` is a condition
position on this rule exactly as `if` is; the tag's name does not change what
its condition is. Positions this rule does not reach keep what they do today: a
`case` subject and an `assign` or `capture` right-hand side read a value rather
than test one, and a missing variable in them is reported under strict mode.

Two things decide it this way. The first is what a visitor should see. A
conditional block is how an author asks whether an optional field was filled,
and when it was not, the right outcome is that the block does not render - a
screen without its optional block, not a screen replaced by an error. Strict
mode exists to tell an author and a conformance case that a template asked for
a value that was not there; a condition did not ask for a value, it asked a
question, and an absent value makes that question false. The second is the
porting bill. Stated by position, the rule is one a second runtime implements
by looking at where the path appears in its own parse tree. Stated by what a
particular engine happens to report, it would be a rule no two runtimes could
agree on.

What the code does today, read at `27faac3`: `Riddler.Template.render/3` in
`lib/riddler/template.ex` passes `strict_variables: true` to `solid` (`1.3.4`,
as this repository's `mix.lock` resolves it) in both modes and sorts what comes
back in its private `missing/2`, so mode decides only whether a missing variable
is an error or a list beside the text. That engine reports a missing `for`
operand, `case` subject and `assign` right-hand side, and does not report a
missing `if` or `elsif` condition. The `if` half therefore already behaves as
decided above, and the asymmetry between a loop operand and a condition operand
is the observation this note settles rather than a behavior it introduces.

`unless` is the one place the code does not yet match, and that is a defect in
the code half rather than a second semantics. At `1.3.4` the engine evaluates an
`if` and an `unless` condition through the same call but keeps that evaluation's
recorded errors only when the branch it renders is the branch that call threw,
so `{% unless b %}A{% endunless %}` against a root without `b` renders `A` and
also reports `b`, where `{% if b %}A{% endif %}` reports nothing. The difference
is the engine's error bookkeeping, not the meaning of the two tags, and this
record decides the meaning. Under this note
`{% unless b %}A{% endunless %}` renders `A` with nothing missing in either
mode, and bringing the code to that is the code half's work, not a change to
what is decided here.

The conformance corpus carries the pair (rd-alj): a variable used only as an
`if` condition and one used only as an `unless` condition, each rendered against
a root that does not carry it, each stated in both modes, each expecting an
empty missing list, a render that succeeds, and the text of the branch that
holds. A second runtime that reports either of them fails the corpus.

---

Noted 2026-09-18, campaign RF055, bead rd-tmv. One note by addition, read
against `main` at `90f5930`. Nothing above is changed.

**A `when` operand is a read position, and the list of positions the rule above
does not reach was not exhaustive.** The note above states its rule by position
and then names both sides of it. On the one side, "The rule is positional, not
expressional. The condition of an `if`, an `elsif` or an `unless` is one
position, whatever expression stands in it". On the other, "Positions this rule
does not reach keep what they do today: a `case` subject and an `assign` or
`capture` right-hand side read a value rather than test one, and a missing
variable in them is reported under strict mode." A `when` operand is named in
neither list. It belongs with the second: a `when` operand is read and compared
against the subject the `case` tag carries, and it reports its missing variable
under strict mode exactly as that subject does.

**What the code does, read at `90f5930`.** The test named "a when operand still
reports the missing variable" (`test/riddler/template_test.exs`) pins both
modes: `{% case "yes" %}{% when responses.newsletter %}A{% endcase %}` rendered
through `Riddler.Template.render/3` against a root that does not carry
`responses.newsletter` answers `{:ok, "", ["responses.newsletter"]}` in lenient
mode and `{:error, ["responses.newsletter"]}` in strict mode. That is the answer
a read position gives, and it is the answer the `case` subject beside it gives:
the test named "a case subject still reports the missing variable", in the same
file and read at the same commit, pins the subject in the same two modes.

**The conformance corpus does not carry a `when` operand case, so nothing here
is complete.** `corpus/templates/render.json`, read at `90f5930`, carries the
case named "A case subject the root does not carry is still reported in strict
mode: a subject reads a value rather than testing one", which states the subject
in strict mode alone, and it carries no case in which a `when` operand is the
missing variable. A second runtime is held to what this entry records only once
the corpus carries it; today just this package's own test does. Whether the
corpus should carry the case is not decided here.

**Why a note and not an amendment.** The rule above answers a call about the
condition of an `if`, an `elsif` or an `unless`, and it gave no answer about a
`when` operand at all. Recording that the rule does not reach one, and that the
position keeps what it does today, takes nothing away: no template that renders
stops rendering, no missing list changes, and no refusal is added. What it fills
is an enumeration that reads as exhaustive and is not, which is where a reader
takes an omission for a decision. Whether a later amendment should bring a
`when` operand under the condition rule - it is a test of a kind, compared
against a subject rather than output - is a question this entry leaves open
rather than settles.
