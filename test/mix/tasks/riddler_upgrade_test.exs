defmodule Mix.Tasks.Riddler.UpgradeTest do
  @moduledoc """
  The upgrade task, run the way a person runs it, over a file in a directory
  of its own.
  """

  use ExUnit.Case, async: false

  alias Mix.Tasks.Riddler.Upgrade, as: Task

  @version_one """
  {
    "id": "patron_registration",
    "screens": [
      {
        "key": "patron_details",
        "title": "Get your library card",
        "nodes": [
          {"type": "text", "key": "welcome", "text": "Welcome."}
        ]
      }
    ]
  }
  """

  setup do
    shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(shell) end)
    :ok
  end

  # Sabotage: dropped the `File.write!/2` from the rewrite branch; the file
  # still read version 1 and this test went red.
  test "rewrites a version 1 document in place as version 2 and says so" do
    path = document!("patron.json", @version_one)

    assert Task.run([path]) == :ok

    assert File.read!(path) ==
             @version_one
             |> String.replace(~s({\n  "id"), ~s({\n  "schema_version": 2,\n  "id"))
             |> String.replace(~s("nodes"), ~s("elements"))

    assert_received {:mix_shell, :info, [message]}
    assert message == "#{path} is rewritten as version 2."
  end

  # Sabotage: wrote the file on every `{:ok, _}`, the unchanged text
  # included; the file's modification time moved and this went red.
  test "leaves a version 2 document as it is and writes nothing, so a second run is a no-op" do
    path = document!("patron.json", @version_one)
    Task.run([path])
    upgraded = File.read!(path)
    File.touch!(path, {{2000, 1, 1}, {0, 0, 0}})

    assert Task.run([path]) == :ok
    assert File.read!(path) == upgraded
    assert File.stat!(path).mtime == {{2000, 1, 1}, {0, 0, 0}}
    assert_received {:mix_shell, :info, [_first]}
    assert_received {:mix_shell, :info, [message]}
    assert message == "#{path} is already version 2; nothing was written."
  end

  # Sabotage: reported a refusal through `Mix.shell().info/1` instead of
  # raising, so the task exited 0; no Mix.Error was raised and this went red.
  test "refuses a version 1 document already carrying elements, writing nothing" do
    colliding = String.replace(@version_one, ~s("title"), ~s("elements": [], "title"))
    path = document!("colliding.json", colliding)

    error = assert_raise Mix.Error, fn -> Task.run([path]) end
    assert error.message =~ "#{path} was not upgraded: it is a version 1 document"
    assert error.message =~ "already carries an elements key"
    assert File.read!(path) == colliding
  end

  # Sabotage: mapped every refusal to one message; the not-JSON and the
  # version messages no longer named their cause and this went red.
  test "names each refusal: not JSON, not a document, another version" do
    for {text, said} <- [
          {"{", "it is not JSON."},
          {~s({"screens": 3}), "it is not a screen document"},
          {~s({"schema_version": 3, "screens": []}), "neither 1 nor 2"}
        ] do
      path = document!("refused.json", text)
      error = assert_raise Mix.Error, fn -> Task.run([path]) end
      assert error.message =~ said
      assert File.read!(path) == text
    end
  end

  # Sabotage: answered a bare variant in `rename/1` with
  # `Map.put(map, "elements", [])`; the edited text no longer decoded to that
  # answer, the task refused the file and this went red.
  test "rewrites a document whose variant carries no candidates, exiting 0" do
    text =
      ~s({"screens": [{"key": "s", "title": "S", "nodes": [{"type": "variant", "key": "v"}]}]})

    path = document!("bare.json", text)

    ran =
      try do
        Task.run([path])
      rescue
        error in Mix.Error -> {:refused, error.message}
      end

    assert ran == :ok

    assert File.read!(path) ==
             ~s({"schema_version": 2,"screens": [{"key": "s", "title": "S", "elements": [{"type": "variant", "key": "v"}]}]})
  end

  # Sabotage: took the first of several paths; two paths no longer raised and
  # this went red.
  test "takes exactly one readable path and no options" do
    for argv <- [[], ["a.json", "b.json"], ["--force", "a.json"]] do
      error = assert_raise Mix.Error, fn -> Task.run(argv) end
      assert error.message =~ "mix riddler.upgrade PATH"
    end

    missing = Path.join(dir!(), "missing.json")
    error = assert_raise Mix.Error, fn -> Task.run([missing]) end
    assert error.message =~ "could not read #{missing}"
  end

  defp document!(name, text) do
    path = Path.join(dir!(), name)
    File.write!(path, text)
    path
  end

  defp dir! do
    dir = Path.join(System.tmp_dir!(), "riddler-upgrade-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end
end
