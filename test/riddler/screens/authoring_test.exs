defmodule Riddler.Screens.AuthoringTest do
  @moduledoc """
  The authoring schema and the element instructions in `priv/authoring/`:
  that the committed files are the ones the registry gives, that the schema
  takes each type's fields from the registry, and that it agrees with what
  `Riddler.Screens.Document.validate/1` accepts over every corpus document.
  """

  use ExUnit.Case, async: true

  alias Riddler.Corpus
  alias Riddler.Screens.Authoring
  alias Riddler.Screens.Checks
  alias Riddler.Screens.Document
  alias Riddler.Screens.Registry

  @schema_path "priv/authoring/screen-authoring.schema.json"
  @instructions_path "priv/authoring/screen-elements.md"
  @transport_path "priv/schemas/screen-document.schema.json"

  # Every corpus case input that carries a screen document.
  @document_files [
    "corpus/screens/admit.json",
    "corpus/screens/resolve.json",
    "corpus/screens/validate_screen.json",
    "corpus/screens/seal_secrets.json",
    "corpus/journey/present.json"
  ]

  # The findings the authoring schema states as a structural rule, so a
  # document refused with only these is refused by the schema too.
  @structural_codes [
    "document.unknown_kind",
    "document.invalid_schema_version",
    "document.other_version_spelling",
    "document.unknown_type",
    "document.missing_field",
    "document.invalid_key",
    "document.conflicting_options"
  ]

  describe "the committed files" do
    # Sabotage: changed one byte of priv/authoring/screen-elements.md; drift
    # reported it as differing and this test went red.
    test "are the bytes the registry gives, so a hand edit or a stale file is red" do
      assert Authoring.drift(File.cwd!()) == []
    end

    # Sabotage: made compare/2 answer nil for a file that differs; the
    # changed copy read as no drift and this test went red.
    test "a copy that differs or is missing is reported as drift" do
      root = Path.join(System.tmp_dir!(), "authoring-drift-#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf!(root) end)

      assert Enum.sort(Authoring.drift(root)) ==
               [{@schema_path, :missing}, {@instructions_path, :missing}]

      Authoring.write(root)
      assert Authoring.drift(root) == []

      File.write!(Path.join(root, @instructions_path), "edited by hand\n")
      assert Authoring.drift(root) == [{@instructions_path, :differs}]
    end
  end

  describe "the schema takes each type from the registry" do
    # Sabotage: dropped :alt from the image type's required fields; the
    # schema's image branch no longer required it and this test went red.
    test "enumerates the registered types and, per type, exactly their fields" do
      schema = Corpus.read(@schema_path)

      for version <- ["1", "2"] do
        element = schema["definitions"]["element_version_#{version}"]
        assert element["properties"]["type"]["enum"] == Registry.types()

        branches =
          Map.new(element["allOf"], &{&1["if"]["properties"]["type"]["const"], &1["then"]})

        assert Enum.sort(Map.keys(branches)) == Registry.types()

        for type <- Registry.types() do
          {:ok, module} = Registry.fetch(type)
          %{required: required, optional: optional} = module.fields()
          spell = &spelling(&1, version)

          checks = if type in Checks.question_types(), do: ["checks"], else: []

          expected =
            Enum.uniq(
              ~w(type key condition accessible_label accessible_description) ++
                checks ++ Enum.map(required ++ (optional -- refused(type)), spell)
            )

          assert Enum.sort(Map.keys(branches[type]["properties"])) == Enum.sort(expected)

          stated_required =
            branches[type]["required"] ++
              Enum.flat_map(Map.get(branches[type], "allOf", []), fn alt ->
                [%{"required" => [field]}, %{"required" => [_other]}] = alt["oneOf"]
                [field]
              end)

          assert Enum.sort(stated_required) ==
                   Enum.sort(["type", "key" | Enum.map(required, spell)])

          assert branches[type]["additionalProperties"] == false
        end
      end
    end

    # Sabotage: changed one byte of the text type's sentence in the committed
    # instructions; its section no longer read the sentence and this test
    # went red.
    test "every type carries an instruction sentence and a section in the instructions" do
      instructions = File.read!(@instructions_path)

      for type <- Registry.types() do
        assert Map.has_key?(Authoring.sentences(), type)
        assert instructions =~ "## #{type}\n\n#{Authoring.sentences()[type]}\n"
      end
    end

    # Sabotage: printed an alternative's two fields as two separate names in
    # list/2 and regenerated; the choice question's Required line changed and
    # this test went red.
    test "the instructions list each type's required and optional fields" do
      instructions = File.read!(@instructions_path)

      assert instructions =~
               "Required: `label`, `select`, `answer_options` or `answer_options_from`.\n"

      assert instructions =~
               "## image\n\n#{Authoring.sentences()["image"]}\n\nRequired: `src`, `alt`.\nOptional: `size`, `fit`.\n"

      assert instructions =~
               "## divider\n\n#{Authoring.sentences()["divider"]}\n\nRequired: none.\nOptional: none.\n"

      assert instructions =~
               "## secret_question\n\n#{Authoring.sentences()["secret_question"]}\n\nRequired: `label`.\nOptional: `required`, `help`, `messages`.\n"
    end
  end

  describe "hand-built documents against the schema" do
    setup do
      %{schema: @schema_path |> Corpus.read() |> ExJsonSchema.Schema.resolve()}
    end

    # Sabotage: made the choice question's alternative an anyOf and
    # regenerated; the question carrying both forms validated and this test
    # went red.
    test "a choice question carries answer_options or answer_options_from, exactly one",
         %{schema: schema} do
      question = %{
        "type" => "choice_question",
        "key" => "plan",
        "label" => "Plan",
        "select" => "one"
      }

      options = [%{"value" => "monthly", "label" => "Monthly"}]

      assert valid?(schema, [Map.put(question, "answer_options", options)])
      assert valid?(schema, [Map.put(question, "answer_options_from", "context.plans")])
      refute valid?(schema, [question])

      refute valid?(schema, [
               question
               |> Map.put("answer_options", options)
               |> Map.put("answer_options_from", "context.plans")
             ])
    end

    # Sabotage: emptied the refused fields of a secret question and
    # regenerated; a secret question carrying a default validated and this
    # test went red.
    test "a secret question carries no default and no prefill", %{schema: schema} do
      secret = %{"type" => "secret_question", "key" => "card_pin", "label" => "PIN"}

      assert valid?(schema, [secret])
      refute valid?(schema, [Map.put(secret, "default", "1234")])
      refute valid?(schema, [Map.put(secret, "prefill", "context.pin")])
    end

    # Sabotage: dropped the code pattern and the message minLength from the
    # check definition and regenerated; the malformed checks validated and
    # this test went red.
    test "a check carries a condition, an author's code and a message, and nothing else",
         %{schema: schema} do
      check = %{
        "condition" => "responses.age >= 18",
        "code" => "check.adult",
        "message" => "Adults only."
      }

      question = %{"type" => "text_question", "key" => "age", "label" => "Age"}
      with_check = &valid?(schema, [Map.put(question, "checks", [&1])])

      assert with_check.(check)
      refute with_check.(%{check | "code" => "adult"})
      refute with_check.(%{check | "message" => ""})
      refute with_check.(Map.put(check, "severity", "high"))
      refute with_check.(Map.delete(check, "condition"))

      refute valid?(schema, [
               %{"type" => "text", "key" => "note", "text" => "x", "checks" => [check]}
             ])
    end
  end

  describe "the transport schema" do
    # Sabotage: added an enum to the transport schema's element type; this
    # test went red.
    test "keeps type an open string" do
      element = Corpus.read(@transport_path)["definitions"]["element"]
      assert element["properties"]["type"]["type"] == "string"
      refute Map.has_key?(element["properties"]["type"], "enum")
    end
  end

  describe "agreement with validate/1 over the corpus documents" do
    setup do
      %{schema: @schema_path |> Corpus.read() |> ExJsonSchema.Schema.resolve()}
    end

    # Sabotage: removed "accessible_label" from the fields every element
    # shares; the corpus documents carrying it failed the schema and this
    # test went red.
    test "every document validate/1 accepts validates, once the fields it drops are dropped",
         %{schema: schema} do
      accepted = for {name, doc} <- documents(), match?({:ok, _}, verdict(doc)), do: {name, doc}
      refute accepted == []

      failing =
        for {name, doc} <- accepted,
            {:error, errors} <- [ExJsonSchema.Validator.validate(schema, read_fields(doc))],
            do: {name, errors}

      assert failing == []
    end

    # Sabotage: removed "additionalProperties" => false from each type's
    # branch; the documents carrying a field their type does not name
    # validated and this test went red.
    test "an accepted document carrying a field admit/1 drops is refused, and only such a one",
         %{schema: schema} do
      {dropping, exact} =
        documents()
        |> Enum.filter(fn {_name, doc} -> match?({:ok, _}, verdict(doc)) end)
        |> Enum.split_with(fn {_name, doc} -> read_fields(doc) != doc end)

      refute dropping == []

      assert for({name, doc} <- dropping, ExJsonSchema.Validator.valid?(schema, doc), do: name) ==
               []

      assert for({name, doc} <- exact, not ExJsonSchema.Validator.valid?(schema, doc), do: name) ==
               []
    end

    # Sabotage: removed "additionalProperties" => false from each type's
    # branch; a corpus value admit/1 refuses validated and this test went
    # red.
    test "every value admit/1 says is not a document is refused by the schema", %{schema: schema} do
      not_documents =
        for {name, doc} <- documents(), verdict(doc) == :not_a_document, do: {name, doc}

      refute not_documents == []

      passing =
        for {name, doc} <- not_documents, ExJsonSchema.Validator.valid?(schema, doc), do: name

      assert passing == []
    end

    # Sabotage: dropped the "required" of each type's branch; the
    # missing-field documents validated and this test went red.
    test "every document refused only for a structural rule is refused by the schema",
         %{schema: schema} do
      structural =
        for {name, doc} <- documents(),
            {:error, findings} <- [verdict(doc)],
            Enum.all?(findings, &(&1.code in @structural_codes)),
            do: {name, doc}

      refute structural == []

      passing =
        for {name, doc} <- structural, ExJsonSchema.Validator.valid?(schema, doc), do: name

      assert passing == []
    end
  end

  # A decoded document with every field admit/1 carries nowhere removed: on
  # the envelope, a screen, an element, an option and a check, the fields it
  # reads and no other, written independently of the module under test.
  defp read_fields(doc) do
    own = if doc["schema_version"] == 2, do: "elements", else: "nodes"

    doc
    |> Map.take(~w(id kind metadata schema_version screens))
    |> Map.update!("screens", fn screens -> Enum.map(screens, &read_screen(&1, own)) end)
  end

  defp read_screen(screen, own) do
    screen
    |> Map.take(["key", "title", own])
    |> Map.update!(own, fn elements -> Enum.map(elements, &read_element(&1, own)) end)
  end

  defp read_element(element, own) do
    {:ok, module} = Registry.fetch(element["type"])
    %{required: required, optional: optional} = module.fields()

    names =
      ~w(type key condition checks accessible_label accessible_description) ++
        Enum.map(required ++ optional, &if(&1 == :elements, do: own, else: Atom.to_string(&1)))

    element
    |> Map.take(names)
    |> update_present(own, fn children -> Enum.map(children, &read_element(&1, own)) end)
    |> update_present("answer_options", fn options ->
      Enum.map(options, &Map.take(&1, ~w(value label description)))
    end)
    |> update_present("checks", fn checks ->
      Enum.map(checks, &Map.take(&1, ~w(condition code message)))
    end)
  end

  defp update_present(map, key, fun) do
    if Map.has_key?(map, key), do: Map.update!(map, key, fun), else: map
  end

  defp valid?(schema, elements) do
    doc = %{"schema_version" => 2, "screens" => [%{"key" => "signup", "elements" => elements}]}
    ExJsonSchema.Validator.valid?(schema, doc)
  end

  defp verdict(doc) do
    case Document.admit(doc) do
      nil -> :not_a_document
      admitted -> Document.validate(admitted)
    end
  end

  defp documents do
    for path <- @document_files,
        test_case <- Corpus.cases(path),
        Map.has_key?(test_case["input"], "document"),
        do: {"#{path}: #{test_case["name"]}", test_case["input"]["document"]}
  end

  defp spelling(:elements, "1"), do: "nodes"
  defp spelling(field, _version), do: Atom.to_string(field)

  defp refused("secret_question"), do: [:default, :prefill]
  defp refused(_type), do: []
end
