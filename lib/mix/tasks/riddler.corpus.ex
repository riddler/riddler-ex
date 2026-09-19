defmodule Mix.Tasks.Riddler.Corpus do
  @shortdoc "Exports the conformance corpus into a directory, or compares a copy already there"

  @moduledoc """
  Exports the conformance corpus and the JSON schemas out of this repository
  into a directory you name, or checks that the copy already in that directory
  is the one this repository would write.

      mix riddler.corpus --to ../export
      mix riddler.corpus --check --to ../export

  The corpus lives in this repository: the cases in `corpus/`, beside the code
  that has to satisfy them, and the schemas in `priv/schemas/`. A runtime in
  another language vendors them from a tag of this repository. This task is for
  a consumer that wants a copy as files, and the copy is an artifact. So the
  task runs every case through this implementation before it writes anything
  and refuses on the first red case: a corpus copied out of a repository whose
  own suite it does not describe would hold a second runtime to behavior the
  reference runtime does not have.

  What is written is byte-stable - keys sorted, two spaces of indent, one
  trailing newline, no version, no timestamp and no commit - so re-exporting an
  unchanged corpus writes the same bytes and `--check` reports a real change
  rather than the passage of time or the cutting of a release. Each case file
  gains one key it was not authored with, `generated_by`, whose value is the
  word `riddler`, a space, the word `from`, a space and the file's path in this
  repository - `"riddler from corpus/screens/admit.json"`. The schemas are
  copied unchanged.

  ## Where it writes

  Into the `--to` directory, and nowhere else: there is no default and no
  environment variable, and the task refuses to run without `--to`. A case file
  lands at `<path>/corpus/<capability>/<name>.json` and a schema at
  `<path>/schemas/<name>.schema.json`.

  ## Options

    * `--to PATH` - required. The directory to export into, or, with
      `--check`, the directory holding the copy to compare.
    * `--check` - writes nothing. Compares what would be written against what
      is there and exits 1 listing every file that is missing or differs.
    * `--force` - write even though the target is a git working tree with
      uncommitted changes. Without it an export onto a dirty tree is refused,
      because the export overwrites whole files and git is what would
      otherwise give the work back. `--check` writes nothing and never refuses.
  """

  use Mix.Task

  alias Riddler.Corpus

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
    case opts[:to] do
      nil ->
        Mix.raise(
          "mix riddler.corpus needs --to PATH, the directory to export into " <>
            "or, with --check, the directory holding the copy to compare."
        )

      path ->
        path
    end
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
        Mix.shell().info(
          "#{target} carries the corpus this repository emits (checked by riddler #{Corpus.version()})."
        )

        :ok

      drift ->
        Mix.raise("""
        #{target} does not carry the corpus this repository emits.
        Run `mix riddler.corpus --to #{target}` to rewrite it.

        #{Enum.map_join(drift, "\n", fn {relative, reason} -> "  #{reason}: #{relative}" end)}
        """)
    end
  end
end
