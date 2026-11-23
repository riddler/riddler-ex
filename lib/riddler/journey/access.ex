defmodule Riddler.Journey.Access do
  @moduledoc """
  Who may see and step a Journey: the behaviour a host implements, and the
  one check a renderer asks.

  Who is asking is the host's to represent, and is called the actor here;
  this package passes it through and never reads it. A host implements this
  behaviour to say which actors belong to which scopes
  (`Riddler.Journey.Scope`):

  - `c:member?/2` answers `true` when the actor belongs to the scope, and
    `false` otherwise;
  - `c:scopes/1` answers the scopes the actor belongs to, for a host or a
    renderer that lists the Journeys an actor may resume;
  - `c:allowed?/3`, optional, answers `true` when the actor may take one
    operation - `:present`, `:submit` or `:back` - in the scope, and `false`
    otherwise.

  A host keeps `c:member?/2` and `c:scopes/1` in agreement: a scope is in
  `scopes(actor)` exactly when `member?(actor, scope)` is `true`. This
  package cannot check that, and does not call `c:scopes/1` itself.

  A renderer asks `check/4` before a start, with `:present` and the scope
  the Journey is to be started under; on mount, with `:present`; on every
  submit, with `:submit`; and on every back, with `:back`. It asks again each
  time rather than once, because whether an actor belongs to a scope is the
  host's, and can change while a Journey is open. The answer is `:ok` or
  `{:error, :no_such_journey}`, and the refusal does not say why: a Journey
  that is not the actor's is answered exactly as a Journey that does not
  exist, so a refusal tells the asker nothing about which Journeys exist.

  `check_kind/2` is the other half: a host's Path record names the one scope
  kind a Journey of that Path takes, and the host checks a scope against it
  before it starts the execution.

  Both checks are pure: they keep no state, start no process and read no
  store or execution. `check/4` calls the host's callbacks and nothing else;
  `check_kind/2` calls nothing.

  ## Example

  Patron registration: the library's host scopes each registration Journey
  to the patron it is for, and answers `c:member?/2` from the patron's own
  id. The actor here is the patron id the host signed in.

      iex> defmodule Library.PatronAccess do
      ...>   @behaviour Riddler.Journey.Access
      ...>   alias Riddler.Journey.Scope
      ...>
      ...>   @impl true
      ...>   def member?(patron_id, %Scope{kind: "patron", id: id}), do: patron_id == id
      ...>   def member?(_patron_id, _scope), do: false
      ...>
      ...>   @impl true
      ...>   def scopes(patron_id) do
      ...>     {:ok, scope} = Scope.new("patron", patron_id)
      ...>     [scope]
      ...>   end
      ...> end
      iex> {:ok, scope} = Riddler.Journey.Scope.new("patron", "P-1001")
      iex> Riddler.Journey.Access.check(Library.PatronAccess, "P-1001", scope, :present)
      :ok
      iex> Riddler.Journey.Access.check(Library.PatronAccess, "P-2002", scope, :present)
      {:error, :no_such_journey}

  The registration Path's record on the host says it takes the kind
  `"patron"`, so the host checks a scope before it starts a Journey:

      iex> {:ok, scope} = Riddler.Journey.Scope.new("patron", "P-1001")
      iex> Riddler.Journey.Access.check_kind(scope, "patron")
      :ok
      iex> {:ok, branch} = Riddler.Journey.Scope.new("branch", "B-12")
      iex> Riddler.Journey.Access.check_kind(branch, "patron")
      {:error, :wrong_scope_kind}
  """

  alias Riddler.Journey.Scope

  @typedoc "Who is asking: the host's own value, which this package never reads."
  @type actor :: term()

  @typedoc "What the actor is about to do with the Journey."
  @type operation :: :present | :submit | :back

  @doc """
  Answers `true` when `actor` belongs to `scope`, and `false` otherwise.
  """
  @callback member?(actor(), Scope.t()) :: boolean()

  @doc """
  The scopes `actor` belongs to: exactly those for which `c:member?/2`
  answers `true`.
  """
  @callback scopes(actor()) :: [Scope.t()]

  @doc """
  Answers `true` when `actor` may take `operation` in `scope`, and `false`
  otherwise. Optional: a host that does not export it lets every member take
  every operation. `check/4` calls it only after `c:member?/2` has answered
  `true`.
  """
  @callback allowed?(actor(), Scope.t(), operation()) :: boolean()

  @optional_callbacks allowed?: 3

  @operations [:present, :submit, :back]

  @doc """
  Whether `actor` may take `operation` in the Journey whose scope is `scope`,
  asked of `access`, the host's module implementing this behaviour.

  Answers `:ok` when `member?(actor, scope)` answers `true` and either
  `access` does not export `allowed?/3` or `allowed?(actor, scope, operation)`
  answers `true`. Everything else answers `{:error, :no_such_journey}`: a
  callback answer that is not exactly `true`, `false` included; a `scope`
  that is not a `Riddler.Journey.Scope`; an `operation` other than
  `:present`, `:submit` and `:back`; and an `access` that is not an atom
  naming a module that exports `member?/2`. The refusal is the same for
  every one of them.

  What `access` exports is read after `Code.ensure_loaded/1` on it, so a
  module not yet loaded is not taken for one that does not export a
  callback; an `access` that is not an atom is refused without being loaded.
  A callback that raises is the host's defect, and is not rescued here.

      iex> {:ok, scope} = Riddler.Journey.Scope.new("merchant", "M-1001")
      iex> Riddler.Journey.Access.check("not a module", "operator-7", scope, :submit)
      {:error, :no_such_journey}
      iex> Riddler.Journey.Access.check(Riddler.Journey.Scope, "operator-7", scope, :submit)
      {:error, :no_such_journey}
  """
  @spec check(term(), actor(), term(), term()) :: :ok | {:error, :no_such_journey}
  def check(access, actor, %Scope{} = scope, operation)
      when is_atom(access) and operation in @operations do
    with {:module, ^access} <- Code.ensure_loaded(access),
         true <- function_exported?(access, :member?, 2),
         true <- access.member?(actor, scope),
         true <- allowed?(access, actor, scope, operation) do
      :ok
    else
      _refused -> {:error, :no_such_journey}
    end
  end

  def check(_access, _actor, _scope, _operation), do: {:error, :no_such_journey}

  defp allowed?(access, actor, scope, operation) do
    if function_exported?(access, :allowed?, 3) do
      access.allowed?(actor, scope, operation)
    else
      true
    end
  end

  @doc """
  Whether `scope` is of the kind a Path expects, `expected_kind`, the one
  scope kind the host's own Path record names.

  Answers `:ok` when `scope` is a `Riddler.Journey.Scope` whose `kind`
  equals `expected_kind` byte for byte, and `{:error, :wrong_scope_kind}`
  otherwise, an `expected_kind` that is not a string of at least one byte
  included. Neither string is trimmed or case-folded. It calls nothing.

      iex> {:ok, scope} = Riddler.Journey.Scope.new("merchant", "M-1001")
      iex> Riddler.Journey.Access.check_kind(scope, "merchant")
      :ok
      iex> Riddler.Journey.Access.check_kind(scope, "Merchant")
      {:error, :wrong_scope_kind}
      iex> Riddler.Journey.Access.check_kind(%{"kind" => "merchant", "id" => "M-1001"}, "merchant")
      {:error, :wrong_scope_kind}
  """
  @spec check_kind(term(), term()) :: :ok | {:error, :wrong_scope_kind}
  def check_kind(%Scope{kind: kind}, kind) when is_binary(kind) and byte_size(kind) > 0,
    do: :ok

  def check_kind(_scope, _expected_kind), do: {:error, :wrong_scope_kind}
end
