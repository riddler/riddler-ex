defmodule Riddler.CorpusTest do
  @moduledoc """
  The conformance corpus, run against the implementation it was authored beside.

  Every case in `corpus/` is an input and the answer every runtime has to give
  for it. This file is what makes the corpus true of this runtime: it reads
  each case file, runs each case through the function its `capability` names,
  and compares the answer to the one the case states. A case the
  implementation does not satisfy is a red test, so the corpus can never drift
  into describing a runtime that does not exist.

  ## The one encoder

  A second runtime compares JSON, not Elixir terms, so every answer is put
  through one encoder before it is compared: structs become maps, atom keys
  become strings, and atom values other than `true`, `false` and `nil` become
  strings. Nothing else is touched - a rendered string, a number and a list
  come back as themselves. Findings are the one shaped exception: a finding is
  compared as `code`, `field` and `node_key` and never by its message, because
  the code is the stable thing a host switches on and the message is prose a
  second runtime is not obliged to reproduce word for word.
  """

  use ExUnit.Case, async: true

  alias Riddler.Elements
  alias Riddler.Elements.Document
  alias Riddler.Template

  @corpus_files [
    "corpus/elements/admit.json",
    "corpus/elements/resolve.json",
    "corpus/elements/validate_responses.json",
    "corpus/templates/render.json"
  ]

  @document_schema "priv/schemas/element-document.schema.json"
  @case_schema "priv/schemas/corpus-case.schema.json"
  @json_files @corpus_files ++ [@document_schema, @case_schema]

  for path <- @json_files do
    @external_resource path
  end

  # The corpus is emitted into a second repository and checked there for drift,
  # so the count is part of what this version pins: a case lost in a rebase is
  # a case a second runtime stops being held to, and nothing else would notice.
  @case_counts %{
    "corpus/elements/admit.json" => 21,
    "corpus/elements/resolve.json" => 20,
    "corpus/elements/validate_responses.json" => 27,
    "corpus/templates/render.json" => 29
  }

  @draft_7 "http://json-schema.org/draft-07/schema#"

  # The three spellings the vocabulary retired. They are named here, and only
  # here, so that the corpus can be held to not carrying them: a document
  # accepted under two spellings is a document authored under both.
  @retired_spellings ["payload", "action", "answers"]

  describe "the corpus files themselves" do
    # Sabotage: re-indented corpus/templates/render.json with four spaces; the
    # file no longer matched its canonical form and this test went red.
    test "every corpus file and every schema is in the canonical form the emitter copies" do
      drift = Enum.reject(@json_files, fn path -> File.read!(path) == canonical(read(path)) end)

      assert drift == []
    end

    # Sabotage: renamed "capability" to "kind" in corpus/elements/admit.json;
    # the required-property check failed and this test went red.
    test "every corpus file satisfies the corpus case schema" do
      schema = resolved_schema(@case_schema)

      invalid =
        for path <- @corpus_files,
            {:error, errors} <- [ExJsonSchema.Validator.validate(schema, read(path))],
            do: {path, errors}

      assert invalid == []
    end

    # Sabotage: changed the $schema of the corpus case schema to the 2020-12
    # URL; resolving it raised the unsupported-version error and this test went
    # red.
    test "both schemas name JSON Schema draft 7, the highest draft the validator knows" do
      for path <- [@document_schema, @case_schema] do
        assert read(path)["$schema"] == @draft_7
        assert %ExJsonSchema.Schema.Root{} = resolved_schema(path)
      end
    end

    # Sabotage: deleted the liquid refusal case from corpus/templates/render.json;
    # that file's count was one short and this test went red.
    test "every corpus file holds the cases this version pins, each under its own name" do
      counts = Map.new(@corpus_files, fn path -> {path, length(cases(path))} end)

      assert counts == @case_counts

      repeated =
        @corpus_files
        |> Enum.map(fn path -> {path, repeated_names(path)} end)
        |> Enum.reject(fn {_path, names} -> names == [] end)

      assert repeated == []
    end

    # Sabotage: renamed the two "Liquid filter chain" cases; the substance was
    # no longer findable by name and this test went red.
    test "the four substances the 2019 corpus carried are present by name" do
      names = Enum.map(cases("corpus/elements/resolve.json"), & &1["name"])

      for substance <- ["Basic text:", "Include condition:", "Liquid filter chain:", "Variant:"] do
        assert Enum.any?(names, &String.starts_with?(&1, substance)),
               "no case in the resolve corpus names the substance #{inspect(substance)}"
      end
    end

    # Sabotage: pointed the walk at "capability", a key every corpus file does
    # carry; the walk found it and this test went red.
    test "no corpus file and no schema carries a key the vocabulary retired" do
      carried =
        for path <- @json_files,
            key <- path |> read() |> every_key(),
            key in @retired_spellings,
            do: {path, key}

      assert carried == []
    end
  end

  describe "the cases" do
    # Sabotage: made admit/1 answer nil for a document carrying metadata; the
    # fixture case came back unadmitted and this test went red.
    test "every admission case answers what the corpus states" do
      assert mismatches("corpus/elements/admit.json") == []
    end

    # Sabotage: handed a container's candidates to the walk reversed, so the
    # last match won; the three variant cases came back with the wrong candidate
    # and this test went red.
    test "every resolution case answers what the corpus states" do
      assert mismatches("corpus/elements/resolve.json") == []
    end

    # Sabotage: made an absent response count as answered rather than blank; the
    # unanswered cases came back :ok and this test went red.
    test "every response validation case answers what the corpus states" do
      assert mismatches("corpus/elements/validate_responses.json") == []
    end

    # Sabotage: added "cycle" to the template allowlist; the cycle refusal case
    # compiled and this test went red.
    test "every template case answers what the corpus states" do
      assert mismatches("corpus/templates/render.json") == []
    end
  end

  describe "the element document schema" do
    # Sabotage: dropped "screens" from the schema's required list; the cases
    # that are not documents validated against it and this test went red.
    test "admits exactly the values the admission corpus calls documents" do
      schema = resolved_schema(@document_schema)

      disagreements =
        for %{"name" => name, "input" => input, "expected" => expected} <-
              cases("corpus/elements/admit.json"),
            valid = ExJsonSchema.Validator.valid?(schema, input["document"]),
            valid != expected["admitted"],
            do: {name, valid, expected["admitted"]}

      assert disagreements == []
    end

    # Sabotage: typed a node's key as an integer in the schema; every document
    # the corpus carries failed validation and this test went red.
    test "validates every document the rest of the corpus carries, resolved documents included" do
      schema = resolved_schema(@document_schema)

      invalid =
        for {name, document} <- every_document(),
            not ExJsonSchema.Validator.valid?(schema, document),
            do: {name, ExJsonSchema.Validator.validate(schema, document)}

      assert invalid == []
    end
  end

  # -- running one case -------------------------------------------------------

  defp mismatches(path) do
    capability = read(path)["capability"]

    path
    |> cases()
    |> Enum.map(fn one -> {one["name"], run(capability, one["input"]), one["expected"]} end)
    |> Enum.reject(fn {_name, answered, stated} -> answered == stated end)
  end

  defp run("elements.admit", input) do
    case Document.admit(input["document"]) do
      nil -> %{"admitted" => false, "findings" => []}
      document -> %{"admitted" => true, "findings" => admit_findings(document)}
    end
  end

  defp run("elements.resolve", input) do
    document = admitted(input["document"])

    case input["screen"] do
      nil ->
        {:ok, resolved} = Elements.resolve(document, input["root"])
        encode(resolved)

      screen_key ->
        case Elements.resolve_screen(document, screen_key, input["root"]) do
          {:ok, screen} -> encode(screen)
          {:error, :no_such_screen} -> %{"error" => "no_such_screen"}
        end
    end
  end

  defp run("elements.validate_responses", input) do
    document = admitted(input["document"])

    document
    |> validate_responses(input)
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
    document = Document.admit(raw)
    refute is_nil(document), "a case input that is meant to be a document was not admitted"
    document
  end

  defp validate_responses(document, input) do
    case Map.fetch(input, "pressed_button") do
      {:ok, key} ->
        Elements.validate_responses(document, input["screen"], input["responses"], key)

      :error ->
        Elements.validate_responses(document, input["screen"], input["responses"])
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

  # -- the documents the corpus carries ---------------------------------------

  defp every_document do
    admitted_documents() ++ carried_documents() ++ resolved_documents()
  end

  defp admitted_documents do
    for one <- cases("corpus/elements/admit.json"),
        one["expected"]["admitted"],
        do: {one["name"], one["input"]["document"]}
  end

  defp carried_documents do
    for path <- ["corpus/elements/resolve.json", "corpus/elements/validate_responses.json"],
        one <- cases(path),
        do: {one["name"], one["input"]["document"]}
  end

  defp resolved_documents do
    for one <- cases("corpus/elements/resolve.json"),
        is_nil(one["input"]["screen"]),
        do: {one["name"] <> " (resolved)", one["expected"]}
  end

  # -- reading and canonical form ---------------------------------------------

  defp read(path), do: path |> File.read!() |> Jason.decode!()

  defp cases(path), do: read(path)["cases"]

  defp repeated_names(path) do
    names = Enum.map(cases(path), & &1["name"])
    Enum.uniq(names -- Enum.uniq(names))
  end

  defp resolved_schema(path), do: path |> read() |> ExJsonSchema.Schema.resolve()

  # The canonical form is what makes the emit a copy and the drift check
  # meaningful: keys sorted, two spaces of indent, one trailing newline. Scalars
  # are encoded by the JSON library, so only the shape is this function's.
  defp canonical(value), do: IO.iodata_to_binary([layout(value, ""), "\n"])

  defp layout(map, _indent) when map_size(map) == 0, do: "{}"

  defp layout(map, indent) when is_map(map) do
    inner = indent <> "  "

    entries =
      map
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map_intersperse(",\n", fn key ->
        [inner, Jason.encode!(key), ": ", layout(Map.fetch!(map, key), inner)]
      end)

    ["{\n", entries, "\n", indent, "}"]
  end

  defp layout([], _indent), do: "[]"

  defp layout(list, indent) when is_list(list) do
    inner = indent <> "  "
    entries = Enum.map_intersperse(list, ",\n", fn value -> [inner, layout(value, inner)] end)

    ["[\n", entries, "\n", indent, "]"]
  end

  defp layout(value, _indent), do: Jason.encode!(value)

  # -- the retired spellings --------------------------------------------------

  defp every_key(map) when is_map(map) do
    Map.keys(map) ++ Enum.flat_map(Map.values(map), &every_key/1)
  end

  defp every_key(list) when is_list(list), do: Enum.flat_map(list, &every_key/1)
  defp every_key(_value), do: []
end
