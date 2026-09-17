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

    # Mutation: delete the liquid_refusals/1 call from compile/1 - the parse
    # tree carries no trace of the liquid tag, so the finding disappears.
    test "liquid is refused" do
      assert [%Riddler.Finding{field: "liquid"}] = refusal!("{% liquid\n  assign who = 1\n%}")
    end

    # Mutation: drop the verbatim-block masking in liquid_refusals/1 - the
    # liquid opener inside raw is then read as a construct and the compile
    # fails instead of succeeding.
    test "a liquid opener inside raw is text, not a construct" do
      assert {:ok, "{% liquid echo x %}", []} =
               render!("{% raw %}{% liquid echo x %}{% endraw %}")
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

    # Mutation: delete drop_derivative/1, or the uniq_by in to_findings/1 -
    # the parser reports the same refused tag twice and the orphaned block
    # terminator once more, and the list is then longer than the number of
    # constructs the author actually reached for.
    test "a refused construct inside a block is reported once" do
      findings = refusal!("{% if responses.plan %}{% include 'footer' %}{% endif %}")

      assert ["include"] = findings |> Enum.map(& &1.field) |> Enum.uniq()
      assert Enum.count(findings, &(&1.field == "include")) == 1
    end

    # Mutation: have drop_derivative/1 always drop terminators - a stray
    # terminator standing alone then produces no finding at all.
    test "a block terminator standing alone is still refused" do
      assert [%Riddler.Finding{field: "endif"}] = refusal!("done {% endif %}")
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

    # Mutation: drop the reduce over the elsif bodies in conditional/2 - the
    # general walk stops at the {condition, body} tuple, so a tag nested in an
    # elsif body is never reached and its own condition re-reports.
    test "an unless nested in an elsif body is a condition position too" do
      source =
        "{% if responses.nickname %}A{% elsif responses.plan %}" <>
          "{% unless responses.newsletter %}B{% endunless %}{% endif %}"

      assert {:ok, "B", []} = render!(source, @assigns, :lenient)
      assert {:ok, "B", []} = render!(source, @assigns, :strict)
    end

    # Mutation: drop the CaseTag clause of conditional/2 - a `case` branch's
    # body is a {values, body} tuple, so the general walk stops before it and
    # the nested condition re-reports.
    test "an unless in a when body is a condition position too" do
      source =
        ~s({% case context.tenant %}{% when "acme" %}) <>
          "{% unless responses.newsletter %}B{% endunless %}{% endcase %}"

      assert {:ok, "B", []} = render!(source, @assigns, :lenient)
      assert {:ok, "B", []} = render!(source, @assigns, :strict)
    end

    # Mutation: the same. A `case` else branch is an {:else, body} tuple, so
    # it needs the same clause and a case of its own.
    test "an unless in a case else body is a condition position too" do
      source =
        ~s({% case context.tenant %}{% when "other" %}A{% else %}) <>
          "{% unless responses.newsletter %}B{% endunless %}{% endcase %}"

      assert {:ok, "B", []} = render!(source, @assigns, :lenient)
      assert {:ok, "B", []} = render!(source, @assigns, :strict)
    end

    # The distinction the CaseTag clause has to keep: the tag's own argument is
    # the subject and reads a value, while a condition inside one of its branch
    # bodies tests one. Both appear here and only the subject is reported.
    #
    # Mutation: have the CaseTag clause reduce over the whole tag rather than
    # over its branch bodies - the subject is then excluded and this goes red
    # while every other case test stays green.
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

    # A `when` operand is a read position today and stays one; whether the
    # rule should reach it is a separate open question and not settled here.
    test "a when operand still reports the missing variable" do
      source = ~s({% case "yes" %}{% when responses.newsletter %}A{% endcase %})

      assert {:ok, "", ["responses.newsletter"]} = render!(source, @assigns, :lenient)
      assert {:error, ["responses.newsletter"]} = render!(source)
    end
  end
end
