defmodule Riddler do
  @moduledoc """
  Riddler: a dynamic content runtime.

  A host authors content as JSON documents - screens now; emails, images and
  feature flags forthcoming - and Riddler resolves each against a visitor's
  context; the host renders, sends or serves what comes back. The document is
  the contract: it is JSON, it carries a `schema_version` and a `kind`, and it
  is what both sides of the boundary agree on. This package is the Elixir
  runtime for that contract - pure functions over a decoded document and a
  context map, with no renderer, no persistence and no editor inside them.

  A content kind is a document shape, a resolved shape, a registry and a
  corpus capability. This version ships exactly one, `screens`; each
  forthcoming kind is decided by its own record before it is code.

  Three seams divide the package, and each one arrives as its own module:

    * `Riddler.Screens` - the screens kind. What the vocabulary admits,
      what a container resolves to against a context, and what a set of
      responses has to satisfy to be accepted.

    * `Riddler.Template` - the safe template subset. A deliberately small
      slice of Liquid, so that a host can let an author interpolate a value
      into copy without letting them run code.

    * `Riddler.Corpus` - the conformance corpus. The cases are authored here,
      beside the code that has to satisfy them, and emitted into the corpus
      repository by `mix riddler.corpus` so that a runtime written in another
      language can be held to the same behavior.

  Conditions are evaluated by predicator and templates are parsed by solid.
  Nothing else is a runtime dependency, and nothing in the statifier family
  is: this package is consumed beside those packages by a host application,
  never from inside its own core.

  ## Examples

      iex> Code.ensure_loaded?(Riddler)
      true
  """
end
