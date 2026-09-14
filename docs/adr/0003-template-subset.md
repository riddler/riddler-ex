# ADR-0003: The template subset

Status: proposed

## Context

An element document carries authored prose that is not fixed text: a node's
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

An editor validates at authoring time. A host authoring an element document
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
together with `default`. Adding to this list is a change to this record.

**The exclusion list is: `include`, `render`, `increment`, `decrement`,
`cycle`, `tablerow`, `liquid` and `echo`, and every vendor-specific
construct.** `include` and `render` reach for a file that an element document
does not have and a second runtime would have to invent a filesystem to serve.
`increment` and `decrement` and `cycle` carry state between renders, which
makes a rendered document depend on how many times it was rendered. `tablerow`
emits markup, which the text rule below forbids. `liquid` and `echo` are
alternate spellings for constructs already in the allowlist and would double
every corpus case that uses them. A vendor construct is by definition one no
second runtime can be held to.

**Anything outside the allowlist fails at compile, never at render.** A
template is compiled once, without a context, and a template holding a refused
construct is refused there - so the editor's authoring-time answer and the
runtime's answer are the same answer, reached by the same code. A construct
that parsed cleanly and then failed when a visitor arrived would be a defect in
this rule, not an accepted behavior.

**Compilation reports one finding per refused construct, not the first.** An
author fixing a template learns everything wrong with it in one pass.

**Rendered output is text, never markup.** A template produces a string that
means exactly the characters in it. This package does not emit markup, does not
accept markup as a distinguished kind of output, and does not escape: escaping
is the act of a renderer that knows what it is rendering into, and this package
does not. The absence of autoescape is therefore not a hole in this record. A
host that renders into HTML escapes what it is given, exactly as it escapes any
other untrusted string.

**There are two render modes, lenient and strict, and they differ only in what
a missing thing does.** In lenient mode a missing variable renders as the empty
string and the render returns the list of what was missing; it is the runtime
mode, because a visitor should see a screen rather than an error page when an
optional field has not been filled. In strict mode a missing variable or a
missing filter is an error and the render returns it; it is the mode for
preview and for the corpus, because an author and a conformance case both need
to be told. The two modes agree on every template where nothing is missing:
mode is not a second dialect.

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
That is ADR-0002 (the element document, forthcoming). Nothing here decides
transport, authentication, streaming, the identity of a visitor's execution, or
the editor; ADR-0001 left those open and this record leaves them open.

The vocabulary of ADR-0001 holds: a document declares `writes`, a control names
an `outcome`, what a visitor submits is `responses`, and the host-supplied root
is `context`. A template path reads from those roots.

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

Recorded 2026-09-14, campaign RF049, bead rd-61p.
