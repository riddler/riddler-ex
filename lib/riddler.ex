defmodule Riddler do
  @moduledoc """
  Riddler: the element document and what can be decided from it.

  An element document is a host application's declaration of the dynamic
  content and forms a visitor is shown - a screen of a signup wizard, a set of
  questions, a block of copy that varies by audience. It is JSON, it carries a
  schema version, and it is the contract between a host that authors content
  and any runtime that renders it. This package is the Elixir runtime for that
  contract: pure functions over a decoded document and a context map, with no
  renderer, no persistence and no editor inside them.

  Three seams divide the package, and each one arrives as its own module:

    * `Riddler.Elements` - the document itself. What the vocabulary admits,
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
