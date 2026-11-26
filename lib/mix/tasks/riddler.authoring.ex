defmodule Mix.Tasks.Riddler.Authoring do
  @shortdoc "Writes the authoring schema and the element instructions from the type registry"

  @moduledoc """
  Writes the authoring schema and the element instructions into
  `priv/authoring/`, or checks that the committed copies are the ones the
  element type registry gives.

      mix riddler.authoring
      mix riddler.authoring --check

  Two files are written, both from `Riddler.Screens.Registry` and each type's
  `fields/0`:

    * `priv/authoring/screen-authoring.schema.json` - a JSON Schema an
      authoring tool validates a screen document against while it is being
      written. The element types are enumerated, each type takes exactly the
      fields the registry names for it and the fields every element shares,
      and a field this version does not read is refused. A document
      `Riddler.Screens.Document.validate/1` accepts, and that carries no field
      admission drops, validates against it.
      The transport schema, `priv/schemas/screen-document.schema.json`, is
      unchanged: there `type` stays an open string.
    * `priv/authoring/screen-elements.md` - a short plain text per element
      type, for an author or an authoring tool: what the type is, and the
      fields it requires and takes.

  Both files are generated and never edited by hand. What is written is
  byte-stable - keys sorted, two spaces of indent, one trailing newline - so
  writing again from an unchanged registry writes the same bytes, and the
  suite fails when a committed file differs from what this task would write.
  The task reads and writes files only; it calls nothing outside this
  package.

  It runs in a checkout of this repository and refuses to run in any other
  project, where `priv/authoring/` would be that project's directory.

  ## Options

    * `--check` - writes nothing. Compares what would be written against what
      is committed and exits 1 listing every file that is missing or differs.
  """

  use Mix.Task

  alias Riddler.Screens.Authoring

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(argv) do
    {opts, [], []} = OptionParser.parse(argv, strict: [check: :boolean])

    unless Mix.Project.config()[:app] == :riddler do
      Mix.raise(
        "mix riddler.authoring writes into this repository's priv/authoring and runs only in it."
      )
    end

    root = File.cwd!()

    if opts[:check], do: check(root), else: emit(root)
  end

  defp emit(root) do
    written = Authoring.write(root)
    Enum.each(written, fn relative -> Mix.shell().info("wrote #{relative}") end)
    :ok
  end

  defp check(root) do
    case Authoring.drift(root) do
      [] ->
        Mix.shell().info("priv/authoring carries what the element type registry gives.")
        :ok

      drift ->
        Mix.raise("""
        priv/authoring does not carry what the element type registry gives.
        Run `mix riddler.authoring` to rewrite it.

        #{Enum.map_join(drift, "\n", fn {relative, reason} -> "  #{reason}: #{relative}" end)}
        """)
    end
  end
end
