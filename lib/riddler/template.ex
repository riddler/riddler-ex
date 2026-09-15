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

  ## Refusal happens at compile, never at render

  `compile/1` takes template source and no context at all, so an editor can
  tell an author that a template is wrong while the author is still looking at
  it, and the answer it gets is the same answer the runtime would reach. A
  refusal reports one finding per refused construct rather than the first, so
  that one pass over the findings is enough to fix the template.

      iex> {:error, findings} = Riddler.Template.compile("{% include 'footer' %}")
      iex> Enum.map(findings, & &1.field)
      ["include"]

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
  # found. Verbatim blocks are masked first, because a liquid opener written
  # inside `{% raw %}` or `{% comment %}` is text, not a construct.
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
    case Solid.parse(source) do
      {:ok, %Solid.Template{parsed_template: tree} = parsed} ->
        case refusals(tree) ++ liquid_refusals(source) do
          [] ->
            {:ok, %Compiled{source: source, parsed: parsed, defaulted: defaulted_positions(tree)}}

          refusals ->
            {:error, to_findings(refusals)}
        end

      {:error, %Solid.TemplateError{errors: errors}} ->
        {:error, errors |> Enum.map(&parse_refusal/1) |> drop_derivative() |> to_findings()}
    end
  end

  @doc """
  Renders a compiled template against assigns in lenient or strict mode.

  Lenient returns `{:ok, text, missing}`, where a missing variable rendered as
  the empty string and its path is in the list. Strict returns
  `{:ok, text, []}` when nothing was missing and `{:error, missing}` when
  something was. A variable guarded by `default` is missing in neither mode.

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
        case missing(errors, compiled.defaulted) do
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

  # -- the one construct the parse tree erases ------------------------------

  defp liquid_refusals(source) do
    masked = Regex.replace(@verbatim_block, source, fn match, _block -> mask(match) end)

    @liquid_opener
    |> Regex.scan(masked, return: :index)
    |> Enum.map(fn [{offset, _length} | _] ->
      {line, column} = position(masked, offset)
      {line, column, @tag_not_allowed, "liquid", "the tag"}
    end)
  end

  defp mask(text), do: String.replace(text, ~r/[^\n]/, " ")

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

  defp finding({line, column, @parse_error, nil, reason}) do
    %Finding{
      code: @parse_error,
      message: "the template could not be parsed: #{reason} (line #{line}, column #{column})",
      field: nil,
      node_key: nil
    }
  end

  defp finding({line, column, code, name, lead}) do
    %Finding{
      code: code,
      message:
        "#{lead} \"#{name}\" is not in the template subset (line #{line}, column #{column})",
      field: name,
      node_key: nil
    }
  end

  # -- render support -------------------------------------------------------

  defp missing(errors, defaulted) do
    errors
    |> Enum.flat_map(fn
      %Solid.UndefinedVariableError{original_name: name, loc: loc} ->
        if MapSet.member?(defaulted, {loc.line, loc.column}), do: [], else: [name]

      %Solid.UndefinedFilterError{filter: filter} ->
        [filter]

      _tolerated ->
        []
    end)
    |> Enum.uniq()
  end

  # -- traversal ------------------------------------------------------------

  # Visits every term in the parse tree, struct fields included, and folds
  # `fun` over it. Both the allowlist walk and the `default` collector are
  # just the function passed in here.
  defp reduce_nodes(node, acc, fun) when is_struct(node) do
    node
    |> Map.from_struct()
    |> Map.values()
    |> Enum.reduce(fun.(node, acc), &reduce_nodes(&1, &2, fun))
  end

  defp reduce_nodes(list, acc, fun) when is_list(list) do
    Enum.reduce(list, acc, &reduce_nodes(&1, &2, fun))
  end

  defp reduce_nodes(map, acc, fun) when is_map(map) do
    map |> Map.values() |> Enum.reduce(acc, &reduce_nodes(&1, &2, fun))
  end

  defp reduce_nodes(_other, acc, _fun), do: acc
end
