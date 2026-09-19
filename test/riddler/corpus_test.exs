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
  task that exports this corpus runs every case before it copies it out and
  has to run them the way this suite does.
  """

  use ExUnit.Case, async: true

  @corpus_files [
    "corpus/screens/admit.json",
    "corpus/screens/resolve.json",
    "corpus/screens/validate_screen.json",
    "corpus/templates/render.json"
  ]

  @document_schema "priv/schemas/screen-document.schema.json"
  @case_schema "priv/schemas/corpus-case.schema.json"
  @json_files @corpus_files ++ [@document_schema, @case_schema]

  for path <- @json_files do
    @external_resource path
  end

  # A second runtime vendors the corpus from a tag of this repository, so the
  # count is part of what this version pins: a case lost in a rebase is a case
  # a second runtime stops being held to, and nothing else would notice.
  @case_counts %{
    "corpus/screens/admit.json" => 42,
    "corpus/screens/resolve.json" => 21,
    "corpus/screens/validate_screen.json" => 34,
    "corpus/templates/render.json" => 58
  }

  @draft_7 "http://json-schema.org/draft-07/schema#"

  # The three spellings the vocabulary retired. They are named here, and only
  # here, so that the corpus can be held to not carrying them: a document
  # accepted under two spellings is a document authored under both. Naming them
  # as the data a guard checks against is the rule quoting itself, not a use of
  # them.
  @retired_spellings ["payload", "action", "answers"]

  # The escape hatch, as data rather than as an edit someone has to invent
  # under deadline. Each entry is a `{file, path, reason}` triple: the file the
  # string sits in, the dotted path the walk already computes for it, and why
  # that one string is allowed to carry a retired spelling. The walk drops a
  # hit whose file and path both match an entry, and nothing else.
  #
  # It is EMPTY, so it changes nothing today. It exists so that the first
  # person who meets the strictness described below has an edit to make that a
  # reviewer can read: one named string with a stated reason, never a quieter
  # match and never a respelled verb.
  @spelling_exemptions []

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
            {at, string, word} <- retired_spellings_in(read(path), path),
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
    # off. The schema's own camelCase vocabulary is here for the same reason: it
    # is scanned like everything else, the case-boundary split below cuts it,
    # and the words it is cut into have to stay innocent.
    #
    # Sabotage: matched with String.contains?/2 instead of cutting the string
    # into words; `transaction` came back as a hit and this test went red.
    test "a word that merely contains a retired spelling is not a hit" do
      assert retired_spellings_in(%{"transaction" => "answer_options"}) == []

      assert retired_spellings_in(%{"additionalProperties" => false, "minItems" => 1}) == []
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

    # The camelCase compound is that same mistake in the idiom of the runtime
    # likeliest to make it: this corpus is emitted for a second implementation,
    # and that implementation's keys may well be camelCase. Cutting on the
    # lower-to-upper transition is what sees it, and the cut has to happen
    # before the downcase, which is the only thing that destroys the boundary.
    #
    # Sabotage: removed the case-boundary split from `words/1`; `onAction`
    # stayed one word and this test went red.
    test "a camelCase compound naming a retired spelling is a hit, key or value" do
      assert [{"nodes.0.onAction", "onAction", "action"}] =
               retired_spellings_in(%{"nodes" => [%{"onAction" => true}]})

      assert [{"expected.code", "actionType", "action"}] =
               retired_spellings_in(%{"expected" => %{"code" => "actionType"}})
    end

    # An acronym-led compound is the camelCase compound again, written with a
    # run of capitals in front: `UIAction` has no lower-to-upper transition
    # before its `Action`, so the first cut leaves it one word. A second cut
    # runs where a capital starts a word after a run of capitals, which is the
    # upper-to-upper boundary followed by a lower. A run of capitals with no
    # lower after it is not cut, so an acronym stays one word and the words
    # around it stay innocent.
    #
    # Sabotage: removed the upper-to-upper split from `words/1`; `UIAction`
    # stayed one word and this test went red.
    test "an acronym-led compound naming a retired spelling is a hit, key or value" do
      assert [{"nodes.0.UIAction", "UIAction", "action"}] =
               retired_spellings_in(%{"nodes" => [%{"UIAction" => true}]})

      assert [{"expected.code", "HTTPPayloads", "payload"}] =
               retired_spellings_in(%{"expected" => %{"code" => "HTTPPayloads"}})

      assert retired_spellings_in(%{"UITransaction" => "JSONSchema", "URL" => "SMSAnswer"}) ==
               []
    end

    # A possessive is cut at its apostrophe like any other character that is not
    # a letter or a digit, so `action's` is the word `action` and a hit. A
    # trailing `es` is deliberately not cut: none of the three retired spellings
    # forms its plural with it, so an `es` arm would catch no inflection of them
    # and could only reach a word the rule does not retire.
    #
    # Sabotage: let the word split keep an apostrophe inside a word; `action's`
    # stayed one word and the first assertion went red. And again with an arm in
    # `retired_spelling/1` cutting a trailing `es`; `actiones` came back as a hit
    # and the second assertion went red.
    test "a possessive is a hit and an -es ending is not cut" do
      assert [{"name", "the action's key", "action"}] =
               retired_spellings_in(%{"name" => "the action's key"})

      assert retired_spellings_in(%{"actiones" => "payloades"}) == []
    end

    # A plural names the thing its singular names, so a document that carried
    # `actions` carried the retired vocabulary. The hit is reported under the
    # retired spelling itself rather than under the inflection, because what
    # the author has to change is the word, not the `s`. The rule's own
    # `answers` is unaffected: its singular is `answer`, which is not retired,
    # so cutting one trailing `s` never reaches past the three spellings.
    #
    # Sabotage: dropped the plural arm from `retired_spelling/1`; `actions` and
    # `payloads` came back clean and this test went red.
    test "the plural of a retired spelling is a hit, reported under the spelling" do
      assert [{"actions", "actions", "action"}, {"actions", "payloads", "payload"}] =
               retired_spellings_in(%{"actions" => "payloads"})

      assert retired_spellings_in(%{"answer" => "options"}) == []
    end

    # The hatch the comment below describes, driven with an explicit list so
    # that what an entry would do is pinned without putting a real entry in
    # `@spelling_exemptions`, which is empty and stays empty until there is a
    # case for it. An entry exempts one file at one path: the same path in
    # another file, and another path in the same file, are still hits. A path
    # is compared whole and not as a prefix, which is the difference between
    # exempting one named string and exempting a subtree nobody reviewed: an
    # entry at `expected` must not carry `expected.code` with it.
    #
    # Sabotage: made `exempt?/3` compare the path only, ignoring the file; the
    # second assertion came back one hit short and this test went red. And
    # again with `exempt?/3` matching a path by String.starts_with?/2; the
    # prefix entry swallowed the longer path and this test went red.
    test "an exemption entry exempts exactly its file and its path, and nothing else" do
      value = %{"name" => "an action", "expected" => %{"code" => "on_action"}}
      exemptions = [{"corpus/screens/admit.json", "name", "a fixture, not a real entry"}]
      prefix = [{"corpus/screens/admit.json", "expected", "a fixture, not a real entry"}]

      assert [{"expected.code", "on_action", "action"}] =
               retired_spellings_in(value, "corpus/screens/admit.json", exemptions)

      assert [{"expected.code", "on_action", "action"}, {"name", "an action", "action"}] =
               retired_spellings_in(value, "corpus/screens/resolve.json", exemptions)

      assert [{"expected.code", "on_action", "action"}, {"name", "an action", "action"}] =
               retired_spellings_in(value, "corpus/screens/admit.json", [])

      assert [{"expected.code", "on_action", "action"}, {"name", "an action", "action"}] =
               retired_spellings_in(value, "corpus/screens/admit.json", prefix)
    end

    # What the walk CANNOT do, stated as a test so that nobody reads the guard
    # as cleverer than it is. The rule exempts ordinary English prose and the
    # verb "answers" above all, but inside a JSON string there is nothing to
    # tell the verb in a sentence from the noun that names a field - and a case
    # name, which the rule counts as vocabulary, is written as a sentence. So
    # the walk is deliberately stricter than the rule: every string is held to
    # the three spellings, prose included. The corpus carries no such prose
    # today, and if a case name ever needs the English verb, the way to allow it
    # is an entry in `@spelling_exemptions` naming that file and that path and
    # saying why - never a quieter match, and never respelling the verb.
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
      assert mismatches("corpus/screens/validate_screen.json") == []
    end

    # The capability string this version renamed is gone, not kept alive beside
    # the new one. The runner carries a clause per capability and no fallback,
    # so a case file naming a capability it does not carry raises where a case
    # would have run - and a corpus still naming the old string is a red run
    # rather than one that quietly passes under a compatibility clause nobody
    # decided to add. The name is the contract a second runtime dispatches on,
    # and two live names for one behavior is two contracts.
    #
    # Sabotage: added a `defp run("screens.validate_responses", input)` clause
    # to `Riddler.Corpus` delegating to the new one; the retired string ran the
    # case instead of raising and this test went red.
    test "the capability string this version retired is an unknown capability, not an alias" do
      path =
        Path.join(
          System.tmp_dir!(),
          "retired-capability-#{System.unique_integer([:positive])}.json"
        )

      File.write!(path, Riddler.Corpus.canonical(retired_capability_case()))
      on_exit(fn -> File.rm(path) end)

      assert_raise FunctionClauseError, fn -> Riddler.Corpus.mismatches(path) end
    end

    # Sabotage: added "cycle" to the template allowlist; the cycle refusal case
    # compiled and this test went red.
    test "every template case answers what the corpus states" do
      assert mismatches("corpus/templates/render.json") == []
    end
  end

  describe "the screen document schema" do
    # Both directions: a case the corpus calls a document is one the schema
    # validates, and a case it calls no document is one the schema refuses.
    # The validity is bound by a generator rather than by a bare `valid = ...`,
    # which a comprehension reads as a filter too and which would drop every
    # value the schema refuses before the comparison ran.
    #
    # Sabotage: dropped "screens" from the schema's required list; the cases
    # that are not documents validated against it and this test went red. And
    # again with a draft case stating `"admitted": true` for a document whose
    # id is 7, which the schema refuses; this test went red on it, where the
    # filtering binding it replaces had skipped it.
    test "admits exactly the values the admission corpus calls documents" do
      schema = resolved_schema(@document_schema)

      disagreements =
        for %{"name" => name, "input" => input, "expected" => expected} <-
              cases("corpus/screens/admit.json"),
            valid <- [ExJsonSchema.Validator.valid?(schema, input["document"])],
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

  # A case file shaped like a real one and naming the capability this version
  # retired. It is written to a temporary path rather than into `corpus/`,
  # because the corpus is what the file lists above hold to the tree and a file
  # there naming a capability the runner does not carry is exactly what those
  # lists exist to refuse.
  defp retired_capability_case do
    %{
      "capability" => "screens.validate_responses",
      "cases" => [
        %{
          "name" => "a case naming the capability this version retired",
          "input" => %{
            "document" => %{
              "id" => "edoc_signup_screens",
              "schema_version" => 1,
              "screens" => [
                %{"key" => "account", "title" => "Create your account", "nodes" => []}
              ]
            },
            "responses" => %{},
            "screen" => "account"
          },
          "expected" => %{"ok" => true}
        }
      ]
    }
  end

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
    for path <- ["corpus/screens/resolve.json", "corpus/screens/validate_screen.json"],
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
  # everything that is not a letter or a digit, on every lower-to-upper
  # transition, and before a capital that starts a word after a run of
  # capitals, and each word is compared whole, singular or plural. So
  # `on_action`, `onAction`, `UIAction`, `actions` and "Action taken" are hits,
  # while `transaction`, `answer_options` and the schema's own
  # `additionalProperties` are not. A regular expression is the obvious way to say "whole word" and the
  # wrong one here, because `\b` counts `_` as a word character:
  # `~r/\baction\b/` matches "Action taken" but misses `on_action`, which is the
  # compound a document is likeliest to carry.
  #
  # `file` is the file the value was read from, and it is what lets an entry in
  # `@spelling_exemptions` name one string rather than a class of them; the
  # exemptions are passed rather than read so that the tests can drive the check
  # with an entry without one having to exist.
  defp retired_spellings_in(value, file \\ nil, exemptions \\ @spelling_exemptions) do
    for {at, string} <- strings(value, []),
        not exempt?(exemptions, file, at),
        word <- words(string),
        spelling = retired_spelling(word),
        do: {at, string, spelling}
  end

  defp exempt?(exemptions, file, at) do
    Enum.any?(exemptions, fn {exempt_file, exempt_path, _reason} ->
      exempt_file == file and exempt_path == at
    end)
  end

  # The spelling a word carries, or `nil`. A plural names what its singular
  # names, so `actions` is reported as `action`: the fix is the word, not the
  # inflection. `answers` is itself retired and its singular `answer` is not, so
  # cutting one trailing `s` never reaches past the three spellings. A trailing
  # `es` is not cut: none of the three forms its plural with it.
  defp retired_spelling(word) do
    cond do
      word in @retired_spellings ->
        word

      String.replace_suffix(word, "s", "") in @retired_spellings ->
        String.replace_suffix(word, "s", "")

      true ->
        nil
    end
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

  # The case-boundary splits run before the downcase, because downcasing is what
  # destroys the boundary. The first cuts a lower-to-upper transition
  # (`onAction`); the second cuts before a capital that starts a word after a
  # run of capitals (`UIAction`), and leaves a run with no lower after it whole.
  defp words(string) do
    string
    |> String.replace(~r/(?<=[a-z0-9])(?=[A-Z])/, " ")
    |> String.replace(~r/(?<=[A-Z])(?=[A-Z][a-z])/, " ")
    |> String.downcase()
    |> String.split(~r/[^a-z0-9]+/, trim: true)
  end
end
