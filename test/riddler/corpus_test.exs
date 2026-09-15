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

  The runner and that encoder are `Riddler.Corpus`, not this file, because the
  task that emits this corpus into a second repository runs every case before
  it copies it out and has to run them the way this suite does.
  """

  use ExUnit.Case, async: true

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

  # The runner, the one encoder and the canonical form all live in
  # `Riddler.Corpus` rather than here, because `mix riddler.corpus` emits this
  # corpus into a second repository and has to run every case before it copies
  # it out. Two copies of that logic would let the emitted corpus describe a
  # runtime this suite never ran.

  defp mismatches(path), do: Riddler.Corpus.mismatches(path)

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

  defp read(path), do: Riddler.Corpus.read(path)

  defp cases(path), do: Riddler.Corpus.cases(path)

  defp canonical(value), do: Riddler.Corpus.canonical(value)

  defp repeated_names(path) do
    names = Enum.map(cases(path), & &1["name"])
    Enum.uniq(names -- Enum.uniq(names))
  end

  defp resolved_schema(path), do: path |> read() |> ExJsonSchema.Schema.resolve()

  # -- the retired spellings --------------------------------------------------

  defp every_key(map) when is_map(map) do
    Map.keys(map) ++ Enum.flat_map(Map.values(map), &every_key/1)
  end

  defp every_key(list) when is_list(list), do: Enum.flat_map(list, &every_key/1)
  defp every_key(_value), do: []
end
