defmodule Mix.Tasks.Riddler.CorpusTest do
  @moduledoc """
  The emitter, run the way a person and CI run it.

  These tests are synchronous and some of them change the working directory,
  because the task reads the corpus by repository-relative path. A test that
  needs a corpus other than this repository's - a red case, for instance -
  builds a small tree that looks like this repository, changes into it, and
  changes back. That is why nothing here is `async`.
  """

  use ExUnit.Case, async: false

  alias Mix.Tasks.Riddler.Corpus, as: Task
  alias Riddler.Corpus

  @sources Riddler.Corpus.case_files() ++ Riddler.Corpus.schema_files()

  setup do
    shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(shell) end)
    :ok
  end

  describe "emitting" do
    # Sabotage: added the time of the emit to the provenance header; the second
    # emit differed from the first and this test went red.
    test "writes every case file and every schema, and a second emit writes the same bytes" do
      first = tmp_dir!("first")
      second = tmp_dir!("second")

      Task.run(["--to", first])
      Task.run(["--to", second])

      written = Path.wildcard(Path.join(first, "**/*.json")) |> relative_to(first)

      assert written == [
               "corpus/screens/admit.json",
               "corpus/screens/resolve.json",
               "corpus/screens/validate_responses.json",
               "corpus/templates/render.json",
               "schemas/corpus-case.schema.json",
               "schemas/screen-document.schema.json"
             ]

      for relative <- written do
        assert File.read!(Path.join(first, relative)) == File.read!(Path.join(second, relative))
      end

      assert_received {:mix_shell, :info, ["6 file(s) written."]}
    end

    # Sabotage: dropped the generated_by key from the emitted case file; the
    # decoded copy no longer differed from the authored file by exactly that
    # key and this test went red.
    test "an emitted case file is the authored file plus one provenance key" do
      target = tmp_dir!("provenance")

      Task.run(["--to", target])

      for source <- Corpus.case_files() do
        emitted = target |> Path.join(Corpus.target_path(source)) |> Corpus.read()
        authored = Corpus.read(source)

        assert Map.delete(emitted, "generated_by") == authored
        assert emitted["generated_by"] == "riddler #{Corpus.version()} from #{source}"
      end

      for source <- Corpus.schema_files() do
        emitted = target |> Path.join(Corpus.target_path(source)) |> Corpus.read()

        assert emitted == Corpus.read(source)
      end
    end

    # Sabotage: dropped the red-case guard from the task; the planted corpus was
    # emitted, nothing was raised, and this test went red.
    test "refuses a corpus this implementation does not satisfy, naming the case, and writes nothing" do
      target = tmp_dir!("red-target")

      in_a_repo_whose_corpus_is_red(fn ->
        assert_raise Mix.Error, ~r/three screens are admitted/, fn ->
          Task.run(["--to", target])
        end
      end)

      assert File.ls!(target) == []
    end

    # Sabotage: made dirty?/1 answer false for every tree; the uncommitted file
    # no longer refused the emit and this test went red.
    test "refuses a git working tree with uncommitted changes unless --force" do
      target = a_dirty_git_tree!()

      assert_raise Mix.Error, ~r/uncommitted changes/, fn -> Task.run(["--to", target]) end
      assert Path.wildcard(Path.join(target, "corpus/**/*.json")) == []

      Task.run(["--to", target, "--force"])

      assert Path.wildcard(Path.join(target, "corpus/**/*.json")) != []
    end

    # Sabotage: made the missing-directory guard create the directory instead
    # of refusing; the emit succeeded into a path nobody had checked out and
    # this test went red.
    test "refuses a target that is not a directory" do
      target = Path.join(tmp_dir!("absent"), "not-checked-out")

      assert_raise Mix.Error, ~r/no such directory/, fn -> Task.run(["--to", target]) end
    end
  end

  describe "--check" do
    # Sabotage: made a file that is present but different read as no drift; the
    # edited case file passed the check and this test went red.
    test "exits green on a tree carrying the emitted corpus and names what differs on one that does not" do
      target = tmp_dir!("check")

      Task.run(["--to", target])
      assert Task.run(["--check", "--to", target]) == :ok

      one = Path.join(target, "corpus/screens/admit.json")
      File.write!(one, String.replace(File.read!(one), "screens.admit", "screens.admitted"))

      assert_raise Mix.Error, ~r/differs: corpus\/screens\/admit\.json/, fn ->
        Task.run(["--check", "--to", target])
      end
    end

    # Sabotage: made a file that is absent read as no drift; the empty checkout
    # passed the check and this test went red. An empty checkout is the state
    # riddler_spec is in until it receives its first emit, and what the drift
    # step in CI reports until then.
    test "names every file an empty checkout is missing" do
      target = tmp_dir!("empty")

      assert_raise Mix.Error, ~r/missing: corpus\/screens\/admit\.json/, fn ->
        Task.run(["--check", "--to", target])
      end
    end

    # Sabotage: made check mode share the emit's dirty-tree guard; the check
    # refused on a tree with uncommitted changes instead of reporting drift,
    # and this test went red.
    test "reads a dirty tree rather than refusing it" do
      target = a_dirty_git_tree!()

      Task.run(["--to", target, "--force"])

      assert Task.run(["--check", "--to", target]) == :ok
    end
  end

  describe "where it writes" do
    # Sabotage: made the task read RIDDLER_SPEC_PATH before --to; the explicit
    # path lost to the environment and this test went red.
    test "prefers --to over RIDDLER_SPEC_PATH" do
      chosen = tmp_dir!("chosen")
      ignored = tmp_dir!("ignored")

      System.put_env("RIDDLER_SPEC_PATH", ignored)
      on_exit(fn -> System.delete_env("RIDDLER_SPEC_PATH") end)

      Task.run(["--to", chosen])

      assert File.ls!(ignored) == []
      assert File.exists?(Path.join(chosen, "corpus/screens/admit.json"))
    end

    # Sabotage: dropped the RIDDLER_SPEC_PATH fallback, leaving only --to and
    # the default; the environment was ignored and this test went red.
    test "falls back to RIDDLER_SPEC_PATH when --to is absent" do
      target = tmp_dir!("from-env")

      System.put_env("RIDDLER_SPEC_PATH", target)
      on_exit(fn -> System.delete_env("RIDDLER_SPEC_PATH") end)

      Task.run([])

      assert File.exists?(Path.join(target, "schemas/screen-document.schema.json"))
    end
  end

  # -- the ground these tests stand on ----------------------------------------

  defp tmp_dir!(name) do
    path =
      Path.join([
        System.tmp_dir!(),
        "riddler-corpus-test",
        "#{System.unique_integer([:positive])}-#{name}"
      ])

    File.rm_rf!(path)
    File.mkdir_p!(path)
    on_exit(fn -> File.rm_rf!(path) end)

    path
  end

  defp relative_to(paths, root) do
    paths |> Enum.map(&Path.relative_to(&1, root)) |> Enum.sort()
  end

  # A copy of this repository's corpus with one case's stated answer changed,
  # so that the implementation and the corpus disagree about it. The task reads
  # the corpus by repository-relative path, so the copy is made current for the
  # duration rather than passed in.
  defp in_a_repo_whose_corpus_is_red(work) do
    root = File.cwd!()
    fake = tmp_dir!("red-corpus")

    for source <- @sources do
      File.mkdir_p!(Path.join(fake, Path.dirname(source)))
      File.cp!(Path.join(root, source), Path.join(fake, source))
    end

    plant_a_red_case!(Path.join(fake, "corpus/screens/admit.json"))

    File.cd!(fake)
    on_exit(fn -> File.cd!(root) end)

    try do
      work.()
    after
      File.cd!(root)
    end
  end

  defp plant_a_red_case!(path) do
    file = Corpus.read(path)

    [one | rest] =
      Enum.filter(file["cases"], &String.contains?(&1["name"], "three screens are admitted"))

    assert rest == [], "the planted case has to be findable by name, and exactly one case is"

    cases =
      Enum.map(file["cases"], fn
        ^one -> put_in(one, ["expected", "admitted"], false)
        other -> other
      end)

    File.write!(path, Corpus.canonical(Map.put(file, "cases", cases)))
  end

  defp a_dirty_git_tree! do
    path = tmp_dir!("dirty")

    {_output, 0} = System.cmd("git", ["init", "--quiet", path], stderr_to_stdout: true)
    File.write!(Path.join(path, "uncommitted.txt"), "a change nobody has committed\n")

    path
  end
end
