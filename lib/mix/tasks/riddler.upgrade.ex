defmodule Mix.Tasks.Riddler.Upgrade do
  @shortdoc "Rewrites one version 1 screen document as version 2"

  @moduledoc """
  Rewrites the screen document in one file from version 1 to version 2.

      mix riddler.upgrade path/to/patron_registration.json

  It makes exactly two changes, the ones `Riddler.Screens.upgrade/1` makes to
  a decoded document: `schema_version` becomes `2`, written in where the
  document declared none, and the `nodes` key of every screen and of every
  `variant` becomes `elements`, its list as written. The file is edited in
  place and every other byte of it - the other keys, their order, the
  whitespace - is left as it was written. Nothing else in the document is
  read or changed, so a document that is wrong stays wrong in the same way.

  Admission never rewrites a document: a version 1 document is admitted as
  version 1 until its host runs this task, or calls `Riddler.Screens.upgrade/1`
  from its own migration, and nothing rewrites it but that.

  ## What it answers

  A version 1 document is rewritten, and the task says so. A version 2
  document is left as it is and nothing is written, so running the task twice
  is running it once. The task exits 1, writing nothing, for a path that
  cannot be read, a file that is not JSON, a document
  `Riddler.Screens.Document.admit/1` answers `nil` for, a version 1 document
  that already carries an `elements` key on a screen or an element, a
  document whose `schema_version` is neither 1 nor 2, and a file whose edited
  text would not decode to the document `Riddler.Screens.upgrade/1` answers;
  the message names which. It takes one path and no options.
  """

  use Mix.Task

  alias Riddler.Screens.Upgrade

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(argv) do
    path = path(argv)
    text = read(path)

    case Upgrade.rewrite_text(text) do
      {:ok, ^text} ->
        Mix.shell().info("#{path} is already version 2; nothing was written.")

      {:ok, upgraded} ->
        File.write!(path, upgraded)
        Mix.shell().info("#{path} is rewritten as version 2.")

      {:error, reason} ->
        Mix.raise("#{path} was not upgraded: #{reason(reason)}")
    end

    :ok
  end

  defp path(argv) do
    case OptionParser.parse(argv, strict: []) do
      {[], [path], []} ->
        path

      _other ->
        Mix.raise(
          "mix riddler.upgrade takes the path of one screen document: " <>
            "mix riddler.upgrade PATH"
        )
    end
  end

  defp read(path) do
    case File.read(path) do
      {:ok, text} -> text
      {:error, reason} -> Mix.raise("could not read #{path}: #{:file.format_error(reason)}")
    end
  end

  defp reason(:not_json), do: "it is not JSON."

  defp reason(:not_a_document),
    do: "it is not a screen document; Riddler.Screens.Document.admit/1 answers nil for it."

  defp reason(:other_version_spelling),
    do:
      "it is a version 1 document that already carries an elements key on a screen " <>
        "or an element. A version 1 document spells its children nodes; remove the " <>
        "elements key and run the task again."

  defp reason(:unverified_edit),
    do:
      "editing its text in place did not give the document " <>
        "Riddler.Screens.upgrade/1 answers for it, so nothing was written."

  defp reason(:unsupported_version),
    do: "its schema_version is neither 1 nor 2; only a version 1 document is upgraded."
end
