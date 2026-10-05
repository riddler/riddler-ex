# What Riddler is for: elements, templates and conditions

A visitor becomes a library patron through a few screens. The first screen
greets a returning visitor by name; a guardian's question appears only when
the visitor says they are under eighteen; a reminder about overdue fines is
shown only at a branch that charges them. None of that is hard to write. What
is hard is keeping it right as the people who own the wording change it, and
that is the problem this package exists for. This page is about why Riddler
splits content into elements, templates and conditions, why each of the three
is as small as it is, which alternatives it turned down, and what it leaves to
the application that uses it.

## Where content that changes with the reader usually lives

Without a runtime like this one, dynamic content ends up in the host's views.
The greeting is string interpolation in a template file, the guardian question
is an `if` around a form field, and the fines reminder is a conditional in
a controller that looks up the branch's policy. Each piece is reasonable on its
own. Together they have three costs that grow with the registration flow.

The first is that the author cannot see them. The person who writes "Get your
library card" and decides when the guardian question appears is rarely the
person who edits the view, so every wording change becomes a code change, and
the rule for when a question shows is readable only by reading code.

The second is that nothing checks them on their own. A misspelt variable in
the greeting, or a condition comparing an age to a string, is found when a
visitor reaches that screen, not when the author saves it.

The third is that the rules are tied to one renderer. A registration flow that
is later shown in a native app, or read back in a confirmation email, has to
re-implement every condition and every interpolation wherever it is drawn, and
the copies drift.

Riddler's answer is to move all three into a document. The registration flow
becomes JSON that the host stores and an author can edit: screens, each a list
of elements, with the conditions and the templates written in the document
beside the copy they govern. The host still draws the screen, but it draws
what Riddler hands back rather than deciding what to draw.

## Elements: the vocabulary is enumerated

An element is one node of a screen: a `heading`, a `text`, a `text_question`,
a `button`, or a `variant` that holds candidates and keeps the first one whose
condition holds. Every element carries a `key`, unique across the whole
document, and that key is how a finding names the element, how a visitor's
response is addressed (`responses.reminder_email`), and how a host matches a
resolved element to the one it was authored from.

```json
{"type": "text_question", "key": "guardian_name",
 "label": "Name of a parent or guardian", "required": true,
 "condition": "context.age < 18"}
```

The vocabulary is a closed list on purpose. An editor or an importer that
meets a field it does not understand has two choices: drop it quietly or
refuse the document. A vocabulary that drops quietly can lose more than a
third of a document - every condition, every key on anything that is not a question -
and report nothing, which is the failure the screen document was designed
against. So an element type the registry does not know is a finding that
names the type and the key, and a field a type requires is a finding when it
is absent. A field the vocabulary has no name for is carried nowhere, so a
button that spells its `outcome` some other way is refused for the missing
`outcome` rather than accepted and rewritten: a document admitted under two
spellings gets authored under both.

The alternative was an open vocabulary: any element type, any field, passed
through to the renderer. It is easier to extend, and a host could invent a
`branch_picker` element tomorrow without asking anyone. It was turned down
because an open vocabulary is one a second runtime cannot be held to, and one
in which a typo in a type name is indistinguishable from a new type. The cost
is real: a new element type is a change to this package, not to a host. The
JSON schema leaves `type` an open string while the registry enumerates it, so
a document can be carried through a pipe that only checks shape without being
rejected by a schema older than the type; the refusal happens where the
vocabulary is known.

Presentation is the one place the vocabulary stays open. A button's `style`
is passed through whatever it says, because how a primary button looks is
the renderer's business, and a list of styles here would only be a list a
renderer had to argue with.

## Templates: a small slice of Liquid, refused at compile

The greeting "Welcome back, {{ context.first_name }}." is a template. So is
any `text`, `label` or `placeholder` in an element; every other string in a
document is literal text.

Templates are an allowlisted subset of Liquid: output with filters, the
`if`, `unless`, `case`, `for`, `assign`, `capture`, `comment` and `raw` tags,
and the standard string, number, array and date filters plus `default`.
Everything else is refused, including whatever Liquid or the parser grows
later. Three things pushed the subset to be small.

A template is written by an author and evaluated in a process the author
never sees, so it must not be able to reach anything outside the document.
`include` and `render` would need a filesystem the document does not have.
`increment`, `decrement` and `cycle` keep state between renders, so a screen
would read differently the second time it was resolved.

A runtime in another language has to reproduce every construct this package
accepts, identically. Each tag admitted is a porting bill paid by whoever
writes that runtime, and each tag refused is one they never build.

An author should hear that a template is wrong while they are looking at it.
Templates are compiled once with no context at all, and anything outside the
allowlist fails there, with one finding per refused construct rather than the
first. The answer an editor gets at authoring time is the answer the runtime
reaches, because it is the same code.

Two alternatives were weighed. Full Liquid, or a general template language
such as the host's own, would have let authors do more, and every extra
power is also a way to fail when a visitor arrives or to escape the
document. A
denylist of dangerous Liquid tags would have been shorter to write, and it
would silently admit whatever a dependency upgrade introduced; a conformance
corpus cannot be written against a surface that grows on its own.

The templates produce text and escape nothing. That is not an oversight:
escaping is the act of something that knows what it is rendering into, and a
screen resolved here might be drawn into HTML, a native view or a PDF. The
host escapes what it receives, exactly as it escapes any other string, and
the filters that know about markup are refused so that a template cannot
escape by hand and be escaped twice.

A variable the context does not carry renders as the empty string when a
screen is resolved, and it is reported in the resolved document's
diagnostics. A visitor sees the screen rather than an error page because a
first name was missing. The strict mode, where a missing variable is an
error, is for preview and for the corpus, where an author and a test both
need to be told.

## Conditions: predicator expressions, decided or reported

`context.age < 18` is a condition, written in
[predicator](https://hex.pm/packages/predicator), a predicate language that
parses the expression rather than handing it to the host language to
evaluate, so it reaches only the values it is given. A condition reads two
roots: `context`, what the host knows about the visitor (their age, whether
they are returning, which branch they chose), and `responses`, what they have
typed so far.

A condition can go wrong in two different ways, and Riddler treats them
differently. A condition that does not parse is wrong about the document, so
it is a finding when the document is checked, before any visitor arrives. A
condition that parses but cannot be decided for this visitor - the host did
not supply `context.age` - is not the document's fault, so resolution hides
the element and reports it under `undecidable_conditions`. The alternative of
showing it was turned down: a guardian question shown to an adult on a guess
is worse than one held back and reported. A condition that is simply false
hides the element silently, because that is the condition doing its job.

The same rule reaches the check of what a visitor submitted. The screen
validated is the screen shown, so a question a condition hid cannot fail, and
a condition that could not be decided is a finding rather than a pass; a Back
button that opts out of validation is the one way around it.

Conditions could have been host functions named in the document, or a JSON
rule format. Named functions put the rules back in the host's code, where the
author cannot read them. A JSON rule format is readable by machines and by
few people. A predicate language with a parser gives the author a line they
can read and the runtime a refusal it can name; why predicator is a language
of its own rather than either of those is
[its own explanation page](https://github.com/riddler/predicator-ex/blob/main/docs/explanation/why-a-predicate-language-of-its-own.md).

## Why three pure functions and nothing else

A host asks this package three questions about a document. Is it a document,
and is it right? What does this visitor see? Is what they typed enough to
submit? Each is a pure function over the decoded document and, where a
visitor is involved, a map of what is known about them: same inputs, same
outputs, no process, no store. Checking a document returns every reason
it is wrong at once, each with a stable code, so an author fixes it in one
pass. Resolving it never refuses: it reports what it could not decide and
returns the rest.

That shape is what lets the same document be checked in an editor, resolved
in a request, replayed in a test and held to a second runtime by the
[conformance corpus](https://github.com/riddler/riddler-ex/tree/main/corpus),
whose cases live beside the code that has to satisfy them.

## What it leaves to the host

The boundary is as deliberate as the vocabulary.

- **Rendering.** Resolution says what a visitor is shown; drawing it, in
  HTML or anything else, is the host's. Nothing here emits or escapes markup.
- **Storage.** Nothing here stores a document, a response or a visitor. A
  host keeps the registration document wherever it keeps its content, and the
  patron record wherever it keeps patrons.
- **Editing.** Authoring tools call into this package to check a document;
  none is inside it.
- **What happens next.** Moving a visitor from one screen to the next over
  days, with reminders and timeouts, is a workflow engine's job. The statifier
  family does that, and the arrow points one way: an execution that reaches a
  screen calls into Riddler, and Riddler never calls back. A dependency in the
  other direction would make content resolution wait on a chart it has no
  reason to know about.

Those exclusions are what keep the package small enough to port and to trust.
A host that needs any of them already has one; what it lacked was a place
where the content's rules are written down, checked on their own, and decided
the same way everywhere the content is shown.

## Where to read next

- [The README's basic usage](../../README.md#basic-usage): one
  patron-registration screen admitted, checked, resolved and validated.
- [`Riddler`](https://hexdocs.pm/riddler/Riddler.html): content kinds and the
  seams the package is divided along.
- [`Riddler.Template`](https://hexdocs.pm/riddler/Riddler.Template.html): the
  full allowlist and how a refusal is reported.
- [The decision records](https://github.com/riddler/riddler-ex/tree/main/docs/adr):
  the screen document, the template subset and the boundary with a host, as
  decided.
