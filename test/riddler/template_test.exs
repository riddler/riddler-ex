defmodule Riddler.TemplateTest do
  use ExUnit.Case, async: true

  alias Riddler.Template

  doctest Riddler.Template

  # The signup wizard is the domain throughout: a visitor gives a name and an
  # email on one screen and is read back to on the next.
  @assigns %{
    "responses" => %{
      "first_name" => "Ada",
      "email" => "ada@example.com",
      "plan" => "pro",
      "invitees" => ["bo", "cy"]
    },
    "context" => %{"tenant" => "acme"}
  }

  defp render!(source, assigns \\ @assigns, mode \\ :strict) do
    assert {:ok, compiled} = Template.compile(source)
    Template.render(compiled, assigns, mode)
  end

  defp refusal!(source) do
    assert {:error, findings} = Template.compile(source)
    findings
  end

  describe "compile/1 accepts the allowlist" do
    # Mutation: drop "if" from @allowed_tags - compile/1 refuses the tag and
    # the match on {:ok, compiled} fails.
    test "if, elsif and else are admitted and render" do
      assert {:ok, "pro plan", []} =
               render!(
                 "{% if responses.plan == 'pro' %}pro plan{% elsif responses.plan %}other{% else %}none{% endif %}"
               )
    end

    # Mutation: drop "unless" from @allowed_tags - the tag is refused at
    # compile and the render never happens.
    test "unless is admitted and renders" do
      assert {:ok, "paid", []} =
               render!("{% unless responses.plan == 'free' %}paid{% endunless %}")
    end

    # Mutation: drop "case" from @allowed_tags - the tag is refused at compile.
    test "case and when are admitted and render" do
      assert {:ok, "monthly", []} =
               render!(
                 "{% case responses.plan %}{% when 'pro' %}monthly{% else %}never{% endcase %}"
               )
    end

    # Mutation: drop "for" from @allowed_tags - the tag is refused at compile.
    test "for is admitted and renders" do
      assert {:ok, "bocy", []} =
               render!("{% for name in responses.invitees %}{{ name }}{% endfor %}")
    end

    # Mutation: drop "for" from @allowed_tags - limit and offset are arguments
    # of the same tag, so refusing it refuses these too.
    test "for admits its limit and offset arguments" do
      assert {:ok, "cy", []} =
               render!(
                 "{% for name in responses.invitees limit: 1 offset: 1 %}{{ name }}{% endfor %}"
               )
    end

    # Mutation: drop "assign" from @allowed_tags - the tag is refused at compile.
    test "assign is admitted and renders" do
      assert {:ok, "Ada", []} = render!("{% assign who = responses.first_name %}{{ who }}")
    end

    # Mutation: drop "capture" from @allowed_tags - the tag is refused at compile.
    test "capture is admitted and renders" do
      assert {:ok, "Hi Ada", []} =
               render!(
                 "{% capture greeting %}Hi {{ responses.first_name }}{% endcapture %}{{ greeting }}"
               )
    end

    # Mutation: drop "comment" from @allowed_tags - the tag is refused at compile.
    test "comment is admitted and renders nothing" do
      assert {:ok, "", []} = render!("{% comment %}for the author only{% endcomment %}")
    end

    # Mutation: drop "raw" from @allowed_tags - the tag is refused at compile.
    test "raw is admitted and renders its contents verbatim" do
      assert {:ok, "{{ responses.first_name }}", []} =
               render!("{% raw %}{{ responses.first_name }}{% endraw %}")
    end

    # Mutation: remove "default" from @allowed_filters - the filter is refused
    # and the compile fails.
    test "an output tag with a filter chain is admitted" do
      assert {:ok, "ADA", []} =
               render!("{{ responses.first_name | upcase | default: 'FRIEND' | truncate: 10 }}")
    end

    # Mutation: replace @allowed_filters with a shorter list - some admitted
    # name is then refused and the assertion of an empty finding list fails.
    # This test is the enumerating surface the record delegates the filter
    # list to: every name here is admitted and nothing else is.
    test "every admitted filter compiles" do
      admitted =
        ~w(append base64_decode base64_encode base64_url_safe_decode base64_url_safe_encode
           capitalize downcase lstrip prepend remove remove_first remove_last replace
           replace_first replace_last rstrip size slice split squish strip strip_newlines
           truncate truncatewords upcase url_decode url_encode
           abs at_least at_most ceil divided_by floor minus modulo plus round times
           compact concat first join last map reverse sort sort_natural sum uniq where
           date default)

      for name <- admitted do
        assert {:ok, _compiled} = Template.compile("{{ responses.first_name | #{name} }}"),
               "expected the filter #{name} to be admitted"
      end
    end
  end

  describe "compile/1 refuses everything outside the allowlist" do
    # Mutation: make refuse/2 return the accumulator unchanged for unknown
    # tags - include then compiles and the finding list is empty.
    test "include is refused, naming the construct" do
      assert [%Riddler.Finding{code: "template.tag_not_allowed", field: "include"} = finding] =
               refusal!("{% include 'footer' %}")

      assert finding.message =~ "include"
      assert finding.message =~ "line 1"
      assert finding.node_key == nil
    end

    # Mutation: add "render" to @allowed_tags - the tag compiles and no
    # finding is produced.
    test "render is refused" do
      assert [%Riddler.Finding{field: "render"}] = refusal!("{% render 'footer' %}")
    end

    # Mutation: add "increment" to @allowed_tags - the tag compiles.
    test "increment is refused" do
      assert [%Riddler.Finding{field: "increment"}] = refusal!("{% increment seen %}")
    end

    # Mutation: have construct/1 return "increment" for every CounterTag - the
    # decrement finding is then named increment and the match fails.
    test "decrement is refused" do
      assert [%Riddler.Finding{field: "decrement"}] = refusal!("{% decrement seen %}")
    end

    # Mutation: add "cycle" to @allowed_tags - the tag compiles.
    test "cycle is refused" do
      assert [%Riddler.Finding{field: "cycle"}] = refusal!("{% cycle 'a', 'b' %}")
    end

    # Mutation: add "tablerow" to @allowed_tags - the tag compiles.
    test "tablerow is refused" do
      assert [%Riddler.Finding{field: "tablerow"}] =
               refusal!("{% tablerow name in responses.invitees %}{{ name }}{% endtablerow %}")
    end

    # The allowlist only holds where the walk reaches, and the two bodies the
    # parse tree wraps in a tuple - an `if` tag's elsifs and a `case` tag's
    # branches - were unreachable, so a refused tag written in either one
    # compiled. These two pin the reach rather than the tag.
    #
    # Mutation: delete the is_tuple clause from reduce_nodes/3 - the elsif
    # body is never visited, compile/1 returns {:ok, compiled}, and refusal!
    # fails on its match.
    test "a refused tag inside an elsif body is refused" do
      assert [%Riddler.Finding{code: "template.tag_not_allowed", field: "cycle"} = finding] =
               refusal!(
                 "{% if responses.plan %}pro{% elsif responses.tier %}" <>
                   "{% cycle 'a', 'b' %}{% endif %}"
               )

      assert finding.message =~ "cycle"
      assert finding.message =~ "line 1"
    end

    # Mutation: delete the is_tuple clause from reduce_nodes/3 - the `when`
    # branch body is never visited and the template compiles.
    test "a refused tag inside a case branch body is refused" do
      assert [%Riddler.Finding{code: "template.tag_not_allowed", field: "cycle"} = finding] =
               refusal!(
                 ~S({% case responses.plan %}{% when "pro" %}) <>
                   "{% cycle 'a', 'b' %}{% endcase %}"
               )

      assert finding.message =~ "cycle"
      assert finding.message =~ "line 1"
    end

    # The reach the tuple clause restored is not tags only: a filter outside
    # the allowlist written in either tuple-wrapped body was unreachable in
    # the same way, and a `case` tag's else branch is `{:else, body}`, a
    # different tuple shape from a `when`'s `{values, body}`.
    #
    # Mutation: delete the is_tuple clause from reduce_nodes/3 - the elsif
    # body is never visited, the filter is never asked about, and compile/1
    # returns {:ok, compiled}.
    test "a refused filter inside an elsif body is refused" do
      assert [%Riddler.Finding{code: "template.filter_not_allowed", field: "escape"} = finding] =
               refusal!(
                 "{% if responses.plan %}pro{% elsif responses.tier %}" <>
                   "{{ responses.first_name | escape }}{% endif %}"
               )

      assert finding.message =~ "escape"
      assert finding.message =~ "line 1"
    end

    # Mutation: delete the is_tuple clause from reduce_nodes/3 - the
    # {:else, body} branch is never visited and the template compiles.
    test "a refused tag inside a case else branch body is refused" do
      assert [%Riddler.Finding{code: "template.tag_not_allowed", field: "cycle"} = finding] =
               refusal!(
                 ~S({% case responses.plan %}{% when "pro" %}pro{% else %}) <>
                   "{% cycle 'a', 'b' %}{% endcase %}"
               )

      assert finding.message =~ "cycle"
      assert finding.message =~ "line 1"
    end

    # Mutation: delete the liquid_refusals/1 call from compile/1 - the parse
    # tree carries no trace of the liquid tag, so the finding disappears.
    test "liquid is refused" do
      assert [%Riddler.Finding{field: "liquid"}] = refusal!("{% liquid\n  assign who = 1\n%}")
    end

    # Mutation: make probe/2 answer for the probe name refused anywhere in the
    # parser's list rather than only first - the parser's recovery reads it
    # as a tag, and the compile fails instead of succeeding.
    test "a liquid opener inside raw is text, not a construct" do
      assert {:ok, "{% liquid echo x %}", []} =
               render!("{% raw %}{% liquid echo x %}{% endraw %}")
    end

    # Mutation: make probe/2 answer for the probe name refused anywhere in the
    # parser's list rather than only first - the parser's recovery reads it
    # as a tag, and the compile fails instead of rendering nothing.
    test "a liquid opener inside comment is text, not a construct" do
      assert {:ok, "", []} =
               render!("{% comment %}{% liquid echo x %}{% endcomment %}")
    end

    # Mutation: make probe/2 answer for the probe name refused anywhere in the
    # parser's list rather than only first - the parser's recovery reads it
    # as a tag, and the compile fails instead of rendering the characters.
    test "a liquid opener inside an output tag's string literal is text" do
      assert {:ok, "{% liquid %}", []} = render!(~S({{ "{% liquid %}" }}))
    end

    # Mutation: make probe/2 answer for the probe name refused anywhere in the
    # parser's list rather than only first - the parser's recovery reads it
    # as a tag, and the compile fails instead of rendering.
    test "a liquid opener inside a filter argument's literal is text" do
      assert {:ok, "Ada{% liquid %}", []} =
               render!(~S({{ responses.first_name | append: "{% liquid %}" }}))
    end

    # Mutation: make probe/2 answer for the probe name refused anywhere in the
    # parser's list rather than only first - the parser's recovery reads it
    # as a tag, and the compile fails instead of rendering.
    test "a liquid opener inside a when branch's literal is text" do
      assert {:ok, "no", []} =
               render!(
                 ~S({% case responses.plan %}{% when "{% liquid %}" %}yes{% else %}no{% endcase %})
               )
    end

    # The exemption is the parser's, not the source's: these three pin that a
    # quote character in the source decides nothing the parser did not.
    #
    # Mutation: make liquid_refusals/1 blank every quoted span of the source
    # before probing - the quotes in this prose then swallow the opener and
    # the refusal disappears.
    test "quote characters in ordinary text do not exempt a liquid opener" do
      assert [%Riddler.Finding{field: "liquid"}] =
               refusal!(~S(He said "hello {% liquid %} world" and left))
    end

    # Mutation: make liquid_refusals/1 blank from the first quote character to
    # the end of the source before probing - the real opener after the
    # literal is blanked too and the refusal disappears.
    test "a real liquid block beside a literal holding the opener is refused" do
      assert [%Riddler.Finding{field: "liquid"}] =
               refusal!(~S({{ "{% liquid %}" }}{% liquid assign who = 1 %}))
    end

    # Mutation: the same blanking to the end of the source - what this case
    # adds is that a stray quote character inside a literal moves nothing;
    # the real opener past the literal stays refused.
    test "an apostrophe inside a double-quoted literal masks nothing beyond it" do
      assert [%Riddler.Finding{field: "liquid"}] =
               refusal!(~S({{ "it's fine" }}{% liquid assign who = 1 %}))
    end

    # Whether characters are a block's marker is the parser's answer too: a
    # template can print the characters of a block's opener and closer around
    # a real refused tag, and any reading of the source ahead of the parser
    # would take them for a block and blank the tag. A marker printed from a
    # literal is not a marker.
    #
    # Mutation: make liquid_refusals/1 blank what the previous release's
    # verbatim-block pattern matches before probing - the printed markers are
    # read as a real raw block, the tag between them is blanked, and
    # compile/1 answers {:ok, _}.
    test "raw markers printed from literals do not mask a real refused tag" do
      assert [%Riddler.Finding{code: "template.tag_not_allowed", field: "liquid"}] =
               refusal!(~S({{ "{% raw %}" }}{% liquid assign who = 1 %}{{ "{% endraw %}" }}))
    end

    # Mutation: the same blanking - the printed comment markers are read as a
    # real comment block and the tag between them is admitted.
    test "comment markers printed from literals do not mask a real refused tag" do
      assert [%Riddler.Finding{code: "template.tag_not_allowed", field: "liquid"}] =
               refusal!(
                 ~S({{ "{% comment %}" }}{% liquid assign who = 1 %}{{ "{% endcomment %}" }})
               )
    end

    # A bracket subscript is a string the template holds, exactly as a plain
    # literal is, but the parser reports it as its own node type, and a
    # reading of the source that knew literals and not subscripts took a
    # marker inside one for a real block marker. These are the positions a
    # subscript can be written in.
    #
    # Mutation: make liquid_refusals/1 blank what the previous release's
    # verbatim-block pattern matches before probing - the printed markers open
    # and close a raw block across the liquid tag, and compile/1 answers
    # {:ok, _}.
    test "raw markers in a bracket subscript do not mask a real refused tag" do
      assert [%Riddler.Finding{code: "template.tag_not_allowed", field: "liquid"}] =
               refusal!(
                 ~S({{ responses["{% raw %}"] }}{% liquid assign who = 1 %}) <>
                   ~S({{ responses["{% endraw %}"] }})
               )
    end

    # Mutation: the same blanking - a single-quoted subscript is the same node
    # and the comment markers in it blank the tag between them.
    test "comment markers in a bracket subscript do not mask a real refused tag" do
      assert [%Riddler.Finding{code: "template.tag_not_allowed", field: "liquid"}] =
               refusal!(
                 ~S({{ responses['{% comment %}'] }}{% liquid assign who = 1 %}) <>
                   ~S({{ responses['{% endcomment %}'] }})
               )
    end

    # Mutation: the same blanking - the markers in an assign's right-hand side
    # pair across the tag between the two, which is admitted.
    test "markers in a subscript on an assign do not mask a real refused tag" do
      assert [%Riddler.Finding{field: "liquid"}] =
               refusal!(
                 ~S({% assign a = responses["{% raw %}"] %}{% liquid assign who = 1 %}) <>
                   ~S({% assign b = responses["{% endraw %}"] %})
               )
    end

    # Mutation: the same blanking - the markers in an if condition pair across
    # the tag between the two, which is admitted.
    test "markers in a subscript in a condition do not mask a real refused tag" do
      assert [%Riddler.Finding{field: "liquid"}] =
               refusal!(
                 ~S({% if responses["{% raw %}"] %}{% endif %}{% liquid assign who = 1 %}) <>
                   ~S({% if responses["{% endraw %}"] %}{% endif %})
               )
    end

    # Mutation: the same blanking - the markers in a filter argument pair
    # across the tag between the two, which is admitted.
    test "markers in a subscript as a filter argument do not mask a refused tag" do
      assert [%Riddler.Finding{field: "liquid"}] =
               refusal!(
                 ~S({{ "x" | append: responses["{% raw %}"] }}{% liquid assign who = 1 %}) <>
                   ~S({{ "x" | append: responses["{% endraw %}"] }})
               )
    end

    # The other direction: a subscript holding a forbidden tag's characters is
    # text and renders, as the same characters in a plain literal do.
    #
    # Mutation: make probe/2 answer for the probe name refused anywhere in the
    # parser's list rather than only first - the parser's recovery reads it
    # as a tag, and the compile fails instead of rendering.
    test "a liquid opener inside a bracket subscript is text, not a construct" do
      assert {:ok, "yes", []} =
               render!(
                 ~S({{ responses["{% liquid %}"] }}),
                 %{"responses" => %{"{% liquid %}" => "yes"}},
                 :strict
               )
    end

    # Mutation: make liquid_refusals/1 blank from the first quote character to
    # the end of the source before probing - the real opener after the
    # subscript is blanked too and the refusal disappears.
    test "a real liquid block beside a subscript holding the opener is refused" do
      assert [%Riddler.Finding{field: "liquid"}] =
               refusal!(~S({{ responses["{% liquid %}"] }}{% liquid assign who = 1 %}))
    end

    # Mutation: add "echo" to @allowed_tags - the tag compiles.
    test "echo is refused" do
      assert [%Riddler.Finding{field: "echo"}] = refusal!("{% echo responses.first_name %}")
    end

    # Mutation: make refuse/2 return the accumulator unchanged for unknown
    # tags - a vendor construct then compiles.
    test "a vendor-specific construct is refused" do
      assert [%Riddler.Finding{field: "acme_widget"}] = refusal!("{% acme_widget id: 1 %}")
    end

    # Mutation: add "break" to @allowed_tags - the tag compiles.
    test "break is refused" do
      assert [%Riddler.Finding{field: "break"}] =
               refusal!("{% for name in responses.invitees %}{% break %}{% endfor %}")
    end

    # Mutation: add "continue" to @allowed_tags - the tag compiles.
    test "continue is refused" do
      assert [%Riddler.Finding{field: "continue"}] =
               refusal!("{% for name in responses.invitees %}{% continue %}{% endfor %}")
    end

    # Mutation: add "#" to @allowed_tags - the inline comment compiles.
    test "the inline comment tag is refused" do
      assert [%Riddler.Finding{field: "#"}] = refusal!("{% # an aside %}")
    end

    # Mutation: add "escape" to @allowed_filters - the filter compiles and no
    # finding is produced.
    test "escape is refused: this package does not escape" do
      assert [%Riddler.Finding{code: "template.filter_not_allowed", field: "escape"}] =
               refusal!("{{ responses.first_name | escape }}")
    end

    # Mutation: add "escape_once" to @allowed_filters - the filter compiles.
    test "escape_once is refused" do
      assert [%Riddler.Finding{field: "escape_once"}] =
               refusal!("{{ responses.first_name | escape_once }}")
    end

    # Mutation: add "newline_to_br" to @allowed_filters - the filter compiles.
    test "newline_to_br is refused: output is text, never markup" do
      assert [%Riddler.Finding{field: "newline_to_br"}] =
               refusal!("{{ responses.first_name | newline_to_br }}")
    end

    # Mutation: add "strip_html" to @allowed_filters - the filter compiles.
    test "strip_html is refused" do
      assert [%Riddler.Finding{field: "strip_html"}] =
               refusal!("{{ responses.first_name | strip_html }}")
    end

    # Mutation: make refuse/2 accept any filter name - an unknown filter then
    # compiles, which is what an allowlist exists to prevent.
    test "a filter the parser does not know is refused" do
      assert [%Riddler.Finding{field: "shout"}] = refusal!("{{ responses.first_name | shout }}")
    end

    # Mutation: have compile/1 return only the first refusal - the list is
    # then one finding long and the match on three fails.
    test "one finding per refused construct, in source order, not the first" do
      findings = refusal!("{% cycle 'a' %}{{ responses.email | escape }}{% render 'footer' %}")

      assert ["cycle", "escape", "render"] = Enum.map(findings, & &1.field)
    end

    # Mutation: map a parse error to {:ok, ...} - the compile then succeeds on
    # source that cannot be parsed.
    test "a parse error is a finding" do
      assert [%Riddler.Finding{code: "template.parse_error", field: nil} = finding] =
               refusal!("{{ responses.email |||}")

      assert finding.message =~ "could not be parsed"
    end

    # Mutation: restore the `meta[:line] - 1` arithmetic by calling
    # `Solid.parse/2` directly from compile/1 instead of parse/1 - the parser
    # raises building its own error message and the assert on {:error, _}
    # never runs.
    test "a template the parser refuses without a place is a finding, not a raise" do
      for source <- ["{% render %}", "{% assign e %}"] do
        assert [%Riddler.Finding{code: "template.parse_error", field: nil} = finding] =
                 refusal!(source)

        assert finding.position == nil
        assert finding.message =~ "could not be parsed"
      end
    end

    # Mutation: have span/1 interpolate the line and the column whatever they
    # are - a placeless refusal then reads "(line , column )", promising a
    # place and naming none.
    test "a refusal the parser did not locate names no place in its message" do
      assert [finding] = refusal!("{% render %}")

      refute finding.message =~ "line"
      refute finding.message =~ "column"
    end

    # Mutation: have unparsed_refusals/2 answer the parser's first report
    # undropped, or delete the uniq_by in to_findings/1 - the parser reports
    # the orphaned block terminator beside the refused tag, or the refused
    # tag is reported by the second reading's tree and again by the first
    # reading's report, and the list is then longer than the number of
    # constructs the author actually reached for. The corpus case "A refused
    # tag inside an if block is the one finding: the closing tag that ends the
    # block is not refused" states this source's answer for a second runtime;
    # the first mutation turns that case red as well as this test.
    test "a refused construct inside a block is reported once" do
      findings = refusal!("{% if responses.plan %}{% include 'footer' %}{% endif %}")

      assert ["include"] = findings |> Enum.map(& &1.field) |> Enum.uniq()
      assert Enum.count(findings, &(&1.field == "include")) == 1
    end

    # Mutation: have refuse/2 skip a Riddler.Template.UnknownTag node and
    # drop_derivative/1 always drop terminators - a stray terminator standing
    # alone then produces no finding at all.
    test "a block terminator standing alone is still refused" do
      assert [%Riddler.Finding{field: "endif"}] = refusal!("done {% endif %}")
    end

    # Mutation: have finding/1 pass `nil` where it passes the line and the
    # column - the refusal then carries no span for an editor to point at and
    # the match on the map fails.
    test "a refused construct carries its source position beside the message" do
      assert [%Riddler.Finding{position: %{line: 1, column: 4}} = finding] =
               refusal!("abc{% include 'footer' %}")

      assert finding.message =~ "(line 1, column 4)"
    end

    # Mutation: as above, on the parse-error clause alone. A parse error takes
    # its line and column from the parser's meta rather than from a loc, so
    # it is the one refusal whose position arrives by a second route.
    test "a parse error carries its source position too" do
      assert [%Riddler.Finding{position: %{line: 1, column: 23}}] =
               refusal!("{{ responses.email |||}")
    end

    # Mutation: drop the "(line ..., column ...)" from either message in
    # finding/1 now that the position has a field of its own - the sentence a
    # human reads stops saying where the refusal was and this match fails.
    # This one pins wording that must NOT change, so it is green before the
    # position field and green after; the mutation is what makes it earn its
    # place.
    test "the message still names the position in its own words" do
      assert [finding] = refusal!("{{ name | strip_html }}")

      assert finding.message ==
               "the filter \"strip_html\" is not in the template subset (line 1, column 11)"
    end
  end

  # One finding per refused construct, whatever route the parser takes to
  # refuse the source: a branch or closing keyword with no block of its own
  # open is refused as itself, beside every other refusal, and the closer of
  # a block the author opened is never refused. Each test pins the fields and
  # the positions, in source order.
  describe "compile/1 beside a stray or misplaced keyword" do
    defp located(source) do
      source |> refusal!() |> Enum.map(&{&1.field, &1.position.line, &1.position.column})
    end

    # Mutation: have unparsed_refusals/2 answer drop_derivative(reported)
    # alone - the render tag sits in a tree the parser throws away when it
    # meets the endif, and only the endif is reported.
    test "a stray closer beside a refused tag the parser reads is reported with it" do
      assert [{"render", 1, 1}, {"endif", 1, 22}] =
               located("{% render 'footer' %}{% endif %}")
    end

    # Mutation: as above - the endif is dropped as if a refusal had orphaned
    # it, and only the include is reported.
    test "a stray closer beside a refused tag the parser does not know is reported with it" do
      assert [{"include", 1, 1}, {"endif", 1, 23}] =
               located("{% include 'footer' %}{% endif %}")
    end

    # Mutation: as above - the endfor that closes the block the author opened
    # is reported beside the endif misplaced inside it.
    test "a closer misplaced inside a block is refused alone: the block's own closer is not" do
      assert [{"endif", 1, 37}] =
               located("{% for name in responses.invitees %}{% endif %}{% endfor %}")
    end

    # Mutation: as above - the case's own when and endcase are reported
    # beside the elsif misplaced inside it.
    test "a branch keyword misplaced inside a block is refused alone" do
      assert [{"elsif", 1, 42}] =
               located(
                 "{% case responses.plan %}{% when 'pro' %}" <>
                   "{% elsif responses.email %}{% endcase %}"
               )
    end

    # Mutation: as above - the escape filter sits in the thrown-away tree,
    # and the endif is reported with the endfor that closes its block.
    test "a misplaced closer and a refused filter in one block are both reported" do
      assert [{"endif", 1, 37}, {"escape", 1, 58}] =
               located(
                 "{% for name in responses.invitees %}{% endif %}" <>
                   "{{ name | escape }}{% endfor %}"
               )
    end

    # Mutation: as above - the render tag sits in the thrown-away tree, and
    # only the include is reported.
    test "a refused tag the parser does not know hides no refused tag it reads" do
      assert [{"include", 1, 1}, {"render", 1, 23}] =
               located("{% include 'footer' %}{% render 'header' %}")
    end

    # Mutation: have unparsed_refusals/2 call liquid_refusals/1 rather than
    # liquid_refusals/2 with the tags it read with - the probe meets the
    # include first, and the liquid tag goes unreported.
    test "a liquid tag after a tag the parser does not know is reported" do
      assert [{"include", 1, 1}, {"liquid", 1, 23}] =
               located("{% include 'footer' %}{% liquid assign who = 1 %}")
    end

    # The parser reads what follows a second else in an if and throws it
    # away, so the second reading's tree does not hold the include; it is
    # refused where the first reading met it.
    #
    # Mutation: delete `++ unknown_constructs(reported)` from
    # unparsed_refusals/2 - the include goes unreported and only the render
    # is.
    test "a tag the parser does not know is refused even where its block throws it away" do
      assert [{"render", 1, 1}, {"include", 1, 67}] =
               located(
                 "{% render 'header' %}{% if responses.plan %}a{% else %}b{% else %}" <>
                   "{% include 'footer' %}{% endif %}"
               )
    end

    # Mutation: make Riddler.Template.UnknownTag consume nothing after its
    # name - the string's characters are read as template text, and the endif
    # inside it is reported as a stray closer.
    test "a keyword's characters in a string a refused tag carries are not a keyword" do
      assert [{"include", 1, 1}] = located("{% include '{% endif %}' %}")
    end
  end

  # A tag token carrying text after its name that the parser reads and throws
  # away is refused, as text after the tag, at the place the tag begins:
  # the corpus states a refusal rather than one parser's leniency.
  describe "compile/1 on a tag token carrying text the parser throws away" do
    @trailing "template.trailing_text_not_allowed"

    defp trailing(source) do
      source
      |> refusal!()
      |> Enum.map(&{&1.code, &1.field, &1.position.line, &1.position.column})
    end

    defp engine_text(source) do
      with {:ok, parsed} <- Solid.parse(source),
           {:ok, text, _tolerated} <- Solid.render(parsed, @assigns) do
        IO.iodata_to_binary(text)
      else
        _refused -> :refused
      end
    end

    # Mutation: have trailing_text_refusals/2 answer [] - the endif's string
    # is thrown away unrefused, the template compiles, and this match fails.
    test "a string on an endif is refused as text after the tag, where the tag begins" do
      assert [{@trailing, "endif", 1, 27}] =
               trailing(~S({% if responses.plan %}Pro{% endif "plan" %}))
    end

    # Mutation: as above - every template below compiles.
    test "each token that takes no text is refused for the text it carries" do
      for {field, source} <- [
            {"else", "{% if responses.plan %}a{% else later %}b{% endif %}"},
            {"endunless", "{% unless responses.plan %}a{% endunless later %}"},
            {"endfor", "{% for name in responses.invitees %}a{% endfor later %}"},
            {"else", "{% for name in responses.invitees %}a{% else later %}b{% endfor %}"},
            {"endcapture", "{% capture line %}a{% endcapture later %}{{ line }}"},
            {"comment", "{% comment later %}a{% endcomment %}"},
            {"endcomment", "{% comment %}a{% endcomment later %}"},
            {"endraw", "{% raw %}a{% endraw later %}"}
          ] do
        assert [%Riddler.Finding{code: @trailing, field: ^field}] = refusal!(source)
      end
    end

    # Mutation: have carrying_text/2 take a token holding only its end, as
    # `[_end | _]`, for one carrying text - every closer is then refused, and
    # this template with it.
    test "a closing tag followed only by whitespace and a newline carries no text" do
      assert {:ok, "Pro", []} = render!("{% if responses.plan %}Pro{% endif\n  %}")
    end

    # Mutation: have kept?/3 answer true - the endif in the comment body is
    # refused, and the template with it.
    test "a token in a comment body is text: the parser throws the whole body away" do
      assert {:ok, "Welcome", []} =
               render!(~S({% comment %}{% endif "plan" %}{% endcomment %}Welcome))
    end

    # Mutation: have kept?/3 answer true - the endif's characters in the
    # string and in the raw body are refused as a token carrying text, and
    # neither compiles.
    test "text the parser keeps is not text it throws away" do
      assert {:ok, "{% endif plan %}", []} = render!(~S({{ "{% endif plan %}" }}))
      assert {:ok, "{% endif plan %}", []} = render!("{% raw %}{% endif plan %}{% endraw %}")
    end

    # Mutation: have trailing_text_refusals/2 skip no token the second
    # reading holds as a tag it does not know - the stray endif is refused
    # twice, as itself and for its string.
    test "a stray closer carrying text is refused once, as itself" do
      assert [{"template.tag_not_allowed", "endif", 1, 8}] =
               trailing(~S(Welcome{% endif "plan" %}))
    end

    # Mutation: have unparsed_refusals/2 answer `refusals` without the
    # trailing findings - the parser refuses the include, and the endif's
    # text goes unreported.
    test "text after a tag is refused beside a refusal the parser reads" do
      assert [{"template.tag_not_allowed", "include", 1, 1}, {@trailing, "endif", 1, 47}] =
               trailing("{% include 'footer' %}{% if responses.plan %}a{% endif later %}")
    end

    # Mutation: have place/2 answer line 1 whatever line the offset is on -
    # the endif is placed on line 1.
    test "a token that begins on a later line is placed on its own line" do
      assert [{@trailing, "endif", 3, 1}] =
               trailing("Hi\n{% if responses.plan %}Pro\n{% endif\n later %}")
    end

    # Mutation: hand place/2 the number of characters before the token
    # rather than the number of bytes - the column comes back two short.
    test "the column counts bytes, as the parser's own places do" do
      prefix = "Grüße "
      assert byte_size(prefix) == 8
      source = prefix <> "{% if responses.plan %}x{% endif later %}"
      assert [{@trailing, "endif", 1, 33}] = trailing(source)
    end

    # Mutation: have carrying_text/2 take the token's end from the line and
    # column the lexer reports rather than from what it leaves unread - the
    # lexer counts a newline in a string as a new line without a new column,
    # the output tag kept?/3 prints lands inside the token, and the else is
    # admitted.
    test "a string carrying a newline is text after the tag like any other" do
      for {field, source} <- [
            {"endif", "{% if responses.plan %}y{% endif 'a\nb' %}"},
            {"endif", "{% if responses.plan %}\n{% endif 'x\ny' %}"},
            {"endraw", "{% raw %}a{% endraw 'x\ny' %}"},
            {"comment", "{% comment 'a\nb' %}x{% endcomment %}"},
            {"else", "{% if responses.plan %}a{% else 'a\nb' %}b{% endif %}"}
          ] do
        assert [%Riddler.Finding{code: @trailing, field: ^field}] = refusal!(source)
      end
    end

    # Mutation: have kept?/3 answer true - the token in each region the
    # parser reads and throws away is refused for its text, and each
    # template, admitted before this rule, is refused.
    test "a token in a region the parser throws away is not refused for its text" do
      for source <- [
            "{% if responses.plan %}{% else %}{% else later %}{% endif %}",
            "{% if responses.plan %}{% else %}{% else %}{% endif later %}",
            "{% case responses.plan %}{% if a %}{% endif later %}{% when 1 %}{% endcase %}",
            "{% if a %}{% else %}{% elsif a %}{% endif %}{% if b %}y{% endif %}"
          ] do
        assert {:ok, _compiled} = Template.compile(source)
      end
    end

    # Mutation: have probe_name/1 answer its stem whatever the source holds -
    # the author's own variable of that name is taken for the probe, and each
    # template is refused for text the parser does not keep.
    test "a variable the author names like the probe is not taken for it" do
      for source <- [
            "{{ riddler_kept_probe }}{% raw %}{% endif x %}{% endraw %}",
            "{{ riddler_kept_probe }}{{ '{% endif x %}' }}",
            "{{ riddler_kept_probe }}{% comment %}{% endif x %}{% endcomment %}",
            "{% if riddler_kept_probe %}{% else %}{% else x %}{% endif %}",
            "{% if a %}{% else %}{{ riddler_kept_probe }}{% else x %}{% endif %}"
          ] do
        assert {:ok, _compiled} = Template.compile(source)
      end
    end

    # Text the lexer cannot read leaves the template refused as it was, as
    # itself or as a parse failure; the rule reaches only text the parser
    # reads and throws away. No mutation in this change reaches these: the
    # answers are pinned as the record states them.
    test "text the parser cannot read after the name is refused as it was" do
      for source <- [
            "{% if a %}x{% endif é %}",
            "{% if a %}x{% endif 'x %}",
            "{% if a %}x{% endif ; %}",
            "{% capture c %}x{% endcapture ¿ %}"
          ] do
        assert [%Riddler.Finding{code: "template.tag_not_allowed"}] = refusal!(source)
      end

      assert [%Riddler.Finding{code: "template.parse_error"}] =
               refusal!("{% comment é %}x{% endcomment %}")
    end

    # Mutation: have unparsed_refusals/2 answer the trailing findings alone
    # where the second reading refuses nothing else, without the first
    # reading's answer - the keywords the first reading refused are lost.
    test "beside the first reading's keywords, those keywords are kept" do
      assert [
               {"template.tag_not_allowed", "endif", 1, 13},
               {"template.tag_not_allowed", "when", 1, 24},
               {"template.tag_not_allowed", "endcase", 1, 36},
               {@trailing, "endif", 1, 59}
             ] =
               trailing("{% case a %}{% endif %}{% when 1 %}{% endcase %}{% if b %}{% endif x %}")

      assert [
               {"template.tag_not_allowed", "endif", 1, 13},
               {"template.tag_not_allowed", "endcase", 1, 26}
             ] = trailing("{% case a %}{% endif x %}{% endcase %}")
    end

    # Mutation: have first_reading/2 add the trailing findings beside a
    # parse failure - the endif of the first block is reported and the parse
    # failure is not alone.
    test "beside a parse failure, text after a tag is not reported" do
      assert [%Riddler.Finding{code: "template.parse_error"}] =
               refusal!(~S({% if a %}{% else %}{% else %}{% elsif a %}{% endif "{% raw %}" %}))

      assert [%Riddler.Finding{code: "template.parse_error"}] =
               refusal!(
                 "{% if b %}x{% endif later %}" <>
                   ~S({% if a %}{% else %}{% else %}{% elsif a %}{% endif "{% raw %}" %})
               )
    end

    # The oracle is the parser and the engine underneath `Riddler.Template`,
    # asked directly: a carrier whose tailed token the parser reads, and
    # renders exactly as it renders the same carrier untailed, threw the
    # tail away. Every such carrier is refused for that token's text, and
    # nothing else; every carrier the parser refuses outright carries no
    # finding of this kind.
    #
    # Sabotage: have trailing_text_refusals/2 answer [] - every carrier the
    # parser reads is then admitted, and this test lists them.
    test "generated agreement with the parser" do
      carriers = [
        {"endif", &"{% if responses.plan %}a{% endif#{&1} %}"},
        {"else", &"{% if responses.plan %}a{% else#{&1} %}b{% endif %}"},
        {"endunless", &"{% unless responses.plan %}a{% endunless#{&1} %}"},
        {"else", &"{% unless responses.plan %}a{% else#{&1} %}b{% endunless %}"},
        {"endfor", &"{% for name in responses.invitees %}{{ name }}{% endfor#{&1} %}"},
        {"else", &"{% for name in responses.invitees %}a{% else#{&1} %}b{% endfor %}"},
        {"endcapture", &"{% capture line %}a{% endcapture#{&1} %}{{ line }}"},
        {"comment", &"{% comment#{&1} %}a{% endcomment %}b"},
        {"endcomment", &"{% comment %}a{% endcomment#{&1} %}b"},
        {"endraw", &"{% raw %}a{% endraw#{&1} %}b"},
        {"endcase", &"{% case responses.plan %}{% when 'pro' %}a{% endcase#{&1} %}"},
        {"else", &"{% case responses.plan %}{% when 'x' %}a{% else#{&1} %}b{% endcase %}"}
      ]

      tails = [
        " later",
        ~S| "plan"|,
        ~S| 'plan'|,
        " a.b | upcase",
        "\n  later",
        " 1",
        " (1..2)",
        " 'a\nb'",
        ~S| "x
"|
      ]

      outcomes =
        for {field, carrier} <- carriers, tail <- tails do
          source = carrier.(tail)

          thrown_away? =
            engine_text(source) == engine_text(carrier.("")) and engine_text(source) != :refused

          case {thrown_away?, Template.compile(source)} do
            {true, {:error, [%Riddler.Finding{code: @trailing, field: ^field}]}} ->
              :refused

            {false, {:error, findings}} ->
              if Enum.any?(findings, &(&1.code == @trailing)),
                do: {:invented, source},
                else: :kept

            other ->
              {:disagreed, source, other}
          end
        end

      assert Enum.reject(outcomes, &(&1 in [:refused, :kept])) == []
      assert %{refused: refused, kept: kept} = Enum.frequencies(outcomes)
      assert refused > 50
      assert kept > 5
    end
  end

  describe "render/3 modes" do
    # Mutation: return [] instead of the missing list in lenient mode - the
    # assertion on the path fails.
    test "lenient renders a missing variable as empty and returns its path" do
      assert {:ok, "Hi !", ["responses.nickname"]} =
               render!("Hi {{ responses.nickname }}!", @assigns, :lenient)
    end

    # Mutation: make the strict branch return {:ok, text, missing} - the match
    # on {:error, _} fails.
    test "strict returns the missing list as an error" do
      assert {:error, ["responses.nickname"]} =
               render!("Hi {{ responses.nickname }}!", @assigns, :strict)
    end

    # Mutation: drop the Enum.uniq in missing/1 - the same path appears twice.
    test "a path missing twice is listed once" do
      assert {:ok, _text, ["responses.nickname"]} =
               render!("{{ responses.nickname }}{{ responses.nickname }}", @assigns, :lenient)
    end

    # Mutation: make the modes differ when nothing is missing - one of the two
    # assertions fails.
    test "the modes agree when nothing is missing" do
      source = "Hi {{ responses.first_name }}!"

      assert {:ok, "Hi Ada!", []} = render!(source, @assigns, :lenient)
      assert {:ok, "Hi Ada!", []} = render!(source, @assigns, :strict)
    end

    # Mutation: delete the defaulted_positions/1 collector, or stop consulting
    # it in missing/1 - the guarded path is then reported missing in lenient
    # mode and returned as an error in strict.
    test "default means the variable is missing in neither mode" do
      source = "We will send a link to {{ responses.inbox | default: 'your inbox' }}."

      assert {:ok, "We will send a link to your inbox.", []} = render!(source, @assigns, :lenient)
      assert {:ok, "We will send a link to your inbox.", []} = render!(source, @assigns, :strict)
    end

    # The guard collector folds through the same general walk the allowlist
    # does, so the two tuple-wrapped bodies were out of its reach too and a
    # guarded path written in either one was reported missing anyway.
    #
    # Mutation: delete the is_tuple clause from reduce_nodes/3 - the guard
    # inside the elsif body is not collected and strict mode returns
    # {:error, ["responses.nickname"]}.
    test "default inside an elsif body means the variable is missing in neither mode" do
      source =
        "{% if responses.newsletter %}A{% elsif responses.plan %}" <>
          "{{ responses.nickname | default: 'friend' }}{% endif %}"

      assert {:ok, "friend", []} = render!(source, @assigns, :lenient)
      assert {:ok, "friend", []} = render!(source, @assigns, :strict)
    end

    # Mutation: delete the is_tuple clause from reduce_nodes/3 - the guard
    # inside the `when` branch body is not collected and strict mode returns
    # {:error, ["responses.nickname"]}.
    test "default inside a case branch body means the variable is missing in neither mode" do
      source =
        ~S({% case responses.plan %}{% when "pro" %}) <>
          "{{ responses.nickname | default: 'friend' }}{% endcase %}"

      assert {:ok, "friend", []} = render!(source, @assigns, :lenient)
      assert {:ok, "friend", []} = render!(source, @assigns, :strict)
    end

    # Mutation: have the default guard swallow every missing path rather than
    # only guarded ones - the unguarded path is then absent from the list.
    test "default guards only the variable it is attached to" do
      source = "{{ responses.inbox | default: 'x' }}{{ responses.nickname }}"

      assert {:ok, "x", ["responses.nickname"]} = render!(source, @assigns, :lenient)
    end

    # Mutation: pipe the rendered text through an escaping filter - the markup
    # comes back escaped and the literal assertion fails.
    test "a value containing markup renders as literal text" do
      assigns = %{"responses" => %{"first_name" => "<b>Ada</b>"}}

      assert {:ok, "Hello <b>Ada</b>", []} = render!("Hello {{ responses.first_name }}", assigns)
    end

    # Mutation: have render/3 resolve assigns with atom keys - the string-keyed
    # roots then miss and the render returns an error.
    test "assigns are string-keyed, as decoded JSON is" do
      assert {:ok, "acme", []} = render!("{{ context.tenant }}")
    end

    # Mutation: have render/3 ignore the mode argument - the strict assertion
    # below then returns {:ok, ...} and the match fails.
    test "a missing nested path is reported by its whole path" do
      assert {:error, ["responses.address.city"]} = render!("{{ responses.address.city }}")
    end
  end

  describe "render/3 condition positions" do
    # A condition asks a question rather than reading a value, so a path the
    # root does not carry is false there and is missing in neither mode. The
    # engine gives that for `if` for free and not for `unless`: it keeps a
    # condition's recorded errors when the branch it renders is the branch
    # that evaluation threw, so an `unless` whose condition is false carried
    # the error out with its body. These tests pin the rule for both tags.
    #
    # Which corpus cases guard this mechanism HERE, and which only bind a
    # second runtime. The corpus states the rule for five shapes, and they do
    # not all do the same job against this engine. Collecting no `if` or
    # `elsif` condition at all - the whole `IfTag` clause of `conditional/2`
    # replaced by `acc` - turns exactly two of them red: "A variable used only
    # as an unless condition ..." and "A condition inside a case branch body
    # ...". The and-chained `if` case stays GREEN under that mutation, because
    # the engine's own `if` renderable already drops its condition's recorded
    # errors, so the exclusion never has to do anything for that source. It is
    # a contract case rather than a regression guard here: a second runtime
    # that reported either path fails it, and this repository would not
    # notice the mechanism being deleted for `if` on its strength. A reader
    # adding a sixth shape should say which of the two jobs it is for.

    # Mutation: delete the condition_positions/1 collector, or stop consulting
    # it in missing/2 - the unless condition's path is then reported in
    # lenient mode and returned as an error in strict.
    test "a variable used only as an unless condition is missing in neither mode" do
      source = "{% unless responses.newsletter %}Add a newsletter?{% endunless %}"

      assert {:ok, "Add a newsletter?", []} = render!(source, @assigns, :lenient)
      assert {:ok, "Add a newsletter?", []} = render!(source, @assigns, :strict)
    end

    # Mutation: stop consulting condition_positions/1 in missing/2 - the
    # condition's path re-reports even though the branch that holds rendered.
    test "an unless with an else branch is clean in both modes" do
      source = "{% unless responses.newsletter %}A{% else %}B{% endunless %}"

      assert {:ok, "A", []} = render!(source, @assigns, :lenient)
      assert {:ok, "A", []} = render!(source, @assigns, :strict)
    end

    # Mutation: stop consulting condition_positions/1 in missing/2 - the
    # comparison's left argument re-reports; it sits at its own position
    # inside a BinaryCondition rather than at the condition's.
    test "a comparison in an unless condition is one position" do
      source = ~s({% unless responses.newsletter == "yes" %}A{% endunless %})

      assert {:ok, "A", []} = render!(source, @assigns, :lenient)
      assert {:ok, "A", []} = render!(source, @assigns, :strict)
    end

    # Mutation: stop following child_condition - the second operand of the
    # chain re-reports.
    test "an and-or chain in an unless condition is one position" do
      source = "{% unless responses.newsletter and responses.nickname %}A{% endunless %}"

      assert {:ok, "A", []} = render!(source, @assigns, :lenient)
      assert {:ok, "A", []} = render!(source, @assigns, :strict)
    end

    # Mutation: delete the is_tuple clause from reduce_nodes/3 - the general
    # walk stops at the {condition, body} tuple, so the unless nested in the
    # elsif body is never handed to conditional/2 and its condition re-reports.
    test "an unless nested in an elsif body is a condition position too" do
      source =
        "{% if responses.nickname %}A{% elsif responses.plan %}" <>
          "{% unless responses.newsletter %}B{% endunless %}{% endif %}"

      assert {:ok, "B", []} = render!(source, @assigns, :lenient)
      assert {:ok, "B", []} = render!(source, @assigns, :strict)
    end

    # Mutation: delete the is_tuple clause from reduce_nodes/3 - a `case`
    # branch's body is a {values, body} tuple, so the general walk stops
    # before it and the nested condition re-reports.
    test "an unless in a when body is a condition position too" do
      source =
        ~s({% case context.tenant %}{% when "acme" %}) <>
          "{% unless responses.newsletter %}B{% endunless %}{% endcase %}"

      assert {:ok, "B", []} = render!(source, @assigns, :lenient)
      assert {:ok, "B", []} = render!(source, @assigns, :strict)
    end

    # Mutation: the same. A `case` else branch is an {:else, body} tuple, a
    # different shape from a `when`'s, so it has a case of its own.
    test "an unless in a case else body is a condition position too" do
      source =
        ~s({% case context.tenant %}{% when "other" %}A{% else %}) <>
          "{% unless responses.newsletter %}B{% endunless %}{% endcase %}"

      assert {:ok, "B", []} = render!(source, @assigns, :lenient)
      assert {:ok, "B", []} = render!(source, @assigns, :strict)
    end

    # The distinction the condition collector has to keep: a `case` tag's own
    # argument is the subject and reads a value, while a condition inside one
    # of its branch bodies tests one. Both appear here and only the subject is
    # reported.
    #
    # Mutation: add a CaseTag clause to conditional/2 that passes the tag's
    # argument to tested/2 - the subject is then excluded and this goes red.
    test "a case subject reports even when its body holds a condition" do
      source =
        "{% case responses.audience %}{% else %}" <>
          "{% unless responses.newsletter %}B{% endunless %}{% endcase %}"

      assert {:ok, "B", ["responses.audience"]} = render!(source, @assigns, :lenient)
      assert {:error, ["responses.audience"]} = render!(source, @assigns, :strict)
    end

    # Mutation: exclude by variable NAME rather than by source position - the
    # output position inside the body is then swallowed too.
    test "a path in a condition is still reported where it is also read" do
      source = "{% unless responses.newsletter %}{{ responses.newsletter }}{% endunless %}"

      assert {:ok, "", ["responses.newsletter"]} = render!(source, @assigns, :lenient)
      assert {:error, ["responses.newsletter"]} = render!(source, @assigns, :strict)
    end

    # Mutation: any change that makes the exclusion reach the `if` tag's body
    # or drop its condition handling - the if half is what already worked and
    # has to keep working.
    test "the if behaviour is unchanged" do
      assert {:ok, "B", []} = render!("{% if responses.newsletter %}A{% else %}B{% endif %}")

      assert {:ok, "X", []} =
               render!(
                 "{% if responses.nickname %}Y{% elsif responses.newsletter %}Z{% else %}X{% endif %}"
               )

      assert {:ok, "", []} = render!(~s({% if responses.newsletter == "yes" %}A{% endif %}))
    end

    # The positions the rule does not reach. Each of these reads a value
    # rather than testing one, and a missing variable in them stays reported
    # in strict mode exactly as before. An exclusion that leaked from the
    # condition walk into the surrounding tree turns every one of them green
    # where it should be red, which is the failure this block guards.

    # Mutation: hand the whole IfTag to the condition collector instead of its
    # condition and elsif conditions - an output inside the body is excluded.
    test "an output position still reports the missing variable" do
      assert {:ok, "", ["responses.newsletter"]} =
               render!("{{ responses.newsletter }}", @assigns, :lenient)

      assert {:error, ["responses.newsletter"]} = render!("{{ responses.newsletter }}")
    end

    # Mutation: collect variables from every node rather than from condition
    # sub-trees - the for operand is excluded.
    test "a for operand still reports the missing variable" do
      source = "{% for guest in responses.guests %}{{ guest }}{% endfor %}"

      assert {:ok, "", ["responses.guests"]} = render!(source, @assigns, :lenient)
      assert {:error, ["responses.guests"]} = render!(source)
    end

    # Mutation: treat a CaseTag's subject as a condition position - the case
    # subject is excluded. The record names it as a read position.
    test "a case subject still reports the missing variable" do
      source = ~s({% case responses.newsletter %}{% when "yes" %}A{% endcase %})

      assert {:ok, "", ["responses.newsletter"]} = render!(source, @assigns, :lenient)
      assert {:error, ["responses.newsletter"]} = render!(source)
    end

    # Mutation: treat an AssignTag's right-hand side as a condition position -
    # the assign is excluded. The record names it as a read position.
    test "an assign right-hand side still reports the missing variable" do
      source = "{% assign plan = responses.newsletter %}{{ plan }}"

      assert {:ok, "", ["responses.newsletter"]} = render!(source, @assigns, :lenient)
      assert {:error, ["responses.newsletter"]} = render!(source)
    end

    # Mutation: treat a CaptureTag's body as a condition position - add a
    # `conditional(%Solid.Tags.CaptureTag{body: body}, acc)` clause that folds
    # `tested/2` over the body, and the capture's read is excluded. The record
    # names a capture right-hand side as a read position beside the assign.
    test "a capture right-hand side still reports the missing variable" do
      source =
        "{% capture line %}Newsletter: {{ responses.newsletter }}{% endcapture %}{{ line }}"

      # The captured value renders where it is output: lenient mode puts the
      # empty string in for the missing read, and the capture's own text still
      # arrives at the output tag rather than being swallowed with it.
      assert {:ok, "Newsletter: ", ["responses.newsletter"]} = render!(source, @assigns, :lenient)
      assert {:error, ["responses.newsletter"]} = render!(source)
    end

    # A `when` operand is a read position today and stays one; whether the
    # rule should reach it is a separate open question and not settled here.
    test "a when operand still reports the missing variable" do
      source = ~s({% case "yes" %}{% when responses.newsletter %}A{% endcase %})

      assert {:ok, "", ["responses.newsletter"]} = render!(source, @assigns, :lenient)
      assert {:error, ["responses.newsletter"]} = render!(source)
    end
  end
end
