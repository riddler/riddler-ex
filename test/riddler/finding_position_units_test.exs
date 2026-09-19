defmodule Riddler.FindingPositionUnitsTest do
  @moduledoc """
  What a `Riddler.Finding` column counts, site by site.

  The column is the unit of whichever parser located the refusal, and this
  package converts neither: the template parser counts bytes, and the
  condition compiler and the evaluator count characters. Every case below puts
  two-byte characters before the defect - two where the template parser
  locates it, one where the condition compiler or the evaluator does - so the
  byte column and the character column to the same place differ by that
  count, and asserts the unit its site gives. The first test enumerates the
  `Riddler.Finding` literals in `lib/` that carry `:position`, so such a
  literal added without a unit named here turns this file red; a position set
  by a struct update or a map write is not a literal and is not read.
  """

  use ExUnit.Case, async: true

  alias Riddler.Finding
  alias Riddler.Screens
  alias Riddler.Screens.Document
  alias Riddler.Template

  # Two two-byte characters, the Portuguese greeting's `á` and the name's `ë`.
  @greeting "Olá, Zoë! "

  # Every place in `lib/` that builds a `Riddler.Finding` carrying `:position`,
  # as the file and the function it is built in, with the unit its column
  # counts. `Riddler.Template.finding/1` appears twice because both of its
  # clauses set the field.
  @sites %{
    {"lib/riddler/template.ex", :finding, 1} => :bytes,
    {"lib/riddler/template.ex", :finding, 2} => :bytes,
    {"lib/riddler/screens/document.ex", :refusals, 1} => :bytes,
    {"lib/riddler/screens/document.ex", :invalid_condition, 1} => :characters,
    {"lib/riddler/screens/validation.ex", :undecidable_finding, 1} => :characters
  }

  # The column each unit gives for a defect standing right after `prefix`.
  defp column(prefix, :bytes), do: byte_size(prefix) + 1
  defp column(prefix, :characters), do: String.length(prefix) + 1

  # A case is only discriminating if the two units disagree on it.
  defp discriminating!(prefix) do
    assert column(prefix, :bytes) != column(prefix, :characters)
  end

  defp template_refusals(source) do
    assert {:error, findings} = Template.compile(source)
    findings
  end

  defp document_findings(node) do
    raw = %{
      "schema_version" => 1,
      "id" => "edoc_signup_screens",
      "screens" => [%{"key" => "account", "title" => "Create your account", "nodes" => [node]}]
    }

    assert {:error, findings} = raw |> Document.admit() |> Document.validate()
    findings
  end

  defp undecidable(condition, root) do
    document =
      Document.admit(%{
        "schema_version" => 1,
        "id" => "edoc_signup_screens",
        "screens" => [
          %{
            "key" => "account",
            "title" => "Create your account",
            "nodes" => [
              %{"type" => "text_question", "key" => "first_name", "label" => "First name"},
              %{
                "type" => "text",
                "key" => "account_greeting",
                "condition" => condition,
                "text" => "Welcome back"
              }
            ]
          }
        ]
      })

    assert {:error, [%Finding{code: "response.undecidable"} = finding]} =
             Screens.validate_screen(document, "account", root)

    finding
  end

  # -- the enumeration -------------------------------------------------------

  # Every `%Finding{...}` or `%Riddler.Finding{...}` literal in `lib/` whose
  # keys include `:position`, keyed by file, function and a one-based count
  # within that function, read out of the source's syntax tree rather than
  # matched as text.
  defp position_sites do
    for path <- Path.wildcard("lib/**/*.ex"),
        {name, literals} <- defs(path),
        {_literal, index} <- Enum.with_index(literals, 1),
        into: MapSet.new(),
        do: {path, name, index}
  end

  defp defs(path) do
    {_ast, defs} =
      path
      |> File.read!()
      |> Code.string_to_quoted!()
      |> Macro.prewalk([], fn
        {kind, _meta, [head | _body]} = node, acc when kind in [:def, :defp] ->
          {nil, [{def_name(head), position_literals(node)} | acc]}

        node, acc ->
          {node, acc}
      end)

    defs
    |> Enum.reverse()
    |> Enum.group_by(fn {name, _literals} -> name end, fn {_name, literals} -> literals end)
    |> Enum.map(fn {name, literals} -> {name, List.flatten(literals)} end)
  end

  defp def_name({:when, _meta, [call | _guards]}), do: def_name(call)
  defp def_name({name, _meta, _args}), do: name

  defp position_literals(node) do
    {_ast, literals} =
      Macro.prewalk(node, [], fn
        {:%, _meta, [{:__aliases__, _, aliases}, {:%{}, _, pairs}]} = literal, acc ->
          if List.last(aliases) == :Finding and Keyword.has_key?(pairs, :position),
            do: {literal, [literal | acc]},
            else: {literal, acc}

        other, acc ->
          {other, acc}
      end)

    literals
  end

  # Mutation: add a `position:` key to any other `%Finding{}` literal in
  # `lib/` - the `document.missing_field` finding in
  # `lib/riddler/screens/document.ex`, say - and the set read out of the
  # source gains a site this file names no unit for, and this reddens.
  test "every site in lib/ that sets a position is named here with its unit" do
    assert position_sites() == @sites |> Map.keys() |> MapSet.new()
  end

  # -- bytes: the template parser located it ---------------------------------

  describe "a column the template parser gave counts bytes" do
    # Mutation: have the parse-failure clause of `Riddler.Template.finding/1`
    # convert its column to characters, the `String.length/1` of the source's
    # line up to the byte column plus one, and this reddens.
    test "on a parse failure" do
      source = @greeting <> "{{ responses.first_name"
      discriminating!(@greeting)

      assert [%Finding{code: "template.parse_error", position: position}] =
               template_refusals(source)

      assert position == %{line: 1, column: column(@greeting, :bytes)}
    end

    # Mutation: as above, on the subset clause of `Riddler.Template.finding/1`,
    # and this reddens, as does the re-wrap test below, which carries what
    # this clause builds. The four routes a subset refusal's place arrives by
    # are each put to it: the parser refusing an unknown tag, the allowlist
    # walk reading a filter's location and a tag's, and the probe that
    # locates a liquid tag.
    test "on a construct outside the subset, by every route its place arrives" do
      discriminating!(@greeting)

      for {construct, field} <- [
            {"{% include 'footer' %}", "include"},
            {"{{ responses.first_name | strip_html }}", "strip_html"},
            {"{% cycle 'a', 'b' %}", "cycle"},
            {"{% liquid assign x = 1 %}", "liquid"}
          ] do
        prefix =
          if field == "strip_html",
            do: @greeting <> "{{ responses.first_name | ",
            else: @greeting

        assert [%Finding{field: ^field, position: position}] =
                 template_refusals(@greeting <> construct)

        assert position == %{line: 1, column: column(prefix, :bytes)},
               "#{field}: #{inspect(position)}"
      end
    end

    # Mutation: have the re-wrap in `Riddler.Screens.Document.refusals/3` carry
    # the wrapped position with its column converted to characters, and this
    # reddens.
    test "on a template a document node writes, carried through the re-wrap" do
      discriminating!(@greeting)

      assert [%Finding{code: "document.invalid_template", position: position}] =
               document_findings(%{
                 "type" => "heading",
                 "key" => "greeting",
                 "level" => 1,
                 "text" => @greeting <> "{% include 'footer' %}"
               })

      assert position == %{line: 1, column: column(@greeting, :bytes)}
    end
  end

  # -- characters: the condition compiler or the evaluator located it --------

  describe "a column the condition compiler or the evaluator gave counts characters" do
    @refused_condition "responses.first_name == 'Zoë' and responses.last_name =="

    # Mutation: have `compile_condition/2` in `Riddler.Screens.Document`
    # convert the column `error_position/1` reads to bytes, the `byte_size/1`
    # of the condition's line up to the character column plus one, and this
    # reddens.
    test "on a condition the document check refuses" do
      discriminating!(@refused_condition)

      assert [%Finding{code: "document.invalid_condition", position: position}] =
               document_findings(%{
                 "type" => "text",
                 "key" => "account_greeting",
                 "condition" => @refused_condition,
                 "text" => "Welcome back"
               })

      assert position == %{line: 1, column: column(@refused_condition, :characters)}
    end

    # Mutation: have `undecidable_finding/2` in `Riddler.Screens.Validation`
    # convert the column `cause/2` answers to bytes, as above, and this
    # reddens, as does the evaluator case below.
    test "on a condition the response check finds the compiler refused" do
      discriminating!(@refused_condition)

      finding = undecidable(@refused_condition, %{"responses" => %{"first_name" => "Zoë"}})

      assert finding.position == %{line: 1, column: column(@refused_condition, :characters)}
    end

    # Mutation: the same one as for the compiler's place above, and this
    # reddens.
    test "on a condition the root leaves undecided, where the evaluator gave the place" do
      prefix = "responses.first_name == 'Zoë' and "
      discriminating!(prefix)

      finding =
        undecidable(prefix <> "is_business", %{"responses" => %{"first_name" => "Zoë"}})

      assert finding.position == %{line: 1, column: column(prefix, :characters)}
    end
  end
end
