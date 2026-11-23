defmodule Riddler.Journey.Scope do
  @moduledoc """
  The scope a Journey runs under: one kind and one id, both strings.

  A host chooses a Journey's scope when it starts the execution, and keeps
  it on its own execution record beside whatever else it keeps there. The
  kind says what sort of thing the Journey belongs to and the id says which
  one: `{"patron", "P-1001"}` for a registration Journey that belongs to one
  patron, `{"branch", "B-12"}` for an onboarding Journey that belongs to one
  branch library. The kinds are open: those two, and any other string a host
  names, are all kinds, and this package lists none.

  Neither string is read for what it means here - not trimmed, not
  case-folded, not parsed, not looked up - and two scopes are the same scope
  exactly when both strings are equal byte for byte. Each has to be a string
  of at least one byte, and that is the whole of the check.

  A scope is fixed once the Journey starts: this module has no function that
  changes one, and nothing here reads an execution to find one. The host
  supplies the scope on every call that needs it.

  `to_data/1` gives the data form a host keeps, a map of `"kind"` and `"id"`,
  and `from_data/1` reads that form back. How and where a host keeps it is
  the host's.

  ## Example

  Patron registration: the registration Journey for one patron.

      iex> {:ok, scope} = Riddler.Journey.Scope.new("patron", "P-1001")
      iex> scope
      %Riddler.Journey.Scope{kind: "patron", id: "P-1001"}
      iex> data = Riddler.Journey.Scope.to_data(scope)
      %{"kind" => "patron", "id" => "P-1001"}
      iex> Riddler.Journey.Scope.from_data(data)
      {:ok, %Riddler.Journey.Scope{kind: "patron", id: "P-1001"}}

  An empty string is not a kind or an id, and a value that is not the data
  form is not read as one:

      iex> Riddler.Journey.Scope.new("patron", "")
      {:error, :invalid_scope}
      iex> Riddler.Journey.Scope.from_data(%{"kind" => "branch"})
      {:error, :invalid_scope}
  """

  @enforce_keys [:kind, :id]
  defstruct [:kind, :id]

  @typedoc "A Journey's scope: a kind and an id, each a string of at least one byte."
  @type t :: %__MODULE__{kind: String.t(), id: String.t()}

  @doc """
  A scope of `kind` and `id`.

  Answers `{:ok, scope}` when both are strings of at least one byte, and
  `{:error, :invalid_scope}` for anything else. Neither string is changed.

      iex> Riddler.Journey.Scope.new("branch", "B-12")
      {:ok, %Riddler.Journey.Scope{kind: "branch", id: "B-12"}}

      iex> Riddler.Journey.Scope.new("branch", 12)
      {:error, :invalid_scope}
  """
  @spec new(term(), term()) :: {:ok, t()} | {:error, :invalid_scope}
  def new(kind, id) when is_binary(kind) and is_binary(id) do
    if byte_size(kind) > 0 and byte_size(id) > 0 do
      {:ok, %__MODULE__{kind: kind, id: id}}
    else
      {:error, :invalid_scope}
    end
  end

  def new(_kind, _id), do: {:error, :invalid_scope}

  @doc """
  The data form of `scope`, the one a host keeps: a map of `"kind"` and
  `"id"`.

      iex> {:ok, scope} = Riddler.Journey.Scope.new("branch", "B-12")
      iex> Riddler.Journey.Scope.to_data(scope)
      %{"kind" => "branch", "id" => "B-12"}
  """
  @spec to_data(t()) :: %{required(String.t()) => String.t()}
  def to_data(%__MODULE__{kind: kind, id: id}), do: %{"kind" => kind, "id" => id}

  @doc """
  Reads the data form back into a scope.

  Answers `{:ok, scope}` for a map whose `"kind"` and `"id"` are strings of at
  least one byte, and reads no other key of it. Anything else, a struct
  included, answers `{:error, :invalid_scope}`.

      iex> Riddler.Journey.Scope.from_data(%{"kind" => "patron", "id" => "P-1001", "note" => "kept by the host"})
      {:ok, %Riddler.Journey.Scope{kind: "patron", id: "P-1001"}}

      iex> Riddler.Journey.Scope.from_data("patron:P-1001")
      {:error, :invalid_scope}
  """
  @spec from_data(term()) :: {:ok, t()} | {:error, :invalid_scope}
  def from_data(data) when is_map(data) and not is_struct(data) do
    case data do
      %{"kind" => kind, "id" => id} -> new(kind, id)
      _other -> {:error, :invalid_scope}
    end
  end

  def from_data(_data), do: {:error, :invalid_scope}
end
