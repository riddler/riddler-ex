# Riddler

Riddler resolves dynamic content for a host application. A host authors its
screens as JSON documents - copy, questions, buttons, safe templates and the
conditions that show or hide each one - and Riddler answers what one visitor
is shown, given what the host knows about them. The host renders what comes
back.

## Why Riddler

Content that changes with the reader - a returning patron greeted by name, a
guardian's question shown only to a visitor under eighteen - tends to end up
as conditions and string interpolation scattered through a host's views,
where an author cannot see them and nothing checks them until a visitor
trips over one. Riddler moves both into the document: a condition is a
[predicator](https://hex.pm/packages/predicator) expression and a template is
an allowlisted subset of Liquid, so a document is checked on its own before
anyone sees it, every reason it is wrong comes back at once with a stable
code, and resolving it against a visitor is a pure function over decoded
data. Rendering, storage and the editor stay the host's: nothing in this
package draws markup, writes to a store or knows that a browser exists.

## Installation

Add `riddler` to the dependencies in your `mix.exs`:

```elixir
def deps do
  [
    {:riddler, "~> 0.3.0"}
  ]
end
```

> **Pre-1.0.** The public API is still moving, and a minor version may break
> it. Pinning to an exact minor - `~> X.Y.0` - is the recommended way to
> consume the package until 1.0.

## Basic usage

A visitor becomes a library patron through a few screens. The first one
greets a returning visitor by name and asks for an email address for due-date
reminders. Riddler takes the document as decoded JSON, with string keys
throughout, admits and checks it, resolves it against what the host knows,
and checks what the visitor typed before the host accepts it:

```elixir
iex> alias Riddler.Screens
iex> alias Riddler.Screens.Document
iex> document =
...>   Document.admit(%{
...>     "schema_version" => 1,
...>     "id" => "patron_registration",
...>     "screens" => [
...>       %{"key" => "patron_details", "title" => "Get your library card",
...>         "nodes" => [
...>           %{"type" => "text", "key" => "welcome_back",
...>             "condition" => "context.returning == 'yes'",
...>             "text" => "Welcome back, {{ context.first_name }}."},
...>           %{"type" => "text_question", "key" => "reminder_email",
...>             "label" => "Email for due-date reminders",
...>             "required" => true, "format" => "email"},
...>           %{"type" => "button", "key" => "details_next",
...>             "label" => "Continue", "outcome" => "details_submitted"}
...>         ]}
...>     ]
...>   })
iex> {:ok, ^document} = Document.validate(document)
iex> root = %{"context" => %{"returning" => "yes", "first_name" => "Ada"}}
iex> {:ok, resolved} = Screens.resolve(document, root)
iex> Enum.map(hd(resolved.screens).nodes, & &1.key)
["welcome_back", "reminder_email", "details_next"]
iex> hd(hd(resolved.screens).nodes).text
"Welcome back, Ada."
iex> typed = Map.put(root, "responses", %{"reminder_email" => "ada"})
iex> {:error, [finding]} = Screens.validate_screen(document, "patron_details", typed)
iex> {finding.code, finding.node_key}
{"response.format", "reminder_email"}
```

## Documentation

- Learn
  - [Basic usage](#basic-usage): one patron-registration screen admitted, checked, resolved for a returning visitor, and its responses checked.
- Do
  - [Check a document before you save it](https://hexdocs.pm/riddler/Riddler.Screens.Document.html#validate/1): every reason a document is refused, in one pass; the function's reference until a guide page exists.
  - [Resolve the one screen you are about to render](https://hexdocs.pm/riddler/Riddler.Screens.html#resolve_screen/3): a screen and its diagnostics for one visitor; the function's reference until a guide page exists.
  - [Let a Back button skip the response check](https://hexdocs.pm/riddler/Riddler.Screens.html#validate_screen/4): honour a pressed button's `validates`; the function's reference until a guide page exists.
  - [Export the corpus for a runtime in another language](https://hexdocs.pm/riddler/Mix.Tasks.Riddler.Corpus.html): write or compare a copy of the cases and schemas with `mix riddler.corpus`; the task's reference until a guide page exists.
- Look up
  - [The API reference on HexDocs](https://hexdocs.pm/riddler): every public module and function of this version.
  - [`Riddler.Screens.Document`](https://hexdocs.pm/riddler/Riddler.Screens.Document.html): what `admit/1` takes and builds, and every finding code `validate/1` returns.
  - [`Riddler.Screens`](https://hexdocs.pm/riddler/Riddler.Screens.html): the root a condition and a template read, what resolution does to a node, and what a set of responses has to satisfy.
  - [`Riddler.Screens.Registry`](https://hexdocs.pm/riddler/Riddler.Screens.Registry.html): the node types this version knows, by the name a document spells them with.
  - [`Riddler.Template`](https://hexdocs.pm/riddler/Riddler.Template.html): the tags and filters the template subset admits, and how a refusal is reported.
  - [`Riddler.Finding`](https://hexdocs.pm/riddler/Riddler.Finding.html): the fields of a finding, the unit every refusal reports.
  - [The screen document schema](https://github.com/riddler/riddler-ex/blob/v0.3.0/priv/schemas/screen-document.schema.json): the JSON schema of a screen document, shipped in the package under `priv/schemas`.
  - [The conformance corpus](https://github.com/riddler/riddler-ex/tree/v0.3.0/corpus): the cases that hold a Riddler runtime to this contract, which a runtime in another language vendors from a tag of this repository.
  - [The changelog](https://hexdocs.pm/riddler/changelog.html): what changed in each version.
- Understand
  - [What Riddler is for: elements, templates and conditions](docs/explanation/what-riddler-is-for.md): why content moves into a document, why the vocabulary, the template subset and the conditions are each as small as they are, the alternatives turned down, and what is left to the host.
  - [What Riddler is](https://hexdocs.pm/riddler/Riddler.html): content kinds, the seams the package is divided along, and what it depends on.
  - [The decision records](https://github.com/riddler/riddler-ex/tree/v0.3.0/docs/adr): why the screen document, the template subset and the boundary with a host are shaped as they are.

## Compatibility

Riddler needs Elixir 1.18 or later (`elixir: "~> 1.18"`). It has two runtime
dependencies: [predicator](https://hex.pm/packages/predicator) `~> 9.4`,
which evaluates the conditions a document declares, and
[solid](https://hex.pm/packages/solid) `~> 1.3`, which parses the template
subset. Its functions take a document already decoded, so a host decodes
with whichever JSON library it already uses. This version reads documents
that declare `schema_version` 1 and ships one content kind, `screens`; a
document naming no `kind` is a screen document. Nothing in the statifier
family is a dependency: a host that uses both calls into Riddler, never the
reverse.

## License

MIT. See [LICENSE](https://github.com/riddler/riddler-ex/blob/v0.3.0/LICENSE).
