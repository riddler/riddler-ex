defmodule Riddler.Journey.HostTest do
  # Not async: the tests compile throwaway host modules from source and purge
  # them, and compiler diagnostics are collected per call.
  use ExUnit.Case, async: false

  alias Riddler.Journey.Host

  # A card-processing host's dispute Journey, implementing every callback.
  # Compiled from source in each test, so that what the compiler says of it
  # can be read.
  @complete """
  defmodule Riddler.Journey.HostTest.Disputes do
    @behaviour Riddler.Journey.Host

    @impl true
    def start(_path, _scope), do: {:error, :no_such_journey}

    @impl true
    def present(_journey), do: {:error, :no_such_journey}

    @impl true
    def submit(_journey, _submit), do: {:error, :no_such_journey}

    @impl true
    def back(_journey, _back_request), do: {:error, :no_such_journey}
  end
  """

  # The same host without back/2.
  @missing_back """
  defmodule Riddler.Journey.HostTest.DisputesNoBack do
    @behaviour Riddler.Journey.Host

    @impl true
    def start(_path, _scope), do: {:error, :no_such_journey}

    @impl true
    def present(_journey), do: {:error, :no_such_journey}

    @impl true
    def submit(_journey, _submit), do: {:error, :no_such_journey}
  end
  """

  defp compile(source) do
    {modules, diagnostics} =
      Code.with_diagnostics(fn -> Code.compile_string(source, "host_test_fixture.ex") end)

    for {module, _binary} <- modules do
      :code.purge(module)
      :code.delete(module)
    end

    Enum.map(diagnostics, &{&1.severity, &1.message})
  end

  defp callback_spec(name, arity) do
    {:ok, callbacks} = Code.Typespec.fetch_callbacks(Host)
    {{^name, ^arity}, [spec]} = List.keyfind(callbacks, {name, arity}, 0)
    # Whitespace is collapsed so that how the formatter wraps a long spec is
    # not read.
    name
    |> Code.Typespec.spec_to_quoted(spec)
    |> Macro.to_string()
    |> String.replace(~r/\s+/, " ")
  end

  # Sabotage: renamed the back/2 callback to step_back/2; the callback list
  # read [present: 1, start: 2, step_back: 2, submit: 2] and this test went red.
  test "the behaviour's callbacks are start/2, present/1, submit/2 and back/2, none optional" do
    assert Enum.sort(Host.behaviour_info(:callbacks)) ==
             [back: 2, present: 1, start: 2, submit: 2]

    assert Host.behaviour_info(:optional_callbacks) == []
  end

  # Sabotage: marked back/2 optional (@optional_callbacks back: 2); the host
  # without back/2 compiled without a warning and this test went red.
  test "a host implementing every callback compiles clean, and one missing back/2 is warned" do
    assert compile(@complete) == []

    assert Enum.any?(compile(@missing_back), fn {severity, message} ->
             severity == :warning and message =~ "back/2" and
               message =~ "Riddler.Journey.Host"
           end)
  end

  # Sabotage: dropped `| {:error, :no_such_journey}` from present/1's spec;
  # its spec no longer carried the refusal and this test went red.
  test "every callback may answer the one refusal" do
    for {name, arity} <- [start: 2, present: 1, submit: 2, back: 2] do
      assert callback_spec(name, arity) =~ "{:error, :no_such_journey}"
    end
  end

  # Sabotage: typed submit/2's findings as [term()]; its spec no longer named
  # Riddler.Finding and this test went red.
  test "submit/2 and back/2 may answer findings, and start/2 and present/1 may not" do
    for {name, arity} <- [submit: 2, back: 2] do
      assert callback_spec(name, arity) =~ "{:error, [Riddler.Finding.t()]}"
    end

    for {name, arity} <- [start: 2, present: 1] do
      refute callback_spec(name, arity) =~ "Riddler.Finding"
    end
  end

  # Sabotage: typed present/1's answer {:ok, Riddler.Journey.answer()},
  # dropping the scope; its spec no longer carried Scope.t() and this test
  # went red.
  test "start/2 answers the Journey's name and present/1 the scope, beside the answer" do
    assert callback_spec(:start, 2) =~ "{:ok, journey(), Riddler.Journey.answer()}"

    assert callback_spec(:present, 1) =~
             "{:ok, Riddler.Journey.Scope.t(), Riddler.Journey.answer()}"

    assert callback_spec(:submit, 2) =~ "submit(journey(), Riddler.Journey.submit())"
    assert callback_spec(:back, 2) =~ "back(journey(), Riddler.Journey.back_request())"
  end
end
