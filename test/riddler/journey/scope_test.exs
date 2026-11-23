defmodule Riddler.Journey.ScopeTest do
  use ExUnit.Case, async: true

  doctest Riddler.Journey.Scope

  alias Riddler.Journey.Scope

  # A map shaped as a struct, carrying the data form's two string keys: what
  # `from_data/1` has to refuse even though both keys are there.
  defmodule Borrowed do
    @moduledoc false
    defstruct [:kind, :id]
  end

  describe "new/2" do
    # Sabotage: answered {:ok, scope} for any two binaries, dropping the
    # byte_size check; the empty kind and the empty id were admitted and this
    # test went red.
    test "refuses an empty kind and an empty id" do
      assert Scope.new("", "P-1001") == {:error, :invalid_scope}
      assert Scope.new("patron", "") == {:error, :invalid_scope}
      assert Scope.new("", "") == {:error, :invalid_scope}
    end

    # Sabotage: made the fallback clause answer {:ok, %Scope{}} with the
    # arguments as given; the non-string kinds and ids were admitted and this
    # test went red.
    test "refuses a kind or an id that is not a string" do
      for {kind, id} <- [
            {:patron, "P-1001"},
            {"patron", 1001},
            {nil, "P-1001"},
            {"patron", nil},
            {~c"patron", "P-1001"},
            {"patron", %{"id" => "P-1001"}}
          ] do
        assert Scope.new(kind, id) == {:error, :invalid_scope}
      end
    end

    # Sabotage: trimmed and downcased the kind in new/2; " Patron " came back
    # as "patron" and this test went red. And again with the id downcased and
    # trimmed at its end; " P-1001 " came back changed and it went red.
    test "keeps both strings byte for byte, reading neither" do
      assert {:ok, %Scope{kind: " Patron ", id: " P-1001 "}} = Scope.new(" Patron ", " P-1001 ")
      assert {:ok, %Scope{kind: "branch", id: " "}} = Scope.new("branch", " ")
    end

    # Sabotage: normalized both strings to NFC in new/2; the decomposed
    # accent came back composed and this test went red.
    test "does not normalize a string, so two spellings of one name are two scopes" do
      decomposed = "Jose" <> <<0xCC, 0x81>>
      composed = "Jos" <> <<0xC3, 0xA9>>

      assert {:ok, %Scope{id: ^decomposed} = one} = Scope.new("patron", decomposed)
      assert {:ok, %Scope{id: ^composed} = other} = Scope.new("patron", composed)
      refute one == other
    end
  end

  describe "to_data/1" do
    # Sabotage: named the data form's keys "scope_kind" and "scope_id"; the
    # map came back with neither "kind" nor "id" and this test went red.
    test "gives a map of exactly kind and id" do
      {:ok, scope} = Scope.new("branch", "B-12")

      assert Scope.to_data(scope) == %{"kind" => "branch", "id" => "B-12"}
    end

    # Sabotage: same key rename as above; from_data/1 no longer read the
    # data form back and this test went red.
    test "is what from_data/1 reads back" do
      {:ok, scope} = Scope.new("patron", "P-1001")

      assert scope |> Scope.to_data() |> Scope.from_data() == {:ok, scope}
    end
  end

  describe "from_data/1" do
    # Sabotage: dropped the `not is_struct(data)` guard; the struct carrying
    # "kind" and "id" was read as a scope and this test went red.
    test "refuses a struct, even one carrying the data form's keys" do
      borrowed = Map.merge(%Borrowed{}, %{"kind" => "patron", "id" => "P-1001"})
      {:ok, scope} = Scope.new("patron", "P-1001")

      assert Scope.from_data(borrowed) == {:error, :invalid_scope}
      assert Scope.from_data(scope) == {:error, :invalid_scope}
    end

    # Sabotage: added a from_data/1 clause reading a keyword list's :kind and
    # :id; the keyword list was read as a scope and this test went red.
    test "refuses a value that is not a map" do
      for data <- ["patron:P-1001", [kind: "patron", id: "P-1001"], nil, 12, {"patron", "P-1001"}] do
        assert Scope.from_data(data) == {:error, :invalid_scope}
      end
    end

    # Sabotage: read atom keys as well as string keys; the atom-keyed map was
    # read as a scope and this test went red.
    test "refuses a map without both string keys, or with either value not a non-empty string" do
      for data <- [
            %{},
            %{"kind" => "patron"},
            %{"id" => "P-1001"},
            %{kind: "patron", id: "P-1001"},
            %{"kind" => "", "id" => "P-1001"},
            %{"kind" => "patron", "id" => ""},
            %{"kind" => "patron", "id" => 1001}
          ] do
        assert Scope.from_data(data) == {:error, :invalid_scope}
      end
    end

    # Sabotage: refused a map carrying any key beside kind and id (a
    # map_size(data) == 2 guard); the map naming the branch was refused and
    # this test went red.
    test "reads no key other than kind and id" do
      data = %{"kind" => "branch", "id" => "B-12", "name" => "Central", "kind_label" => "Branch"}

      assert Scope.from_data(data) == {:ok, %Scope{kind: "branch", id: "B-12"}}
    end
  end
end
