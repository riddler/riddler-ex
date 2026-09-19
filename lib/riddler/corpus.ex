defmodule Riddler.Corpus do
  @moduledoc false

  # The conformance corpus as data: where the authored files are, how a case is
  # run against this implementation, what the canonical byte form of a file is,
  # and how the whole set is exported into a directory.
  #
  # This module is deliberately not public surface. It exists so that the suite
  # that holds this runtime to the corpus and the task that exports the corpus
  # are one piece of logic: a case that passes here and a case that is emitted
  # are the same case, run by the same code, encoded by the same encoder. Two
  # copies of that logic would let the emitted corpus describe a runtime the
  # suite never ran.
  #
  # It reads the corpus out of the repository tree by relative path. The case
  # files and the schemas are not in the package tarball, so this module is
  # meaningful in a checkout of this repository and nowhere else.

  alias Riddler.Screens
  alias Riddler.Screens.Document
  alias Riddler.Template

  @version Mix.Project.config()[:version]

  @case_files [
    "corpus/screens/admit.json",
    "corpus/screens/resolve.json",
    "corpus/screens/validate_screen.json",
    "corpus/templates/render.json"
  ]

  @schema_files [
    "priv/schemas/screen-document.schema.json",
    "priv/schemas/corpus-case.schema.json"
  ]

  for path <- @case_files ++ @schema_files do
    @external_resource path
  end

  @doc "The authored case files, repo-relative."
  @spec case_files() :: [String.t()]
  def case_files, do: @case_files

  @doc "The authored schema files, repo-relative."
  @spec schema_files() :: [String.t()]
  def schema_files, do: @schema_files

  @doc """
  The version of this package. It labels an emit on the console for whoever is
  running one; no emitted file records it, so that an emit is byte-identical
  across releases.
  """
  @spec version() :: String.t()
  def version, do: @version

  # -- where a source file lands in the corpus repository ---------------------

  @doc """
  The path an authored file takes inside the corpus repository, relative to its
  root: a case file keeps its `corpus/<capability>/<name>.json` shape and a
  schema moves from `priv/schemas/` to `schemas/`.
  """
  @spec target_path(String.t()) :: String.t()
  def target_path("corpus/" <> _rest = path), do: path
  def target_path("priv/schemas/" <> file), do: Path.join("schemas", file)

  # -- running the cases ------------------------------------------------------

  @doc """
  Every case in `path` whose answer from this implementation is not the answer
  the case states, as `{name, answered, stated}`.
  """
  @spec mismatches(String.t()) :: [{String.t(), term(), term()}]
  def mismatches(path) do
    capability = read(path)["capability"]

    path
    |> cases()
    |> Enum.map(fn one -> {one["name"], run(capability, one["input"]), one["expected"]} end)
    |> Enum.reject(fn {_name, answered, stated} -> answered == stated end)
  end

  @doc """
  Every case in the corpus this implementation does not satisfy, as
  `{file, case name}`. An emit runs this first and refuses on a non-empty list:
  a corpus copied out of a repository whose suite it does not describe is worse
  than no corpus, because a second runtime is then held to a behavior the
  reference one does not have.
  """
  @spec failing_cases([String.t()]) :: [{String.t(), String.t()}]
  def failing_cases(paths \\ @case_files) do
    for path <- paths,
        {name, _answered, _stated} <- mismatches(path),
        do: {path, name}
  end

  defp run("screens.admit", input) do
    case Document.admit(input["document"]) do
      nil -> %{"admitted" => false, "findings" => []}
      document -> %{"admitted" => true, "findings" => admit_findings(document)}
    end
  end

  defp run("screens.resolve", input) do
    document = admitted(input["document"])

    case input["screen"] do
      nil ->
        {:ok, resolved} = Screens.resolve(document, input["root"])
        encode(resolved)

      screen_key ->
        case Screens.resolve_screen(document, screen_key, input["root"]) do
          {:ok, screen, _diagnostics} -> encode(screen)
          {:error, :no_such_screen} -> %{"error" => "no_such_screen"}
        end
    end
  end

  defp run("screens.validate_screen", input) do
    input["document"]
    |> admitted()
    |> validate_screen(input)
    |> encode_validation()
  end

  defp run("templates.render", input) do
    case Template.compile(input["source"]) do
      {:error, findings} -> %{"compiled" => false, "findings" => encode_findings(findings)}
      {:ok, compiled} -> render_modes(compiled, input)
    end
  end

  defp admit_findings(document) do
    case Document.validate(document) do
      {:ok, _document} -> []
      {:error, findings} -> encode_findings(findings)
    end
  end

  defp admitted(raw) do
    case Document.admit(raw) do
      nil -> raise ArgumentError, "a case input that is meant to be a document was not admitted"
      document -> document
    end
  end

  defp validate_screen(document, input) do
    # The root a case supplies, not a root built here: validation resolves the
    # screen against the same root the host resolved with, so a case carrying a
    # context is run under that context rather than under an empty one. A case
    # that carries neither key gets the empty maps `Screens` normalizes an
    # absent half to.
    root = Map.take(input, ["context", "responses"])

    case Map.fetch(input, "pressed_button") do
      {:ok, key} ->
        Screens.validate_screen(document, input["screen"], root, key)

      :error ->
        Screens.validate_screen(document, input["screen"], root)
    end
  end

  defp encode_validation(:ok), do: %{"ok" => true}
  defp encode_validation({:error, :no_such_screen}), do: %{"error" => "no_such_screen"}

  defp encode_validation({:error, findings}),
    do: %{"ok" => false, "findings" => encode_findings(findings)}

  # `both` is the corpus's way of saying that a template where nothing is
  # missing renders the same in either mode. It is run twice, and a runtime
  # whose two modes disagree fails the case rather than passing half of it.
  defp render_modes(compiled, input) do
    case input["mode"] do
      nil -> %{"compiled" => true}
      "both" -> agreed(render(compiled, input, :lenient), render(compiled, input, :strict))
      "lenient" -> render(compiled, input, :lenient)
      "strict" -> render(compiled, input, :strict)
    end
  end

  defp agreed(same, same), do: same
  defp agreed(lenient, strict), do: %{"modes_disagree" => [lenient, strict]}

  defp render(compiled, input, mode) do
    case Template.render(compiled, input["assigns"] || %{}, mode) do
      {:ok, text, missing} ->
        %{"compiled" => true, "rendered" => true, "text" => text, "missing" => missing}

      {:error, missing} ->
        %{"compiled" => true, "rendered" => false, "missing" => missing}
    end
  end

  # -- the one encoder --------------------------------------------------------

  # A second runtime compares JSON, not Elixir terms, so every answer is put
  # through this before it is compared: structs become maps, atom keys become
  # strings, and atom values other than `true`, `false` and `nil` become
  # strings. A finding is the one shaped exception: it is compared as `code`,
  # `field` and `node_key` and never by its message, because the code is the
  # stable thing a host switches on and the message is prose a second runtime
  # is not obliged to reproduce word for word.
  defp encode_findings(findings) do
    Enum.map(findings, fn finding ->
      %{"code" => finding.code, "field" => finding.field, "node_key" => finding.node_key}
    end)
  end

  defp encode(struct) when is_struct(struct), do: struct |> Map.from_struct() |> encode()

  defp encode(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {encode_key(key), encode(value)} end)

  defp encode(list) when is_list(list), do: Enum.map(list, &encode/1)
  defp encode(value) when value in [nil, true, false], do: value
  defp encode(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp encode(value), do: value

  defp encode_key(key) when is_atom(key), do: Atom.to_string(key)
  defp encode_key(key), do: key

  # -- reading and canonical form ---------------------------------------------

  @doc "The decoded contents of a JSON file."
  @spec read(String.t()) :: term()
  def read(path), do: path |> File.read!() |> JSON.decode!()

  @doc "The cases a case file carries."
  @spec cases(String.t()) :: [map()]
  def cases(path), do: read(path)["cases"]

  @doc """
  The canonical byte form of a decoded value: keys sorted, two spaces of
  indent, one trailing newline. It is what makes the emit a copy and the drift
  check meaningful - an authored file and its emitted counterpart differ in the
  provenance header and in nothing else, so a diff between them is a real
  change rather than a re-formatting. Scalars are encoded by the JSON library;
  only the layout is this function's.
  """
  @spec canonical(term()) :: String.t()
  def canonical(value), do: IO.iodata_to_binary([layout(value, ""), "\n"])

  defp layout(map, _indent) when map_size(map) == 0, do: "{}"

  defp layout(map, indent) when is_map(map) do
    inner = indent <> "  "

    entries =
      map
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map_intersperse(",\n", fn key ->
        [inner, JSON.encode!(key), ": ", layout(Map.fetch!(map, key), inner)]
      end)

    ["{\n", entries, "\n", indent, "}"]
  end

  defp layout([], _indent), do: "[]"

  defp layout(list, indent) when is_list(list) do
    inner = indent <> "  "
    entries = Enum.map_intersperse(list, ",\n", fn value -> [inner, layout(value, inner)] end)

    ["[\n", entries, "\n", indent, "]"]
  end

  defp layout(value, _indent), do: JSON.encode!(value)

  # -- what is emitted --------------------------------------------------------

  @doc """
  The provenance a case file gains when it is copied out: the word `riddler`,
  a space, the word `from`, a space and the path of the file in this
  repository it came from, and nothing else. It carries no version, no
  timestamp and no commit, so re-emitting an unchanged corpus writes the same
  bytes across commits and across releases alike, and the drift check reports a
  real difference rather than the passage of time or the cutting of a release.
  The version and the commit an emit ran from belong in the request that
  carries it.
  """
  @spec generated_by(String.t()) :: String.t()
  def generated_by(source), do: "riddler from #{source}"

  @doc """
  Every file an export writes, as `{relative target path, contents}`: each
  case file with its provenance header, each schema as it
  stands. The schemas are copied unchanged because a JSON Schema is read by
  validators that are not ours, and a provenance key invented for them would
  travel into every one of those.
  """
  @spec files() :: [{String.t(), String.t()}]
  def files do
    schemas = for path <- @schema_files, do: {target_path(path), canonical(read(path))}

    cases =
      for path <- @case_files do
        contents = path |> read() |> Map.put("generated_by", generated_by(path)) |> canonical()
        {target_path(path), contents}
      end

    cases ++ schemas
  end

  # -- emitting and checking --------------------------------------------------

  @doc """
  Writes the corpus into `root`, returning the relative paths written. The
  caller is responsible for having run `failing_cases/1` first.
  """
  @spec write(String.t()) :: [String.t()]
  def write(root) do
    for {relative, contents} <- files() do
      path = Path.join(root, relative)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, contents)
      relative
    end
  end

  @doc """
  What `root` would have to change to match this repository's corpus, as
  `{relative path, :missing | :differs}`. An empty list is no drift.
  """
  @spec drift(String.t()) :: [{String.t(), :missing | :differs}]
  def drift(root) do
    for {relative, contents} <- files(), reason = compare(Path.join(root, relative), contents) do
      {relative, reason}
    end
  end

  defp compare(path, contents) do
    case File.read(path) do
      {:ok, ^contents} -> nil
      {:ok, _other} -> :differs
      {:error, _reason} -> :missing
    end
  end

  @doc """
  Whether `root` is a git working tree with uncommitted changes. A path that is
  not a git working tree answers `false`: there is nothing there to overwrite
  that git could give back.
  """
  @spec dirty?(String.t()) :: boolean()
  def dirty?(root) do
    case System.cmd("git", ["-C", root, "status", "--porcelain"], stderr_to_stdout: true) do
      {output, 0} -> String.trim(output) != ""
      {_output, _code} -> false
    end
  end
end
