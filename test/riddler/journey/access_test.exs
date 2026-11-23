defmodule Riddler.Journey.AccessTest do
  # Not async: one test unloads a compiled access module to show that `check/4`
  # loads it before it reads what it exports, and no other test may be using
  # that module while it is gone.
  use ExUnit.Case, async: false

  doctest Riddler.Journey.Access

  alias Riddler.Corpus.TestAccess
  alias Riddler.Journey.Access
  alias Riddler.Journey.Scope

  # A card-processing host's access module whose answers are read off the
  # actor, so that a test states what `member?/2` answers by the actor it
  # passes. Every call is reported to the test process.
  defmodule Echo do
    @moduledoc false
    @behaviour Riddler.Journey.Access

    @impl true
    def member?(actor, scope) do
      send(self(), {:member?, actor, scope})
      actor.member
    end

    @impl true
    def scopes(_actor), do: []
  end

  # As `Echo`, with `allowed?/3` exported and read off the actor by operation.
  defmodule EchoAllowed do
    @moduledoc false
    @behaviour Riddler.Journey.Access

    @impl true
    def member?(actor, _scope), do: actor.member

    @impl true
    def scopes(_actor), do: []

    @impl true
    def allowed?(actor, scope, operation) do
      send(self(), {:allowed?, actor, scope, operation})
      Map.fetch!(actor.allowed, operation)
    end
  end

  # Exports `scopes/1` but not `member?/2`.
  defmodule NoMember do
    @moduledoc false
    def scopes(_actor), do: []
  end

  defmodule Raises do
    @moduledoc false
    def member?(_actor, _scope), do: raise(ArgumentError, "the host's defect")
    def scopes(_actor), do: []
  end

  # A member, whose allowed?/3 raises.
  defmodule RaisesAllowed do
    @moduledoc false
    def member?(_actor, _scope), do: true
    def scopes(_actor), do: []
    def allowed?(_actor, _scope, _operation), do: raise(ArgumentError, "the host's other defect")
  end

  # A map shaped as a struct, carrying a scope's two fields.
  defmodule Borrowed do
    @moduledoc false
    defstruct [:kind, :id]
  end

  setup do
    {:ok, merchant} = Scope.new("merchant", "M-1001")
    {:ok, scope: merchant}
  end

  describe "check/4" do
    # Sabotage: made check/4 answer :ok without reading member?/2's answer;
    # the non-member came back :ok and this test went red.
    test "a member may take every operation, and a non-member none", %{scope: scope} do
      for operation <- [:present, :submit, :back] do
        assert Access.check(Echo, %{member: true}, scope, operation) == :ok

        assert Access.check(Echo, %{member: false}, scope, operation) ==
                 {:error, :no_such_journey}
      end
    end

    # Sabotage: accepted any truthy member?/2 answer (`if answer`); the string
    # "true" and the atom :yes came back :ok and this test went red.
    test "an answer that is not exactly true refuses", %{scope: scope} do
      for answer <- ["true", :yes, 1, nil, [], %{}, {:ok, true}] do
        assert Access.check(Echo, %{member: answer}, scope, :present) ==
                 {:error, :no_such_journey}
      end
    end

    # Sabotage: dropped the allowed?/3 step, answering :ok for every member;
    # the member refused :submit came back :ok and this test went red.
    test "an exported allowed?/3 is asked with the operation, after member?/2", %{scope: scope} do
      actor = %{member: true, allowed: %{present: true, submit: false, back: "true"}}

      assert Access.check(EchoAllowed, actor, scope, :present) == :ok
      assert_received {:allowed?, ^actor, ^scope, :present}

      assert Access.check(EchoAllowed, actor, scope, :submit) == {:error, :no_such_journey}
      assert_received {:allowed?, ^actor, ^scope, :submit}

      assert Access.check(EchoAllowed, actor, scope, :back) == {:error, :no_such_journey}
    end

    # Sabotage: asked allowed?/3 before member?/2; the non-member's allowed?/3
    # call was received and this test went red.
    test "allowed?/3 is not asked of a non-member", %{scope: scope} do
      actor = %{member: false, allowed: %{present: true}}

      assert Access.check(EchoAllowed, actor, scope, :present) == {:error, :no_such_journey}
      refute_received {:allowed?, _actor, _scope, _operation}
    end

    # Sabotage: answered {:error, :not_a_module} for an access that is not a
    # module exporting member?/2; the refusals differed by cause and this test
    # went red.
    test "every refusal is the same refusal, whatever its cause", %{scope: scope} do
      member = %{member: true}

      refusals = [
        Access.check(Echo, %{member: false}, scope, :present),
        Access.check(Echo, %{member: "true"}, scope, :present),
        Access.check(EchoAllowed, %{member: true, allowed: %{submit: false}}, scope, :submit),
        Access.check(Echo, member, Scope.to_data(scope), :present),
        Access.check(Echo, member, scope, :approve),
        Access.check("Elixir.Riddler.Journey.AccessTest.Echo", member, scope, :present),
        Access.check(:no_such_module_here, member, scope, :present),
        Access.check(NoMember, member, scope, :present)
      ]

      assert Enum.uniq(refusals) == [{:error, :no_such_journey}]
    end

    # Sabotage: dropped the %Scope{} match, so any value reached member?/2;
    # the data form and the borrowed struct were handed to the host and this
    # test went red.
    test "a scope that is not a Scope struct is refused without asking the host", %{scope: scope} do
      for not_a_scope <- [
            Scope.to_data(scope),
            %Borrowed{kind: "merchant", id: "M-1001"},
            {"merchant", "M-1001"},
            "merchant:M-1001",
            nil
          ] do
        assert Access.check(Echo, %{member: true}, not_a_scope, :present) ==
                 {:error, :no_such_journey}
      end

      refute_received {:member?, _actor, _scope}
    end

    # Sabotage: widened the operation guard to any atom; :approve reached the
    # host and came back :ok and this test went red.
    test "an operation outside the three is refused without asking the host", %{scope: scope} do
      for operation <- [:approve, :Present, "present", nil, :start] do
        assert Access.check(Echo, %{member: true}, scope, operation) ==
                 {:error, :no_such_journey}
      end

      refute_received {:member?, _actor, _scope}
    end

    # Sabotage: took a module that does not export member?/2 for a member
    # (`not exported or access.member?(actor, scope)`); those modules came
    # back :ok and this test went red.
    test "an access that is not a module exporting member?/2 is refused", %{scope: scope} do
      for access <- [
            "Elixir.Riddler.Journey.AccessTest.Echo",
            {Echo, :member?},
            [Echo],
            nil,
            :no_such_module_here,
            Scope,
            NoMember
          ] do
        assert Access.check(access, %{member: true}, scope, :present) ==
                 {:error, :no_such_journey}
      end
    end

    # Sabotage: read the exports with function_exported?/3 alone, without
    # Code.ensure_loaded/1; the unloaded module was taken for one without
    # member?/2 and this test went red.
    test "reads the exports of a module that is not yet loaded", %{scope: scope} do
      module = TestAccess.Members
      true = Code.ensure_loaded?(module)
      :code.purge(module)
      true = :code.delete(module)
      :code.purge(module)

      assert :code.is_loaded(module) == false
      assert Access.check(module, [Scope.to_data(scope)], scope, :submit) == :ok
    end

    # Sabotage: rescued the member?/2 call's error into the refusal; no error
    # was raised and this test went red. And again with only the allowed?/3
    # call rescued; the second assert_raise saw no error and it went red.
    test "a callback that raises is the host's defect, and is not rescued", %{scope: scope} do
      assert_raise ArgumentError, "the host's defect", fn ->
        Access.check(Raises, %{}, scope, :present)
      end

      assert_raise ArgumentError, "the host's other defect", fn ->
        Access.check(RaisesAllowed, %{}, scope, :submit)
      end
    end
  end

  describe "check_kind/2" do
    # Sabotage: compared the kinds case-insensitively (String.downcase on
    # both); "Merchant" came back :ok and this test went red.
    test "compares the kind byte for byte", %{scope: scope} do
      assert Access.check_kind(scope, "merchant") == :ok

      for expected <- ["Merchant", "MERCHANT", " merchant", "merchant ", "tenant", "M-1001"] do
        assert Access.check_kind(scope, expected) == {:error, :wrong_scope_kind}
      end
    end

    # Sabotage: dropped the byte_size guard; the hand-built scope of an empty
    # kind matched the empty expected kind and this test went red.
    test "an expected kind that is not a string of at least one byte is refused" do
      empty = %Scope{kind: "", id: "M-1001"}
      assert Access.check_kind(empty, "") == {:error, :wrong_scope_kind}

      {:ok, scope} = Scope.new("merchant", "M-1001")

      for expected <- [nil, :merchant, ~c"merchant", ["merchant"], 1] do
        assert Access.check_kind(scope, expected) == {:error, :wrong_scope_kind}
      end
    end

    # Sabotage: matched any map with a :kind key in place of the %Scope{}
    # match; the atom-keyed map and the borrowed struct came back :ok and
    # this test went red.
    test "a scope that is not a Scope struct is refused" do
      for not_a_scope <- [
            %{"kind" => "merchant", "id" => "M-1001"},
            %{kind: "merchant", id: "M-1001"},
            %Borrowed{kind: "merchant", id: "M-1001"},
            "merchant",
            nil
          ] do
        assert Access.check_kind(not_a_scope, "merchant") == {:error, :wrong_scope_kind}
      end
    end
  end

  describe "the corpus's test access modules" do
    # Sabotage: made Members.scopes/1 list every item Scope.from_data/1 reads;
    # the item carrying a label came back as a scope that member?/2 refuses,
    # and this test went red.
    test "members lists exactly the scopes it answers member? true for" do
      {:ok, merchant} = Scope.new("merchant", "M-1001")
      {:ok, tenant} = Scope.new("tenant", "T-42")
      {:ok, labelled} = Scope.new("signup", "S-77")

      actor = [
        Scope.to_data(merchant),
        %{"kind" => "signup", "id" => "S-77", "label" => "variant B"},
        "tenant:T-42",
        Scope.to_data(tenant)
      ]

      assert TestAccess.Members.scopes(actor) == [merchant, tenant]
      assert Enum.all?(TestAccess.Members.scopes(actor), &TestAccess.Members.member?(actor, &1))
      refute TestAccess.Members.member?(actor, labelled)
      assert TestAccess.Members.scopes("not a list") == []
    end
  end
end
