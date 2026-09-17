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
    "corpus/screens/admit.json",
    "corpus/screens/resolve.json",
    "corpus/screens/validate_responses.json",
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
    "corpus/screens/admit.json" => 24,
    "corpus/screens/resolve.json" => 20,
    "corpus/screens/validate_responses.json" => 27,
    "corpus/templates/render.json" => 29
  }

  @draft_7 "http://json-schema.org/draft-07/schema#"

  # The three spellings the vocabulary retired. They are named here, and only
  # here, so that the corpus can be held to not carrying them: a document
  # accepted under two spellings is a document authored under both. Naming them
  # as the data a guard checks against is the rule quoting itself, not a use of
  # them.
  @retired_spellings ["payload", "action", "answers"]

  describe "the corpus files themselves" do
    # Sabotage: re-indented corpus/templates/render.json with four spaces; the
    # file no longer matched its canonical form and this test went red.
    test "every corpus file and every schema is in the canonical form the emitter copies" do
      drift = Enum.reject(@json_files, fn path -> File.read!(path) == canonical(read(path)) end)

      assert drift == []
    end

    # Sabotage: renamed "capability" to "kind" in corpus/screens/admit.json;
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
      names = Enum.map(cases("corpus/screens/resolve.json"), & &1["name"])

      for substance <- ["Basic text:", "Include condition:", "Liquid filter chain:", "Variant:"] do
        assert Enum.any?(names, &String.starts_with?(&1, substance)),
               "no case in the resolve corpus names the substance #{inspect(substance)}"
      end
    end

    # A key was only ever half of it. A retired spelling names a thing just as
    # much when it is a value - a case name, a finding code, a field name, a
    # capability - as when it is a key, and a walk that reads keys only reports
    # a corpus clean while the spelling sits in the name of every case that
    # exercises it. This walk reads both, and a case name is not exempt: the
    # name is how a second runtime refers to the case, so it is vocabulary.
    #
    # Sabotage: put "action" back into the name of the first admission case in
    # corpus/screens/admit.json; the walk found it and this test went red.
    test "no corpus file and no schema carries a retired spelling, in a key or in any string value" do
      carried =
        for path <- @json_files,
            {at, string, word} <- path |> read() |> retired_spellings_in(),
            do: {path, at, word, string}

      assert carried == []
    end

    # The walk reads a list, so a file this list forgets is a file nothing holds
    # to the vocabulary rule - the failure mode of every guard that enumerates
    # its own inputs, and one assertion to close.
    #
    # Sabotage: dropped corpus/templates/render.json from @corpus_files; the
    # list no longer matched the tree and this test went red.
    test "the walk reads every corpus and schema file the repository carries" do
      on_disk = Path.wildcard("corpus/**/*.json") ++ Path.wildcard("priv/schemas/*.json")

      assert Enum.sort(on_disk) == Enum.sort(@json_files)
    end
  end

  describe "the retired-spelling walk" do
    # Whole words, because the rule retires three spellings and not every string
    # that contains their letters. A substring walk would report `transaction`
    # and `answer_options`, and a guard that cries wolf is a guard someone turns
    # off.
    #
    # Sabotage: matched with String.contains?/2 instead of cutting the string
    # into words; the two innocent identifiers came back as hits and this test
    # went red.
    test "a word that merely contains a retired spelling is not a hit" do
      assert retired_spellings_in(%{"transaction" => "answer_options"}) == []
    end

    # The compound is the case a regular expression would have missed, and it is
    # the likelier one: a document that carried `on_action` carried the retired
    # vocabulary just as much as one that carried `action`.
    #
    # Sabotage: cut words on whitespace only, which is what `\b` amounts to for
    # an underscore; `on_action` stayed one word and this test went red.
    test "a compound identifier naming a retired spelling is a hit, key or value" do
      assert [{"nodes.0.on_action", "on_action", "action"}] =
               retired_spellings_in(%{"nodes" => [%{"on_action" => true}]})

      assert [{"expected.code", "button.on_action", "action"}] =
               retired_spellings_in(%{"expected" => %{"code" => "button.on_action"}})
    end

    # What the walk CANNOT do, stated as a test so that nobody reads the guard
    # as cleverer than it is. The rule exempts ordinary English prose and the
    # verb "answers" above all, but inside a JSON string there is nothing to
    # tell the verb in a sentence from the noun that names a field - and a case
    # name, which the rule counts as vocabulary, is written as a sentence. So
    # the walk is deliberately stricter than the rule: every string is held to
    # the three spellings, prose included. The corpus carries no such prose
    # today, and if a case name ever needs the English verb, the way to allow it
    # is a reviewed change here that says which string and why - never a quieter
    # match, and never respelling the verb.
    #
    # Sabotage: exempted any string carrying a space, on the theory that a space
    # means prose; the sentence came back clean and this test went red.
    test "prose is held to the rule too, the walk not being able to tell it apart" do
      assert [{"name", _sentence, "answers"}] =
               retired_spellings_in(%{
                 "name" => "a required question answers a finding when blank"
               })
    end
  end

  describe "the cases" do
    # Sabotage: made admit/1 answer nil for a document carrying metadata; the
    # fixture case came back unadmitted and this test went red.
    test "every admission case answers what the corpus states" do
      assert mismatches("corpus/screens/admit.json") == []
    end

    # Sabotage: handed a container's candidates to the walk reversed, so the
    # last match won; the three variant cases came back with the wrong candidate
    # and this test went red.
    test "every resolution case answers what the corpus states" do
      assert mismatches("corpus/screens/resolve.json") == []
    end

    # Sabotage: made an absent response count as answered rather than blank; the
    # unanswered cases came back :ok and this test went red.
    test "every response validation case answers what the corpus states" do
      assert mismatches("corpus/screens/validate_responses.json") == []
    end

    # Sabotage: added "cycle" to the template allowlist; the cycle refusal case
    # compiled and this test went red.
    test "every template case answers what the corpus states" do
      assert mismatches("corpus/templates/render.json") == []
    end
  end

  describe "the screen document schema" do
    # Sabotage: dropped "screens" from the schema's required list; the cases
    # that are not documents validated against it and this test went red.
    test "admits exactly the values the admission corpus calls documents" do
      schema = resolved_schema(@document_schema)

      disagreements =
        for %{"name" => name, "input" => input, "expected" => expected} <-
              cases("corpus/screens/admit.json"),
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
    for one <- cases("corpus/screens/admit.json"),
        one["expected"]["admitted"],
        do: {one["name"], one["input"]["document"]}
  end

  defp carried_documents do
    for path <- ["corpus/screens/resolve.json", "corpus/screens/validate_responses.json"],
        one <- cases(path),
        do: {one["name"], one["input"]["document"]}
  end

  defp resolved_documents do
    for one <- cases("corpus/screens/resolve.json"),
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

  # Every hit of a retired spelling in a JSON tree, as `{at, string, word}`,
  # where `at` is the dotted path the string sits at so that a reader can find
  # it.
  #
  # Matching is by WORD, not by substring: each string is cut into words on
  # everything that is not a letter or a digit, and each word is compared whole.
  # So `on_action` and "Action taken" are hits, while `transaction` and
  # `answer_options` are not. A regular expression is the obvious way to say
  # "whole word" and the wrong one here, because `\b` counts `_` as a word
  # character: `~r/\baction\b/` matches "Action taken" but misses `on_action`,
  # which is the compound a document is likeliest to carry.
  defp retired_spellings_in(value) do
    for {at, string} <- strings(value, []),
        word <- words(string),
        word in @retired_spellings,
        do: {at, string, word}
  end

  defp strings(map, path) when is_map(map) do
    Enum.flat_map(map, fn {key, value} ->
      at = path ++ [key]
      [{location(at), key} | strings(value, at)]
    end)
  end

  defp strings(list, path) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.flat_map(fn {value, index} -> strings(value, path ++ [index]) end)
  end

  defp strings(value, path) when is_binary(value), do: [{location(path), value}]
  defp strings(_value, _path), do: []

  defp location(path), do: Enum.join(path, ".")

  defp words(string) do
    string |> String.downcase() |> String.split(~r/[^a-z0-9]+/, trim: true)
  end
end
