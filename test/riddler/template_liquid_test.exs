defmodule Riddler.TemplateLiquidTest do
  @moduledoc """
  Where a liquid tag begins is the parser's to say.

  `liquid` is excluded from the subset as an alternate spelling for tags the
  subset already admits. The parse tree erases the tag itself - the tags inside
  it are ordinary nodes the allowlist walk still asks about - so a liquid tag
  holding only admitted tags is refused on the spelling alone, and whether the
  spelling is there is a question about how the parser read the source.

  A template the check misreads is a conformance gap, not a construct escaping
  the subset: every probe below writes an ADMITTED tag, `assign`, inside the
  liquid body, because a refused tag there is caught by the allowlist walk
  whatever this check decides, and would hide the gap rather than show it. What
  a gap admits is an admitted construct in a spelling a second runtime need not
  implement.
  """

  use ExUnit.Case, async: true

  alias Riddler.Template

  @body ~S|assign greeting = "Hello"|
  @liquid ~s({% liquid #{@body} %})
  @read_back "[{{ greeting }}]"

  defp liquid_fields(source) do
    case Template.compile(source) do
      {:ok, _compiled} -> []
      {:error, findings} -> for %{field: "liquid"} = finding <- findings, do: finding
    end
  end

  describe "the spellings a source pattern misread, each refused" do
    # Each template below compiled at 0.2.0, with its liquid assign executed:
    # a marker the pattern read as a verbatim block's opener paired with a
    # later real closer, and the liquid tag between them was masked.
    #
    # Sabotage, run for every test in this block: liquid_refusals/1 restored
    # to the source pattern it replaced (literal masking, then the verbatim
    # block pattern, then the opener pattern) - each template compiles and
    # each test goes red.

    test "a raw marker inside a comment whose opener carries trailing text" do
      source =
        ~S|{% comment xyz %}{% raw %}{% endcomment %}| <> @liquid <> "{% raw %}{% endraw %}"

      assert [%{code: "template.tag_not_allowed"}] = liquid_fields(source)
    end

    test "a raw marker in the string a comment opener discards" do
      source = ~S|{% comment "{% raw %}" %}{% endcomment %}| <> @liquid <> "{% raw %}{% endraw %}"
      assert [_liquid] = liquid_fields(source)
    end

    test "a raw marker in the string an endcomment discards" do
      source = ~S|{% comment %}{% endcomment "{% raw %}" %}| <> @liquid <> "{% raw %}{% endraw %}"
      assert [_liquid] = liquid_fields(source)
    end

    test "a raw marker in the string an endif discards" do
      source = ~S|{% if true %}{% endif "{% raw %}" %}| <> @liquid <> "{% raw %}{% endraw %}"
      assert [_liquid] = liquid_fields(source)
    end

    test "a raw marker in the string an else discards" do
      source =
        ~S|{% if true %}{% else "{% raw %}" %}{% endif %}| <> @liquid <> "{% raw %}{% endraw %}"

      assert [_liquid] = liquid_fields(source)
    end

    test "a raw marker in the string an endfor discards" do
      source =
        ~S|{% for i in (1..1) %}{% endfor "{% raw %}" %}| <> @liquid <> "{% raw %}{% endraw %}"

      assert [_liquid] = liquid_fields(source)
    end

    test "a raw closer carrying a trailing word" do
      source = ~S|{% raw %}x{% endraw xyz %}| <> @liquid <> "{% raw %}{% endraw %}"
      assert [_liquid] = liquid_fields(source)
    end

    test "a raw closer carrying a trailing string" do
      source = ~S|{% raw %}x{% endraw "q" %}| <> @liquid <> "{% raw %}{% endraw %}"
      assert [_liquid] = liquid_fields(source)
    end

    test "a comment closer carrying a trailing word" do
      source =
        ~S|{% comment %}x{% endcomment xyz %}| <> @liquid <> "{% comment %}{% endcomment %}"

      assert [_liquid] = liquid_fields(source)
    end
  end

  describe "the spellings a source pattern misread, each text" do
    # Each template below was refused at 0.2.0 on a liquid tag the parser
    # reads as the text of a verbatim block: the pattern did not take the
    # opener or the closer for one, and read the characters inside as a tag.
    #
    # Sabotage, run for every test in this block: liquid_refusals/1 restored
    # to the source pattern it replaced - each template is refused on
    # `liquid` and each test goes red.

    test "inside a raw block whose closer carries a trailing word" do
      assert {:ok, compiled} = Template.compile("{% raw %}" <> @liquid <> "{% endraw xyz %}")
      assert {:ok, @liquid, []} = Template.render(compiled, %{}, :strict)
    end

    test "inside a comment block whose opener carries trailing text" do
      assert {:ok, compiled} =
               Template.compile("{% comment xyz %}" <> @liquid <> "{% endcomment %}")

      assert {:ok, "", []} = Template.render(compiled, %{}, :strict)
    end

    test "inside a comment block whose closer carries trailing text" do
      assert {:ok, compiled} =
               Template.compile("{% comment %}" <> @liquid <> "{% endcomment xyz %}")

      assert {:ok, "", []} = Template.render(compiled, %{}, :strict)
    end
  end

  describe "what the parser is asked, and how its answer is read" do
    # Sabotage: probe/1 made to answer only for a refusal that IS the probe
    # name's rather than one ending with it - the if tag words the refusal as
    # its own, the tag is not found, and this test goes red.
    test "a liquid tag inside a block tag's body is refused" do
      source = "{% if true %}" <> @liquid <> "{% endif %}"
      assert [%{position: %{line: 1, column: 14}}] = liquid_fields(source)
    end

    # Sabotage: the rescue deleted from probe/1 - compile/1 raises
    # CaseClauseError out of the parser and this test goes red.
    test "the characters of a liquid tag in an inline comment body are not a tag" do
      assert {:error, [%{field: "#"}]} = Template.compile("{% # a\n # liquid\n %}")
    end

    # Sabotage: probe/1 made to report where the characters `liquid` stand
    # (line 2, column 6) rather than the place the parser located - red.
    test "the refusal is placed where the liquid tag begins" do
      source = ~s({% if true %}{% endif "{% raw %}" %}\n  #{@liquid}{% raw %}{% endraw %})
      assert [%{position: %{line: 2, column: 3}}] = liquid_fields(source)
    end
  end

  describe "generated agreement with the parser" do
    # The oracle is the parser and the engine underneath `Riddler.Template`,
    # asked directly: a generated template reads its assign back as
    # `[Hello]` exactly when the parser read the liquid tag, because every
    # carrier below is a complete construct on a branch that renders, so a
    # liquid tag the parser read is a liquid tag that ran.
    @tails [
      "",
      " xyz",
      ~S| "q"|,
      ~S| "{% raw %}"|,
      ~S| '{% comment %}'|,
      ~S| "{% endraw %}"|,
      ~S| '{% endcomment %}'|,
      ~S| "{% liquid %}"|,
      ~S| "{% endraw"|,
      ~S| 'endcomment %}'|
    ]

    @markers ["{% raw %}", "{% endraw %}", "{% comment %}", "{% endcomment %}", "{% liquid %}"]

    @spellings [
      ~s({% liquid #{@body} %}),
      ~s({%- liquid #{@body} -%}),
      ~s({%liquid #{@body}%}),
      ~s({% liquid\n  #{@body}\n%}),
      ~s({% if true %}{% liquid #{@body} %}{% endif %})
    ]

    @closers [
      "",
      "{% raw %}{% endraw %}",
      "{% comment %}{% endcomment %}",
      "{% raw %}{% endraw xyz %}",
      ~S|{% comment %}{% endcomment "q" %}|,
      ~S|{{ "{% endraw %}" }}|,
      ~S|{{ "{% endcomment %}" }}|
    ]

    defp carriers do
      tailed =
        for tail <- @tails,
            carrier <- [
              "{% comment#{tail} %}{% raw %}{% endcomment %}",
              "{% comment#{tail} %}{% endcomment %}",
              "{% comment %}{% endcomment#{tail} %}",
              "{% raw %}{% endraw#{tail} %}",
              "{% if true %}{% endif#{tail} %}",
              "{% if true %}{% else#{tail} %}{% endif %}",
              "{% unless false %}{% endunless#{tail} %}",
              "{% for i in (1..1) %}{% endfor#{tail} %}",
              "{% for i in (1..1) %}{% else#{tail} %}{% endfor %}",
              "{% case 1 %}{% when 1 %}{% endcase#{tail} %}",
              "{% case 1 %}{% when 2 %}{% else#{tail} %}{% endcase %}",
              "{% capture c %}{% endcapture#{tail} %}"
            ],
            do: carrier

      printed =
        for marker <- @markers,
            carrier <- [~s({{ "#{marker}" }}), ~s({{ c["#{marker}"] }})],
            do: carrier

      ["" | tailed ++ printed]
    end

    # A liquid tag the parser reads after a carrier, then a closer that could
    # pair with a marker the carrier holds.
    defp outside_templates do
      for carrier <- carriers(), spelling <- @spellings, closer <- @closers do
        carrier <> spelling <> closer <> @read_back
      end
    end

    # A liquid tag written inside a verbatim block whose opener or closer
    # carries text the parser discards - the parser reads it as text.
    defp inside_templates do
      for tail <- @tails,
          {opener, closer} <- [
            {"{% raw %}", "{% endraw#{tail} %}"},
            {"{% comment#{tail} %}", "{% endcomment %}"},
            {"{% comment %}", "{% endcomment#{tail} %}"}
          ],
          spelling <- @spellings do
        opener <> spelling <> closer <> @read_back
      end
    end

    defp parser_reads_liquid(source) do
      with {:ok, parsed} <- Solid.parse(source),
           {:ok, rendered, _tolerated} <- Solid.render(parsed, %{}) do
        {:parsed, IO.iodata_to_binary(rendered) =~ "[Hello]"}
      else
        _refused -> :unparsed
      end
    end

    defp disagreement(source) do
      case {parser_reads_liquid(source), Template.compile(source)} do
        {{:parsed, true}, {:error, findings}} ->
          if Enum.any?(findings, &(&1.field == "liquid")), do: nil, else: {:missed, source}

        {{:parsed, true}, {:ok, _compiled}} ->
          {:missed, source}

        {{:parsed, false}, {:ok, _compiled}} ->
          nil

        {{:parsed, false}, {:error, findings}} ->
          {:invented, source, Enum.map(findings, &{&1.code, &1.field})}

        {:unparsed, {:error, _findings}} ->
          nil

        {:unparsed, {:ok, _compiled}} ->
          {:admitted_unparsed, source}
      end
    end

    defp tally(templates) do
      Enum.frequencies_by(templates, fn source ->
        case parser_reads_liquid(source) do
          {:parsed, read?} -> read?
          :unparsed -> :unparsed
        end
      end)
    end

    # Sabotage: liquid_refusals/1 restored to the source pattern it replaced -
    # this test went red with the missed templates listed.
    test "every liquid tag the parser reads is refused" do
      templates = outside_templates()
      assert %{true: read} = tally(templates)
      assert read > 1_000

      assert templates |> Enum.map(&disagreement/1) |> Enum.reject(&is_nil/1) == []
    end

    # Sabotage: probe/1 made to answer for a probe-name refusal anywhere in
    # the parser's list rather than only the first - this test went red,
    # every template here then refused on a liquid tag the parser read as
    # text.
    test "no liquid tag is refused where the parser reads none" do
      templates = inside_templates()
      assert %{false: text} = tally(templates)
      assert text > 50

      assert templates |> Enum.map(&disagreement/1) |> Enum.reject(&is_nil/1) == []
    end
  end
end
