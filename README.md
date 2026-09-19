# Riddler

> **Pre-1.0.** The public API is still moving, and a minor version may break
> it. Pinning to an exact minor - `~> X.Y.0` - is the recommended way to
> consume the package until 1.0.

`riddler` is a dynamic content runtime: a host authors content as JSON
documents - screens now; emails, images and feature flags forthcoming - and
Riddler resolves each against a visitor's context; the host renders, sends or
serves what comes back.

A content kind is a document shape, a resolved shape, a registry and a corpus
capability, and this version ships exactly one: `screens`. A screen document is
a host application's JSON declaration of the content and forms a visitor is
shown - a screen of a signup wizard, a set of questions, a block of copy that
varies by audience. It carries a `schema_version` and a `kind`, and it is the
contract between the host that authors content and any runtime that shows it;
this package is the Elixir runtime for that contract, as pure functions over a
decoded document and a context map.

Conditions are evaluated by [predicator](https://hex.pm/packages/predicator)
and templates are parsed by [solid](https://hex.pm/packages/solid). There is no
renderer, no persistence and no editor inside this package, and nothing in the
statifier family is a dependency of it.

## Installation

```elixir
def deps do
  [
    {:riddler, "~> 0.2.0"}
  ]
end
```

## What it answers

Every example below is a doctest: `test/readme_test.exs` runs this file, so a
snippet that stops being true fails the suite rather than sitting here being
wrong. The two worked domains are a signup wizard and credit-card processing,
as they are everywhere in this family. The installation snippet above carries
no `iex>` prompt and is not an example.

### Is this a document, and is it right?

`Riddler.Screens.Document.admit/1` turns decoded JSON - string keys
throughout, as `Jason.decode!/1` gives - into the struct the rest of the
package reads, and answers `nil` for an input that is not a screen document
at all. `Riddler.Screens.Document.validate/1` takes that struct and returns
*every* reason the document is wrong, so an author fixing what they wrote
learns everything in one pass. Neither consults a context: a document is wrong
or right before a visitor exists, which is what lets an editor answer an author
while the author is still looking at it.

    iex> alias Riddler.Screens.Document
    iex> document =
    ...>   Document.admit(%{
    ...>     "schema_version" => 1,
    ...>     "id" => "edoc_signup",
    ...>     "screens" => [
    ...>       %{
    ...>         "key" => "account",
    ...>         "title" => "Create your account",
    ...>         "nodes" => [
    ...>           %{"type" => "heading", "key" => "account_heading",
    ...>             "level" => 1, "text" => "Create your account"},
    ...>           %{"type" => "text", "key" => "account_greeting",
    ...>             "condition" => "context.returning == 'yes'",
    ...>             "text" => "Welcome back, {{ context.first_name }}."},
    ...>           %{"type" => "text_question", "key" => "work_email",
    ...>             "label" => "Work email", "required" => true,
    ...>             "format" => "email"},
    ...>           %{"type" => "button", "key" => "account_next",
    ...>             "label" => "Continue", "outcome" => "account_submitted"}
    ...>         ]
    ...>       }
    ...>     ]
    ...>   })
    iex> {:ok, ^document} = Document.validate(document)
    iex> Enum.map(hd(document.screens).nodes, & &1.key)
    ["account_heading", "account_greeting", "work_email", "account_next"]

A document that is *absent* and a document that is *wrong* are different
answers. `admit/1` refuses only what the published document schema refuses - a
spine that is not a document's, or a field the schema types holding a value of
another type; everything else is admitted and refused by `validate/1`, one
finding per thing wrong, each carrying a stable `code` a host switches on
rather than wording.

    iex> alias Riddler.Screens.Document
    iex> Document.admit("a string is not a document")
    nil
    iex> wrong =
    ...>   Document.admit(%{
    ...>     "schema_version" => 1,
    ...>     "id" => "edoc_signup",
    ...>     "screens" => [
    ...>       %{"key" => "account", "title" => "Create your account",
    ...>         "nodes" => [%{"type" => "text_question", "key" => "Work Email"}]}
    ...>     ]
    ...>   })
    iex> {:error, findings} = Document.validate(wrong)
    iex> Enum.map(findings, &{&1.code, &1.field})
    [{"document.invalid_key", "key"}, {"document.missing_field", "label"}]

The envelope's `kind` names the content kind the document belongs to. It is
optional and it defaults to `screens`, so a document that names none is a
screen document and is admitted unchanged; the decided kind is carried through
to the resolved document. A kind this package has no runtime for is a finding
naming the value rather than a document resolved by the wrong kind's rules.

    iex> alias Riddler.Screens.Document
    iex> screens = %{
    ...>   "schema_version" => 1,
    ...>   "id" => "edoc_signup",
    ...>   "screens" => [%{"key" => "account", "title" => "Create your account",
    ...>     "nodes" => []}]
    ...> }
    iex> Document.admit(screens).kind
    "screens"
    iex> {:error, [finding]} = Document.validate(Document.admit(Map.put(screens, "kind", "emails")))
    iex> {finding.code, finding.field, finding.node_key}
    {"document.unknown_kind", "kind", nil}

### What does one visitor see?

`Riddler.Screens.resolve/2` answers the other question: given a root of
`"context"` - what the host knows - and `"responses"` - what the visitor has
submitted so far - which nodes are shown, what do their templates say, and
which container won. It is total, and it reports rather than refuses: a node
whose condition evaluates false is hidden silently, because that is the
condition doing its job, while a node whose condition could not be evaluated at
all is hidden *and* reported in `diagnostics.undecidable_conditions`. A visitor
is not shown a node on a guess.

    iex> alias Riddler.Screens.Document
    iex> document =
    ...>   Document.admit(%{
    ...>     "schema_version" => 1,
    ...>     "id" => "edoc_signup",
    ...>     "screens" => [
    ...>       %{
    ...>         "key" => "account",
    ...>         "title" => "Create your account",
    ...>         "nodes" => [
    ...>           %{"type" => "text", "key" => "account_greeting",
    ...>             "condition" => "context.returning == 'yes'",
    ...>             "text" => "Welcome back, {{ context.first_name }}."},
    ...>           %{"type" => "text", "key" => "account_intro",
    ...>             "condition" => "context.returning == 'no'",
    ...>             "text" => "Two questions and you are in."}
    ...>         ]
    ...>       }
    ...>     ]
    ...>   })
    iex> known = %{"context" => %{"returning" => "yes", "first_name" => "Ada"}}
    iex> {:ok, resolved} = Riddler.Screens.resolve(document, known)
    iex> Enum.map(hd(resolved.screens).nodes, &{&1.key, &1.text})
    [{"account_greeting", "Welcome back, Ada."}]
    iex> resolved.diagnostics
    %{missing_variables: [], undecidable_conditions: []}
    iex> {:ok, unknown} = Riddler.Screens.resolve(document, %{})
    iex> hd(unknown.screens).nodes
    []
    iex> Enum.map(unknown.diagnostics.undecidable_conditions, & &1.key)
    ["account_greeting", "account_intro"]

A `variant` is a container: its candidates are considered in order and the
first whose condition holds replaces the container in the output, so nothing
downstream needs to know a container was ever there. A candidate with no
condition wins if it is reached, which is how an author writes a default.

    iex> alias Riddler.Screens.Document
    iex> document =
    ...>   Document.admit(%{
    ...>     "schema_version" => 1,
    ...>     "id" => "edoc_checkout",
    ...>     "screens" => [
    ...>       %{
    ...>         "key" => "card",
    ...>         "title" => "Your card",
    ...>         "nodes" => [
    ...>           %{"type" => "variant", "key" => "card_notice", "nodes" => [
    ...>             %{"type" => "text", "key" => "card_notice_declined",
    ...>               "condition" => "context.last_charge_status == 'declined'",
    ...>               "text" => "That card was declined. Try another."},
    ...>             %{"type" => "text", "key" => "card_notice_default",
    ...>               "text" => "We will charge the card on file."}
    ...>           ]}
    ...>         ]
    ...>       }
    ...>     ]
    ...>   })
    iex> declined = %{"context" => %{"last_charge_status" => "declined"}}
    iex> {:ok, resolved} = Riddler.Screens.resolve(document, declined)
    iex> Enum.map(hd(resolved.screens).nodes, & &1.key)
    ["card_notice_declined"]
    iex> {:ok, resolved} = Riddler.Screens.resolve(document, %{"context" => %{"last_charge_status" => "ok"}})
    iex> Enum.map(hd(resolved.screens).nodes, & &1.key)
    ["card_notice_default"]

### Are these responses enough to submit?

`Riddler.Screens.validate_screen/3` runs over the *resolved* screen and
nothing else, resolving it against the same root the host resolved with: a
question a condition hid is a question the visitor never saw and cannot be
held to, and a question the host's `context` showed is one that can fail. What
is checked is what the node declares - `required`, `format`, and `min` and
`max` on the numeric formats - and every finding names the node, the field and
a stable code.

    iex> alias Riddler.Screens.Document
    iex> document =
    ...>   Document.admit(%{
    ...>     "schema_version" => 1,
    ...>     "id" => "edoc_checkout",
    ...>     "screens" => [
    ...>       %{
    ...>         "key" => "card",
    ...>         "title" => "Your card",
    ...>         "nodes" => [
    ...>           %{"type" => "text_question", "key" => "billing_email",
    ...>             "label" => "Where should the receipt go?",
    ...>             "required" => true, "format" => "email"},
    ...>           %{"type" => "button", "key" => "card_back", "label" => "Back",
    ...>             "outcome" => "went_back", "validates" => false},
    ...>           %{"type" => "button", "key" => "card_pay", "label" => "Pay",
    ...>             "outcome" => "card_submitted",
    ...>             "writes" => %{"responses.paid" => ["const", true]}}
    ...>         ]
    ...>       }
    ...>     ]
    ...>   })
    iex> Riddler.Screens.validate_screen(document, "card", %{"responses" => %{"billing_email" => "ada@example.com"}})
    :ok
    iex> {:error, [finding]} = Riddler.Screens.validate_screen(document, "card", %{"responses" => %{"billing_email" => "ada"}})
    iex> {finding.code, finding.node_key, finding.field}
    {"response.format", "billing_email", "format"}
    iex> {:error, [finding]} = Riddler.Screens.validate_screen(document, "card", %{})
    iex> finding.code
    "response.required"
    iex> Riddler.Screens.validate_screen(document, "billing", %{})
    {:error, :no_such_screen}

`Riddler.Screens.validate_screen/4` takes the key of the button the visitor
pressed and honours its `validates`. It defaults to true, so a button that says
nothing validates the screen it submits; a button declaring `false` answers
`:ok` without running a check, which is what lets a Back button leave a
half-filled screen.

    iex> alias Riddler.Screens.Document
    iex> document =
    ...>   Document.admit(%{
    ...>     "schema_version" => 1,
    ...>     "id" => "edoc_checkout",
    ...>     "screens" => [
    ...>       %{
    ...>         "key" => "card",
    ...>         "title" => "Your card",
    ...>         "nodes" => [
    ...>           %{"type" => "text_question", "key" => "billing_email",
    ...>             "label" => "Where should the receipt go?", "required" => true},
    ...>           %{"type" => "button", "key" => "card_back", "label" => "Back",
    ...>             "outcome" => "went_back", "validates" => false},
    ...>           %{"type" => "button", "key" => "card_pay", "label" => "Pay",
    ...>             "outcome" => "card_submitted"}
    ...>         ]
    ...>       }
    ...>     ]
    ...>   })
    iex> Riddler.Screens.validate_screen(document, "card", %{}, "card_back")
    :ok
    iex> {:error, [finding]} = Riddler.Screens.validate_screen(document, "card", %{}, "card_pay")
    iex> finding.code
    "response.required"

### What may a template do?

Authored prose that is not fixed text - a label that greets a visitor by the
name they just gave - is a template, and `Riddler.Template` decides which
templates a document may carry. The subset is an allowlist, refusal happens at
compile time with no context at all, and one finding comes back per refused
construct rather than the first one, so a single pass over the findings is
enough to fix the template.

    iex> {:ok, compiled} = Riddler.Template.compile("Hi {{ responses.first_name }}!")
    iex> Riddler.Template.render(compiled, %{"responses" => %{"first_name" => "Ada"}}, :strict)
    {:ok, "Hi Ada!", []}
    iex> {:error, [finding]} = Riddler.Template.compile("{{ responses.first_name | strip_html }}")
    iex> {finding.code, finding.field}
    {"template.filter_not_allowed", "strip_html"}
    iex> {:error, [finding]} = Riddler.Template.compile("{% include 'footer' %}")
    iex> {finding.code, finding.field}
    {"template.tag_not_allowed", "include"}
    iex> {:error, [finding]} = Riddler.Template.compile("Nice to meet you, {{ responses.first_name")
    iex> {finding.code, finding.field}
    {"template.parse_error", nil}

A refused template is a document finding too: `Riddler.Screens.Document.validate/1`
puts every `text`, `label` and `placeholder` through the same subset and raises
`document.invalid_template` naming the construct and the node.

## The conformance corpus

The corpus that holds a Riddler runtime to this contract lives here: the cases
in `corpus/`, beside the code that has to satisfy them, and the JSON schemas in
`priv/schemas/`. There is no second repository to consult; a runtime written in
another language vendors the corpus from a tag of this repository and records
the tag it took.

The gate is the corpus runner and its tests. `Riddler.Corpus` runs each case
through the function its `capability` names and compares the answer to the one
the case states, and `test/riddler/corpus_test.exs` runs every case in
`corpus/` that way as part of `mix quality`, so a case this implementation does
not satisfy is a red suite here rather than a contract someone else is held to.

`mix riddler.corpus` exports a copy for a consumer that wants the cases as
files:

```console
$ mix riddler.corpus --to ../somewhere   # write a copy
$ mix riddler.corpus --check --to ../somewhere   # compare a copy without writing
```

A copy is an artifact and is never edited by hand: it is generated from the
cases in this repository. The task runs every case through this implementation
before it writes anything and refuses on the first red case - a corpus copied
out of a repository whose own suite it does not describe would hold a second
runtime to behavior the reference runtime does not have - and what it writes is
byte-stable, so a comparison reports a real change rather than the passage of
time.

## What Riddler is not

- **Not a renderer.** Resolution answers what a visitor is shown; drawing it is
  the host's, in whatever it draws in. Nothing here emits or escapes markup.
- **Not persistence.** Nothing here stores a document, a response or a visitor.
- **Not an editor.** Authoring tools consume this package; none is inside it.
- **Not a workflow engine.** Charts belong to the statifier family, which this
  package neither depends on nor re-implements. A host calls into this runtime
  when a workflow reaches a screen; this runtime never calls back.

## Architecture decisions

The records in [`docs/adr/`](docs/adr/README.md) carry the decisions this
package is built on - what the screen document is, what the template subset
admits, and where the boundary between this package and its hosts runs.

## License

MIT. See [LICENSE](LICENSE).
