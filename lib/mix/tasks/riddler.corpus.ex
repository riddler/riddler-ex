defmodule Mix.Tasks.Riddler.Corpus do
  @shortdoc "Emits the conformance corpus into a riddler_spec checkout, or checks it for drift"

  @moduledoc """
  Copies the conformance corpus and the JSON schemas out of this repository and
  into a checkout of [riddler_spec](https://github.com/riddler/riddler_spec),
  or checks that the copy already there is the one this repository would write.

      mix riddler.corpus --to ../riddler_spec
      mix riddler.corpus --check

  The cases are authored here, beside the code that has to satisfy them, and
  the copy in the other repository is an artifact. So the task runs every case
  through this implementation before it writes anything and refuses on the
  first red case: a corpus copied out of a repository whose own suite it does
  not describe would hold a second runtime to behavior the reference runtime
  does not have.

  What is written is byte-stable - keys sorted, two spaces of indent, one
  trailing newline, no timestamp and no commit - so re-emitting an unchanged
  corpus writes the same bytes and `--check` reports a real change rather than
  the passage of time. Each case file gains one key it was not authored with, a
  `generated_by` naming the version that emitted it and the file here it came
  from. The schemas are copied unchanged.

  ## Where it writes

  In order: the `--to` path, then `$RIDDLER_SPEC_PATH`, then `../riddler_spec`.
  A case file lands at `<path>/corpus/<capability>/<name>.json` and a schema at
  `<path>/schemas/<name>.schema.json`.

  ## Options

    * `--check` - writes nothing. Compares what would be written against what
      is there and exits 1 listing every file that is missing or differs. This
      is the drift check CI runs against a fresh checkout of the corpus
      repository's default branch.
    * `--to PATH` - the checkout to write into.
    * `--force` - write even though the target is a git working tree with
      uncommitted changes. Without it an emit onto a dirty tree is refused,
      because the emit overwrites whole files and git is what would otherwise
      give the work back. `--check` writes nothing and never refuses.
  """

  use Mix.Task

  alias Riddler.Corpus

  @default_target "../riddler_spec"

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(argv) do
    {opts, [], []} =
      OptionParser.parse(argv, strict: [check: :boolean, to: :string, force: :boolean])

    target = target(opts)

    refuse_red_cases()

    if opts[:check], do: check(target), else: emit(target, opts)
  end

  defp target(opts) do
    opts[:to] || System.get_env("RIDDLER_SPEC_PATH") || @default_target
  end

  defp refuse_red_cases do
    case Corpus.failing_cases() do
      [] ->
        :ok

      failing ->
        Mix.raise("""
        the corpus does not describe this implementation, so nothing was emitted.
        #{length(failing)} case(s) answer something other than what they state:

        #{Enum.map_join(failing, "\n", fn {path, name} -> "  #{path}: #{name}" end)}
        """)
    end
  end

  defp emit(target, opts) do
    unless File.dir?(target) do
      Mix.raise("no such directory to emit into: #{target}")
    end

    if Corpus.dirty?(target) and not Keyword.get(opts, :force, false) do
      Mix.raise(
        "#{target} is a git working tree with uncommitted changes. " <>
          "Commit or stash them, or pass --force to overwrite."
      )
    end

    written = Corpus.write(target)

    Mix.shell().info("riddler #{Corpus.version()} -> #{target}")
    Enum.each(written, fn relative -> Mix.shell().info("  wrote #{relative}") end)
    Mix.shell().info("#{length(written)} file(s) written.")

    :ok
  end

  defp check(target) do
    case Corpus.drift(target) do
      [] ->
        Mix.shell().info("#{target} carries the corpus riddler #{Corpus.version()} emits.")
        :ok

      drift ->
        Mix.raise("""
        #{target} does not carry the corpus this repository emits.
        Run `mix riddler.corpus --to #{target}` and open a request there.

        #{Enum.map_join(drift, "\n", fn {relative, reason} -> "  #{reason}: #{relative}" end)}
        """)
    end
  end
end
