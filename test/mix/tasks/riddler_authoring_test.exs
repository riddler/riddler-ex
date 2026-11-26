defmodule Mix.Tasks.Riddler.AuthoringTest do
  @moduledoc """
  The authoring task, run the way a person runs it: in this checkout, and in
  a directory of its own where nothing has been written yet.
  """

  use ExUnit.Case, async: false

  alias Mix.Tasks.Riddler.Authoring, as: Task

  setup do
    shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(shell) end)
    :ok
  end

  # Sabotage: made check/1 raise on an empty drift list; the committed files
  # read as drift and this test went red.
  test "--check answers ok when priv/authoring carries what the registry gives" do
    assert Task.run(["--check"]) == :ok
    assert_received {:mix_shell, :info, [message]}
    assert message =~ "carries what the element type registry gives"
  end

  # Sabotage: made check/1 answer :ok whatever the drift; the empty
  # directory passed the check and this test went red.
  test "--check refuses a directory without the files, and writing them answers it" do
    root = Path.join(System.tmp_dir!(), "authoring-task-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)

    File.cd!(root, fn ->
      error = assert_raise Mix.Error, fn -> Task.run(["--check"]) end
      assert error.message =~ "missing: priv/authoring/screen-authoring.schema.json"
      assert error.message =~ "missing: priv/authoring/screen-elements.md"

      assert Task.run([]) == :ok
      assert Task.run(["--check"]) == :ok
    end)

    assert_received {:mix_shell, :info, ["wrote priv/authoring/screen-authoring.schema.json"]}
  end
end
