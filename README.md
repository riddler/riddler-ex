# Riddler

> **Pre-1.0.** The public API is still moving, and a minor version may break
> it. Pinning to an exact minor - `~> X.Y.0` - is the recommended way to
> consume the package until 1.0.

`riddler`: the element document and what can be decided from it. An element
document is a host application's JSON declaration of the dynamic content and
forms a visitor is shown - a screen of a signup wizard, a set of questions, a
block of copy that varies by audience. The document carries a schema version
and is the contract between the host that authors content and any runtime that
renders it; this package is the Elixir runtime for that contract, as pure
functions over a decoded document and a context map.

Conditions are evaluated by [predicator](https://hex.pm/packages/predicator)
and templates are parsed by [solid](https://hex.pm/packages/solid). There is no
renderer, no persistence and no editor inside this package, and nothing in the
statifier family is a dependency of it.

## The runtime, coming in 0.1.0

- `Riddler.Elements.Document.admit/1` and `Riddler.Elements.Document.validate/1`
  - what the vocabulary admits, and why a document is refused.
- `Riddler.Elements.resolve/2` - the document against a context, with each
  container's winner replacing it in the resolved output.
- `Riddler.Elements.validate_responses/3` - what a set of responses has to
  satisfy before a host accepts it.

Until they land, this package is a scaffold: the gate, the records and the
package metadata, with the functions above arriving one request at a time.
The reference documentation on this page grows with them.

## The conformance corpus

The corpus that holds a Riddler runtime to this contract is authored here,
beside the code that has to satisfy it, and emitted into
[riddler_spec](https://github.com/riddler/riddler_spec) by `mix riddler.corpus`.
A corpus file is never edited by hand in that repository: it is generated from
the cases in this one, so that a runtime written in another language and this
one are held to the same behavior.

## Architecture decisions

The records in [`docs/adr/`](docs/adr/README.md) carry the decisions this
package is built on - what the element document is, what the template subset
admits, and where the boundary between this package and its hosts runs.

## Installation

```elixir
def deps do
  [
    {:riddler, "~> 0.0.1"}
  ]
end
```

## License

MIT. See [LICENSE](LICENSE).
