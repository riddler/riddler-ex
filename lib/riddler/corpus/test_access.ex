# The three fixed test access modules a `journey.check` case names, the same
# in every runtime so that a case can state what `Riddler.Journey.Access.check/4`
# answers, as the one test sealer is for a `screens.seal_secrets` case. They are
# not public surface: `Riddler.Corpus` hands one of them over by the name a case
# gives it.
#
# The actor of `Members` and `PresentOnly` is a list of scope data forms. A
# scope belongs to it exactly when the list holds the scope's data form as
# `Riddler.Journey.Scope.to_data/1` gives it, and `scopes/1` lists exactly those
# items, so the two callbacks agree as the behaviour asks: an item that
# `Scope.from_data/1` would read but that carries a key beside `"kind"` and
# `"id"` is not that data form, and neither callback counts it.

defmodule Riddler.Corpus.TestAccess.Members do
  @moduledoc false
  @behaviour Riddler.Journey.Access

  alias Riddler.Journey.Scope

  @impl true
  def member?(actor, %Scope{} = scope) when is_list(actor), do: Scope.to_data(scope) in actor
  def member?(_actor, _scope), do: false

  @impl true
  def scopes(actor) when is_list(actor) do
    for item <- actor,
        {:ok, scope} <- [Scope.from_data(item)],
        Scope.to_data(scope) == item,
        do: scope
  end

  def scopes(_actor), do: []
end

defmodule Riddler.Corpus.TestAccess.PresentOnly do
  @moduledoc false
  @behaviour Riddler.Journey.Access

  alias Riddler.Corpus.TestAccess.Members

  @impl true
  defdelegate member?(actor, scope), to: Members

  @impl true
  defdelegate scopes(actor), to: Members

  @impl true
  def allowed?(_actor, _scope, :present), do: true
  def allowed?(_actor, _scope, _operation), do: false
end

defmodule Riddler.Corpus.TestAccess.NotBoolean do
  @moduledoc false

  # Answers the string "true", never the boolean: a `check/4` that reads
  # anything other than exactly `true` as a yes is caught by it. It exports the
  # callbacks without declaring the behaviour, because its `member?/2` answers
  # outside the callback's type on purpose; `check/4` reads what a module
  # exports, not what it declares.
  def member?(_actor, _scope), do: "true"

  def scopes(_actor), do: []
end
