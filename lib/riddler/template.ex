defmodule Riddler.Template do
  @moduledoc """
  The safe template subset: a deliberately small slice of Liquid.

  A screen document carries authored prose that is not fixed text - a label
  that greets a visitor by the name they just gave, a summary line that reads
  back what they chose. Those strings are templates, and this module is what
  decides which templates a document may carry.

  ## The subset is an allowlist

  What this module accepts is enumerated here. Everything else is refused,
  including constructs Liquid or the parser underneath may add later. The
  admitted tags are `assign`, `capture`, `case`, `comment`, `for`, `if`, `raw`
  and `unless`, together with the `elsif`, `else` and `when` branches that
  belong to them. The admitted filters are the standard string, number, array
  and date filters, plus `default`; the filters that know about markup -
  `escape`, `escape_once`, `newline_to_br` and `strip_html` - are refused,
  because this package does not emit markup and does not escape.

  What is refused is a construct, never the characters of one. A template may
  print the text of a tag this subset forbids - a screen telling an author
  which tags it will not take - and that template renders those characters.

      iex> {:ok, compiled} = Riddler.Template.compile(~S({{ "{% liquid %}" }} is refused))
      iex> Riddler.Template.render(compiled, %{}, :strict)
      {:ok, "{% liquid %} is refused", []}

  ## Refusal happens at compile, never at render

  `compile/1` takes template source and no context at all, so an editor can
  tell an author that a template is wrong while the author is still looking at
  it, and the answer it gets is the same answer the runtime would reach. A
  refusal reports one finding per refused construct rather than the first, so
  that one pass over the findings is enough to fix the template.

      iex> {:error, findings} = Riddler.Template.compile("{% include 'footer' %}")
      iex> Enum.map(findings, & &1.field)
      ["include"]

  ## A source that does not parse is refused, and as what depends on the reason

  A template the parser cannot read is refused like any other template, and
  which code comes back depends on what the parser said about it. A refusal
  whose reason names a tag - a stray `{% endif %}` standing on its own, for
  example - is reported as that tag, `template.tag_not_allowed`, with the tag
  in `field`: the author reached for a construct the subset does not admit,
  and naming the construct is the answer they can act on. A refusal naming no
  tag is a parse failure, `template.parse_error`, with a null `field` and the
  parser's own reason carried in the message: there is no construct to name,
  so a host shows the reason rather than looking for a tag that is not there.

      iex> {:error, [finding]} = Riddler.Template.compile("done{% endif %}")
      iex> {finding.code, finding.field}
      {"template.tag_not_allowed", "endif"}
      iex> {:error, [finding]} = Riddler.Template.compile("Nice to meet you, {{ responses.first_name")
      iex> {finding.code, finding.field}
      {"template.parse_error", nil}

  A parse failure is also the one refusal that can arrive with no position on
  it. It carries one when the parser named a place and `nil` when the parser
  refused the source without naming one, so a host that points at a span
  checks `position` for `nil` on this code where it need not on the others.

  Both halves of the split are pinned by the conformance corpus, which is
  where a second runtime meets the same rule: "A stray closing tag is refused
  as a tag outside the subset, not as a parse error: a parse failure naming a
  tag is reported as that tag", "An unterminated output tag is refused as a
  parse error, and the finding names no field", and "A template the parser
  refuses without saying where is refused as a parse error, and the finding
  names no place".

  ## Output is text, never markup

  A template produces a string that means exactly the characters in it. A
  value containing markup renders as the literal characters of that markup:
  escaping is the act of a renderer that knows what it is rendering into, and
  this package does not know. A host rendering into HTML escapes what it is
  given here, exactly as it escapes any other untrusted string.

  ## Two render modes

  `render/3` takes lenient or strict, and they differ only in what a missing
  thing does. Lenient renders a missing variable as the empty string and
  returns the list of what was missing; it is the runtime mode, because a
  visitor should see a screen rather than an error page when an optional field
  has not been filled. Strict returns the missing list as an error; it is the
  mode for preview and for the conformance corpus, where an author and a case
  both need to be told. On a template where nothing is missing the two modes
  agree.

  A variable guarded by `default` is not missing in either mode: `default` is
  how an author says a field is optional, and lenient mode's empty string is
  the fallback for what an author did not anticipate.

  ## A condition tests a value rather than reading one

  Neither mode reports a variable that appears only in the condition of an
  `if`, an `elsif` or an `unless`. A condition asks a question, and a path the
  roots do not carry makes that question false, so the branch that holds
  renders and nothing is missing. The rule is positional: the whole condition
  is one position, whatever expression stands in it - a bare path, a
  comparison, a chain joined by `and` or `or` - and the same path read in an
  output tag, iterated by `for`, taken as a `case` subject or assigned is
  reported as it would be anywhere else.

      iex> {:ok, compiled} = Riddler.Template.compile("{% unless responses.newsletter %}Sign up?{% endunless %}")
      iex> Riddler.Template.render(compiled, %{}, :strict)
      {:ok, "Sign up?", []}

  ## Assigns are string-keyed

  The map handed to `render/3` is the document's roots - `responses` and
  `context` - and those are decoded JSON, so every key in it and in the maps
  under it is a string.

      iex> {:ok, compiled} = Riddler.Template.compile("Hi {{ responses.first_name }}!")
      iex> Riddler.Template.render(compiled, %{"responses" => %{"first_name" => "Ada"}}, :strict)
      {:ok, "Hi Ada!", []}
  """

  alias Riddler.Finding
  alias Riddler.Template.Compiled

  @tag_not_allowed "template.tag_not_allowed"
  @filter_not_allowed "template.filter_not_allowed"
  @parse_error "template.parse_error"

  # What a refusal that names no place says instead of naming one.
  @placeless_reason "the parser refused the source without naming a place"

  @allowed_tags ~w(assign capture case comment for if raw unless)

  @string_filters ~w(
    append base64_decode base64_encode base64_url_safe_decode base64_url_safe_encode
    capitalize downcase lstrip prepend remove remove_first remove_last replace
    replace_first replace_last rstrip size slice split squish strip strip_newlines
    truncate truncatewords upcase url_decode url_encode
  )
  @number_filters ~w(abs at_least at_most ceil divided_by floor minus modulo plus round times)
  @array_filters ~w(compact concat first join last map reverse sort sort_natural sum uniq where)
  @date_filters ~w(date)

  # The host-registered filter contract ships empty in this version. A
  # registered filter is a name plus one implementation per runtime, declared
  # here so that compilation accepts the name and a second runtime is obliged
  # to supply its own implementation of it. The seam exists now so that a
  # later host need does not become a change to the allowlist rule; nothing is
  # registered, and registering is not yet something a host can do from
  # outside this module.
  @registered_filters []

  @allowed_filters @string_filters ++
                     @number_filters ++
                     @array_filters ++
                     @date_filters ++ ["default"] ++ @registered_filters

  # The parser erases exactly one excluded construct. `{% liquid %}` switches
  # its lexer into a mode where the tags inside it parse as ordinary tag
  # nodes, and nothing in the resulting tree records that they arrived that
  # way - so the walk below cannot see it and the source is where it has to be
  # found. Reading the source is what makes masking necessary: the characters
  # of a liquid opener can appear in a template that holds no liquid tag at
  # all. Verbatim blocks are masked because a liquid opener written inside
  # `{% raw %}` or `{% comment %}` is text, and string literals are masked
  # because an opener a template merely prints is text too.
  @liquid_opener ~r/\{%-?\s*liquid\b/
  @verbatim_block ~r/\{%-?\s*(raw|comment)\s*-?%\}.*?\{%-?\s*end\1\s*-?%\}/s

  @unexpected_tag ~r/Unexpected tag '([^']+)'/

  # The branch and terminator keywords of the admitted block tags. A refused
  # construct inside a block leaves the block unterminated, and the parser
  # reports the orphaned terminator as a second unexpected tag - a consequence
  # of the first refusal rather than a construct the author reached for. They
  # are dropped whenever the template has a real refusal beside them, and kept
  # when one stands alone, because a terminator with no opener is genuinely
  # not a tag this package admits.
  @block_keywords ~w(
    elsif else when
    endif endunless endcase endfor endcapture endcomment endraw endtablerow
  )

  @doc """
  Compiles template source against the subset.

  Returns `{:ok, compiled}` when every construct in the source is inside the
  allowlist, and `{:error, findings}` otherwise, with one finding per refused
  construct in source order. No context is consulted and none is needed: a
  template that compiles here compiles anywhere, and a template refused here
  is refused before any visitor exists.

      iex> {:error, [finding]} = Riddler.Template.compile("{{ name | strip_html }}")
      iex> {finding.code, finding.field}
      {"template.filter_not_allowed", "strip_html"}
  """
  @spec compile(String.t()) :: {:ok, Compiled.t()} | {:error, [Finding.t()]}
  def compile(source) when is_binary(source) do
    case parse(source) do
      {:ok, %Solid.Template{parsed_template: tree} = parsed} ->
        case refusals(tree) ++ liquid_refusals(source, tree) do
          [] ->
            {:ok, %Compiled{source: source, parsed: parsed, defaulted: defaulted_positions(tree)}}

          refusals ->
            {:error, to_findings(refusals)}
        end

      {:error, %Solid.TemplateError{errors: errors}} ->
        {:error, errors |> Enum.map(&parse_refusal/1) |> drop_derivative() |> to_findings()}

      {:error, :placeless} ->
        {:error, to_findings([{nil, nil, @parse_error, nil, @placeless_reason}])}
    end
  end

  # -- the one call into the parser -----------------------------------------

  # The parser can refuse a source without saying where, and at `solid`
  # `1.3.4` it raises rather than returning when it does. A refusal carries a
  # location, and for some sources that location is a keyword list with no
  # `:line` key at all: `Solid.Parser.parse("{% render %}", [])` answers
  # `{:error, [{"Expected template name as a quoted string",
  # [end: %{line: 1, column: 11}]}]}`. `Solid.parse/2` then reads
  # `meta[:line]` out of that list to slice the offending line out of the
  # source, and the arithmetic on the `nil` it gets back raises before any
  # caller sees a return value. A neighbouring source, `{% assign e %}`,
  # reaches a placeless location one frame earlier and raises inside the
  # parser itself. Neither shape is exotic - both are reachable from ordinary
  # malformed source - and how often one is reached is a property of the
  # sources being fed in rather than of this package, so no rate is quoted
  # here.
  #
  # Both are the parser refusing a template, which is a finding here whatever
  # the refusal does or does not say about where: `compile/1` answers
  # `{:ok, compiled}` or findings and admits no third outcome, and
  # `Riddler.Screens.Document` promises not to raise on anything a host can
  # author - a host authors the template source a document node carries. So
  # the guard is here, at the one call into the parser, rather than in each
  # caller, and what it produces is the same parse-failure finding any other
  # refusal produces, with no position on it. The two exception types are
  # named rather than rescued wholesale: an exception this package has not
  # established as a refusal without a place is a defect to see, not a
  # finding to report.
  defp parse(source) do
    Solid.parse(source)
  rescue
    _placeless in [ArithmeticError, CaseClauseError] -> {:error, :placeless}
  end

  @doc """
  Renders a compiled template against assigns in lenient or strict mode.

  Lenient returns `{:ok, text, missing}`, where a missing variable rendered as
  the empty string and its path is in the list. Strict returns
  `{:ok, text, []}` when nothing was missing and `{:error, missing}` when
  something was. A variable guarded by `default`, and a variable appearing
  only in the condition of an `if`, an `elsif` or an `unless`, is missing in
  neither mode.

      iex> {:ok, compiled} = Riddler.Template.compile("Hi {{ responses.first_name }}!")
      iex> Riddler.Template.render(compiled, %{}, :lenient)
      {:ok, "Hi !", ["responses.first_name"]}
      iex> Riddler.Template.render(compiled, %{}, :strict)
      {:error, ["responses.first_name"]}
  """
  @spec render(Compiled.t(), map, :lenient | :strict) ::
          {:ok, String.t(), [String.t()]} | {:error, [String.t()]}
  def render(%Compiled{} = compiled, assigns, mode)
      when is_map(assigns) and mode in [:lenient, :strict] do
    case Solid.render(compiled.parsed, assigns, strict_variables: true, strict_filters: true) do
      {:ok, result, _tolerated} ->
        {:ok, IO.iodata_to_binary(result), []}

      {:error, errors, partial} ->
        case missing(errors, excluded_positions(compiled)) do
          [] -> {:ok, IO.iodata_to_binary(partial), []}
          missing when mode == :lenient -> {:ok, IO.iodata_to_binary(partial), missing}
          missing -> {:error, missing}
        end
    end
  end

  # -- the allowlist walk ---------------------------------------------------

  defp refusals(tree), do: tree |> reduce_nodes([], &refuse/2) |> Enum.reverse()

  defp refuse(%Solid.Filter{function: function, loc: loc}, acc) do
    if function in @allowed_filters do
      acc
    else
      [{loc.line, loc.column, @filter_not_allowed, function, "the filter"} | acc]
    end
  end

  defp refuse(node, acc) do
    case construct(node) do
      nil -> acc
      name when name in @allowed_tags -> acc
      name -> [{node.loc.line, node.loc.column, @tag_not_allowed, name, "the tag"} | acc]
    end
  end

  # Every tag the parser can produce, mapped back to the name an author wrote.
  # Two of them carry the name in a field rather than in the struct: `if` and
  # `unless` share one struct, and so do `increment` and `decrement`.
  defp construct(%Solid.Tags.IfTag{tag_name: name}), do: to_string(name)
  defp construct(%Solid.Tags.CounterTag{operation: operation}), do: to_string(operation)
  defp construct(%Solid.Tags.AssignTag{}), do: "assign"
  defp construct(%Solid.Tags.CaptureTag{}), do: "capture"
  defp construct(%Solid.Tags.CaseTag{}), do: "case"
  defp construct(%Solid.Tags.CommentTag{}), do: "comment"
  defp construct(%Solid.Tags.InlineCommentTag{}), do: "#"
  defp construct(%Solid.Tags.ForTag{}), do: "for"
  defp construct(%Solid.Tags.RawTag{}), do: "raw"
  defp construct(%Solid.Tags.BreakTag{}), do: "break"
  defp construct(%Solid.Tags.ContinueTag{}), do: "continue"
  defp construct(%Solid.Tags.CycleTag{}), do: "cycle"
  defp construct(%Solid.Tags.EchoTag{}), do: "echo"
  defp construct(%Solid.Tags.RenderTag{}), do: "render"
  defp construct(%Solid.Tags.TablerowTag{}), do: "tablerow"
  defp construct(_node), do: nil

  # -- `default` as the authored answer for an optional field ---------------

  defp defaulted_positions(tree), do: reduce_nodes(tree, MapSet.new(), &guarded/2)

  defp guarded(%Solid.Object{argument: %{loc: %Solid.Parser.Loc{} = loc}, filters: filters}, acc) do
    if Enum.any?(filters, &(&1.function == "default")) do
      MapSet.put(acc, {loc.line, loc.column})
    else
      acc
    end
  end

  defp guarded(_node, acc), do: acc

  # -- a condition asks a question rather than reading a value --------------

  # The condition of an `if`, an `elsif` or an `unless` is one position, and a
  # path the roots do not carry is `false` in it rather than missing. The
  # engine gives that for `if` and not for `unless`: an `if` and an `unless`
  # condition go through the same evaluation, but the renderable
  # implementation returns the outer context when no branch throws, so an `if`
  # drops its condition's recorded error, and an `unless` whose condition is
  # false renders the branch that evaluation threw and carries the error out
  # with it. Collecting the positions inside every condition and subtracting
  # them in `missing/2` makes the two tags mean the same thing, and because
  # only the sub-trees under `condition` and under each `elsif` are walked,
  # the exclusion cannot reach an output, a `for` operand, a `case` subject or
  # an `assign` right-hand side, all of which read a value and stay reported.
  #
  # This is collected at render rather than at compile, and only on the branch
  # where the engine reported something, so that the compiled struct a host
  # caches and hands back keeps the shape it already has.
  defp condition_positions(tree), do: reduce_nodes(tree, MapSet.new(), &conditional/2)

  defp conditional(%Solid.Tags.IfTag{condition: condition, elsifs: elsifs}, acc) do
    conditions = [condition | Enum.map(elsifs, &elem(&1, 0))]
    bodies = Enum.map(elsifs, &elem(&1, 1))
    collected = Enum.reduce(conditions, acc, &tested/2)

    # The general walk descends the `{condition, body}` tuple itself now, so
    # an `elsif` body's own nested tags are reached both ways. This fold is
    # kept so that which positions a condition excludes does not depend on
    # the general reducer's shape, and the accumulator is a `MapSet`, so a
    # position reached twice is recorded once.
    branch_bodies(bodies, collected)
  end

  # A `case` branch is a `{values, body}` tuple, or `{:else, body}` for its
  # else, which the general walk descends exactly as it does an `elsif`'s.
  # Only the bodies are followed from here: the tag's own `argument` is the
  # subject, which reads a value rather than tests one, and stays reported.
  defp conditional(%Solid.Tags.CaseTag{cases: cases}, acc) do
    cases |> Enum.map(&elem(&1, 1)) |> branch_bodies(acc)
  end

  defp conditional(_node, acc), do: acc

  # The two tuple-wrapped body positions among the admitted tags -
  # `if_tag.elsifs` and `case_tag.cases` - and no others: every other
  # admitted tag holds its body in a plain list. The general walk follows
  # both shapes now; this is the condition collector's own pass over the two
  # tuple-wrapped ones.
  defp branch_bodies(bodies, acc) do
    reduce_nodes(bodies, acc, fn node, positions -> conditional(node, positions) end)
  end

  # A condition's own traversal, because the general one reports struct nodes
  # to the function it was given and what is wanted here is every `Variable`
  # loc under a condition, `and` / `or` chains included - those hang off
  # `child_condition` as `{:and, next}`. Only an `elsif`'s condition half is
  # passed in here: its body is an ordinary read position, and the general
  # walk reaches it through the `{condition, body}` tuple.
  defp tested(%Solid.Variable{loc: %Solid.Parser.Loc{} = loc} = variable, acc) do
    tested(variable.accesses, MapSet.put(acc, {loc.line, loc.column}))
  end

  defp tested(term, acc) when is_struct(term) do
    term |> Map.from_struct() |> Map.values() |> Enum.reduce(acc, &tested/2)
  end

  defp tested(term, acc) when is_tuple(term) do
    term |> Tuple.to_list() |> Enum.reduce(acc, &tested/2)
  end

  defp tested(term, acc) when is_list(term), do: Enum.reduce(term, acc, &tested/2)

  defp tested(term, acc) when is_map(term),
    do: term |> Map.values() |> Enum.reduce(acc, &tested/2)

  defp tested(_other, acc), do: acc

  # -- the one construct the parse tree erases ------------------------------

  # The two masks are both answers to the same question - is this run of
  # characters a construct or is it text - and they have to answer it about
  # the same source, or one of them decides the other's input. Literals are
  # masked FIRST, because what a verbatim block is gets decided by the tree
  # too: a template that prints the characters of `{% raw %}`, a refused tag,
  # and the characters of `{% endraw %}` holds three constructs and no
  # verbatim block, and masking the block first read the printed characters as
  # a real opener and closer, blanked the tag between them, and admitted it.
  # Masking literals first blanks the spans the tree reports as the template's
  # own strings: a plain literal and a bracket subscript are the two shapes
  # that carry one.
  #
  # That is all this ordering fixes, and the paragraph claims nothing more.
  # Where a verbatim block ENDS is decided by the pattern below exactly as it
  # was before, and the pattern recognises one spelling of a closing tag while
  # the parser accepts several: `{% endraw xyz %}` closes a block at
  # `solid` `1.3.4` and this pattern runs past it to the next closer, blanking
  # the span between. A marker written inside a string the parser reads and
  # then THROWS AWAY is the other gap - the trailing tokens of several
  # admitted tags are discarded, so such a string is in no node, is never
  # masked, and a marker in it pairs with a real marker later in the source.
  #
  # Be exact about what gets through either gap. `liquid` is excluded as an
  # alternate SPELLING for constructs the subset already admits, not as a
  # construct the subset forbids: the tags written inside it are ordinary tag
  # nodes in the tree and the allowlist walk asks about every one of them, so
  # `{% liquid echo x %}` is still refused on `echo`. What a blanked span
  # admits is therefore an admitted construct in a spelling a second runtime
  # need not implement - a hole in what the conformance corpus can hold two
  # runtimes to - and not a forbidden construct escaping the walk.
  #
  # Both gaps are tracked separately, and the fix for them is not a wider
  # pattern. A pattern is a hand-copy of the lexer and a hand-copy drifts; the
  # end of a block is something to ask the parser for.
  defp liquid_refusals(source, tree) do
    masked =
      source
      |> mask_string_literals(tree)
      |> mask_verbatim_blocks()

    @liquid_opener
    |> Regex.scan(masked, return: :index)
    |> Enum.map(fn [{offset, _length} | _] ->
      {line, column} = position(masked, offset)
      {line, column, @tag_not_allowed, "liquid", "the tag"}
    end)
  end

  # Runs over the literal-masked source, so a `{% raw %}` or `{% comment %}`
  # marker the template merely prints is no longer here to be read as one.
  # Masking preserves length and newlines here as it does everywhere else.
  defp mask_verbatim_blocks(source) do
    Regex.replace(@verbatim_block, source, fn match, _block -> mask(match) end)
  end

  # The exemption is the parse tree's, not the source's. A template that
  # prints the characters of a liquid opener - a screen explaining to an
  # author what the subset refuses - holds a string literal there and no tag,
  # and the tree is what says so: the parser reports a `Solid.Literal` for a
  # quoted argument and ordinary `Solid.Text` for prose that merely contains
  # quotes. Masking the spans the tree calls literals therefore cannot hide a
  # real opener, where masking every quoted span in the source could.
  #
  # Masking preserves length and newlines, so the offsets stay the ones the
  # locs describe and the reported position is still the author's.
  defp mask_string_literals(source, tree) do
    tree
    |> literal_locs([])
    |> Enum.map(&literal_span(source, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(source, &mask_span(&2, &1))
  end

  # A literal's own traversal, because the general one reports struct nodes to
  # the function it was given and what is wanted here is a list of locs rather
  # than a fold over nodes. Two of the admitted tags hold a literal behind a
  # tuple - a `case` branch is a `{values, body}` pair and an `elsif` a
  # `{condition, body}` pair - which is why this walk has a tuple clause of
  # its own and had one before the general reducer grew its own.
  defp literal_locs(%Solid.Literal{loc: %Solid.Parser.Loc{} = loc}, acc),
    do: [{loc.line, loc.column} | acc]

  # A bracket subscript is a string written in the template exactly as any
  # other literal is - `a["plan"]` - but the parser reports it as its own node
  # type rather than as a literal, so the clause above does not see it. It is
  # the same exemption for the same reason: `{{ a["{% liquid %}"] }}` prints
  # those characters and holds no tag. A dot access is the same node with a
  # different `access_type` and its loc is on the identifier rather than on a
  # quote, and an integer subscript's loc is on a digit; both reach
  # `literal_span/2`, which skips a loc that does not start at a quote, so
  # this clause does not need to exclude them and is not written as though it
  # does.
  defp literal_locs(%Solid.AccessLiteral{loc: %Solid.Parser.Loc{} = loc}, acc),
    do: [{loc.line, loc.column} | acc]

  defp literal_locs(term, acc) when is_struct(term),
    do: term |> Map.from_struct() |> Map.values() |> Enum.reduce(acc, &literal_locs/2)

  defp literal_locs(term, acc) when is_tuple(term),
    do: term |> Tuple.to_list() |> Enum.reduce(acc, &literal_locs/2)

  defp literal_locs(term, acc) when is_list(term), do: Enum.reduce(term, acc, &literal_locs/2)

  defp literal_locs(term, acc) when is_map(term),
    do: term |> Map.values() |> Enum.reduce(acc, &literal_locs/2)

  defp literal_locs(_other, acc), do: acc

  # A literal's source span runs from its opening quote to the next occurrence
  # of that same character: `solid` at `1.3.4` has no escape inside a string
  # literal - `"a\"b"` is a parse error, not an escaped quote - so the next
  # one is the closing one. A loc whose character is not a quote belongs to a
  # number or a boolean and is skipped. This runs over the unmasked source -
  # it is the first of the two masks - so every loc the tree reports still
  # points at the character the author wrote.
  defp literal_span(source, {line, column}) do
    with offset when is_integer(offset) <- offset(source, line, column),
         true <- offset < byte_size(source),
         char when char in ["\"", "'"] <- binary_part(source, offset, 1),
         from = offset + 1,
         {at, 1} <-
           :binary.match(source, char, scope: {from, byte_size(source) - from}) do
      {offset, at - offset + 1}
    else
      _no_span -> nil
    end
  end

  defp mask_span(source, {offset, length}) do
    binary_part(source, 0, offset) <>
      mask(binary_part(source, offset, length)) <>
      binary_part(source, offset + length, byte_size(source) - offset - length)
  end

  defp mask(text), do: String.replace(text, ~r/[^\n]/, " ")

  # The inverse of `position/2`: a loc's line and column are one-based and
  # count bytes, as the scan's offsets do.
  defp offset(_source, 1, column), do: column - 1

  defp offset(source, line, column) do
    case Enum.at(:binary.matches(source, "\n"), line - 2) do
      {at, 1} -> at + 1 + column - 1
      nil -> nil
    end
  end

  defp position(source, offset) do
    prefix = binary_part(source, 0, offset)
    newlines = :binary.matches(prefix, "\n")

    case List.last(newlines) do
      nil -> {1, offset + 1}
      {at, 1} -> {length(newlines) + 1, offset - at}
    end
  end

  # -- parse errors ---------------------------------------------------------

  defp parse_refusal(%Solid.ParserError{reason: reason, meta: meta}) do
    case Regex.run(@unexpected_tag, reason) do
      [_whole, tag] -> {meta[:line], meta[:column], @tag_not_allowed, tag, "the tag"}
      nil -> {meta[:line], meta[:column], @parse_error, nil, reason}
    end
  end

  defp drop_derivative(refusals) do
    case Enum.reject(refusals, fn {_line, _column, _code, field, _lead} ->
           field in @block_keywords
         end) do
      [] -> refusals
      real -> real
    end
  end

  # -- findings -------------------------------------------------------------

  defp to_findings(refusals) do
    refusals
    |> Enum.uniq_by(fn {line, column, code, field, _lead} -> {line, column, code, field} end)
    |> Enum.sort_by(fn {line, column, code, field, _lead} -> {line, column, code, field} end)
    |> Enum.map(&finding/1)
  end

  # The line and the column go on being written into the message, because a
  # person reading a refusal should not have to assemble the sentence, and
  # they are also carried on `:position` for an editor that has to point at
  # the span rather than read about it. A parse failure is the one refusal
  # that can arrive without them, and `span/1` below is what it says instead.
  defp finding({line, column, @parse_error, nil, reason}) do
    position = Finding.position(line, column)

    %Finding{
      code: @parse_error,
      message: "the template could not be parsed: " <> reason <> span(position),
      field: nil,
      node_key: nil,
      position: position
    }
  end

  defp finding({line, column, code, name, lead}) do
    %Finding{
      code: code,
      message:
        "#{lead} \"#{name}\" is not in the template subset (line #{line}, column #{column})",
      field: name,
      node_key: nil,
      position: Finding.position(line, column)
    }
  end

  # A refusal with no place names none. The span is appended from the
  # position rather than from the line and the column it was built out of, so
  # that the sentence and the field cannot disagree: a refusal the parser
  # located reads as it always has, and one it did not reports the reason and
  # stops there rather than promising a place and leaving the slots empty.
  defp span(nil), do: ""
  defp span(%{line: line, column: column}), do: " (line #{line}, column #{column})"

  # -- render support -------------------------------------------------------

  defp excluded_positions(%Compiled{defaulted: defaulted, parsed: parsed}) do
    MapSet.union(defaulted, condition_positions(parsed.parsed_template))
  end

  defp missing(errors, excluded) do
    errors
    |> Enum.flat_map(fn
      %Solid.UndefinedVariableError{original_name: name, loc: loc} ->
        if MapSet.member?(excluded, {loc.line, loc.column}), do: [], else: [name]

      %Solid.UndefinedFilterError{filter: filter} ->
        [filter]

      _tolerated ->
        []
    end)
    |> Enum.uniq()
  end

  # -- traversal ------------------------------------------------------------

  # Visits every term in the parse tree - struct fields, list elements, map
  # values and tuple elements - and folds `fun` over it. Both the allowlist
  # walk and the `default` collector are just the function passed in here.
  #
  # The walk has to be TOTAL for the allowlist to mean anything: a position it
  # cannot reach is a position where a refused construct is admitted, whatever
  # the allowlist says. Two of the admitted tags hold a body behind a tuple -
  # an `if` tag's `elsifs` are `{condition, body}` pairs and a `case` tag's
  # `cases` are `{values, body}`, with `{:else, body}` for the else - and
  # without the tuple clause below a refused tag written inside either body
  # was never visited and so compiled.
  #
  # `fun` is applied to structs only: a tuple, a list and a map are containers
  # the walk descends through rather than nodes it reports, so the tuple
  # clause widens what is reached without widening what is asked about. A
  # tuple's first element is descended too - an elsif's condition, a `when`'s
  # values, the `:else` atom - and those are reached only that way: nothing
  # else in the tree leads to an elsif condition's variables or a `when`'s
  # values. What makes descending them harmless is not that they are reached
  # twice but that no collector clause matches anything found there - a
  # condition and a branch's values hold no tag and no filter, so `refuse/2`
  # falls through, `guarded/2` sees no `Object` and `conditional/2` no block
  # tag - and the collectors that fold into a `MapSet` are idempotent about
  # being handed a position twice in any case.
  defp reduce_nodes(node, acc, fun) when is_struct(node) do
    node
    |> Map.from_struct()
    |> Map.values()
    |> Enum.reduce(fun.(node, acc), &reduce_nodes(&1, &2, fun))
  end

  defp reduce_nodes(list, acc, fun) when is_list(list) do
    Enum.reduce(list, acc, &reduce_nodes(&1, &2, fun))
  end

  defp reduce_nodes(tuple, acc, fun) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.reduce(acc, &reduce_nodes(&1, &2, fun))
  end

  defp reduce_nodes(map, acc, fun) when is_map(map) do
    map |> Map.values() |> Enum.reduce(acc, &reduce_nodes(&1, &2, fun))
  end

  defp reduce_nodes(_other, acc, _fun), do: acc
end
