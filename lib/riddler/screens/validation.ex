defmodule Riddler.Screens.Validation do
  @moduledoc false

  # What a set of responses has to satisfy before a host accepts it.
  #
  # The public entry points are `Riddler.Screens.validate_screen/3` and
  # `/4`; this module holds the checks behind them and is not part of the
  # package's surface. It is handed a screen that has already been resolved,
  # which is the whole of why the response checks can be this small: a node
  # that is here is a node the visitor was shown, every container has already
  # collapsed to its winner, and there is no condition left to consult.
  #
  # The one thing it is told about resolution rather than about the screen is
  # what resolution could not decide, which `undecidable_findings/2` turns into
  # findings. That is why the entry point takes the diagnostics beside the
  # screen: both halves of the answer sit behind one opt-out check, so a button
  # that declares it does not validate leaves by the same door whichever half
  # would otherwise have spoken.
  #
  # It takes the whole root rather than the responses inside it for one reason:
  # a condition that could not be decided is read again here, against the same
  # root it was resolved against, to say which of the three things went wrong
  # and to recover the place the compiler or the evaluator gave. The published
  # diagnostics could have carried that instead, and do not: their shape is
  # part of what `resolve_screen/3` answers, and a second key on it would be a
  # new public field for something only this module reads.

  alias Predicator.Errors.EvaluationError
  alias Predicator.Errors.UndefinedVariableError
  alias Riddler.Finding
  alias Riddler.Screens.Compilers
  alias Riddler.Screens.Resolved

  # A node a response answers is a node that declares something about the
  # response: whether it is required, or the format it has to be in. A node
  # that declares neither has nothing to check. The two choice types are the
  # exception, and are checked whatever they declare: a choice question's
  # options are a declaration, and a boolean question is held to its shape.
  @declaring_fields [:required, :format]

  @choice_type "choice_question"
  @boolean_type "boolean_question"

  # A response to a question carrying a format is one line of text a visitor
  # typed, so every format below reads it as text or as the number a decoder
  # already made of it.
  @email ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/
  @phone ~r/^\+?[0-9][0-9 ()\.\-]*$/

  # The undecidable findings come first: they are about whether the screen could
  # be resolved at all, which precedes anything about a response, and the nodes
  # they name are not on the resolved screen, so there is no document order to
  # interleave them into.
  @spec validate(Resolved.screen(), Resolved.diagnostics(), map(), term()) ::
          :ok | {:error, [Finding.t()]}
  def validate(screen, diagnostics, root, pressed_button_key) do
    if opted_out?(screen, pressed_button_key) do
      :ok
    else
      responses = root["responses"]

      case undecidable_findings(diagnostics, root) ++
             Enum.flat_map(screen.nodes, &node_findings(&1, responses)) do
        [] -> :ok
        findings -> {:error, findings}
      end
    end
  end

  # -- what resolution could not decide ---------------------------------------

  # A condition the root could not decide, as one finding per node resolution
  # reported. The amendment to `docs/adr/0002-element-document.md` headed "the
  # screen validated is the screen shown" decides that such a screen answers a
  # finding rather than `:ok` where the press validates: once
  # validation resolves against the host's real root, a condition that cannot be
  # decided says the root the host handed in does not carry what the document
  # asks about, which is a defect in the call and not a property of the visitor.
  # Answering `:ok` would treat the node as hidden, which is the false pass that
  # amendment removes.
  #
  # `missing_variables`, the other half of the diagnostics, is deliberately not
  # here. A variable a template wanted and the root did not carry renders as the
  # empty string on purpose, so that a visitor sees a screen rather than an
  # error page, and that record leaves the lenient rendering unchanged. Only a
  # condition decides whether a question was asked at all.
  #
  # This is reached only from inside `validate/4`'s else branch, which is the
  # amendment headed "the per-button opt-out covers an undecidable condition":
  # a press through a button declaring `validates` as `false` answers `:ok` whatever
  # resolution could not decide, because a visitor can always press Back and a
  # host's defect is not theirs to be held at the screen by.
  defp undecidable_findings(diagnostics, root) do
    Enum.map(diagnostics.undecidable_conditions, &undecidable_finding(&1, root))
  end

  # One code for three causes, by decision, and the message is what tells them
  # apart. The record headed "An undecidable condition is a finding" makes this
  # the fail-closed answer for a condition resolution could not decide, and a
  # host that skipped the document checks reaches it with a condition that does
  # not compile and with one that is not source text at all. Narrowing the code
  # to the genuinely-undecided case would let those two through such a host
  # unreported, which is the silent pass the record removes, so the code stays
  # and the sentence carries the difference.
  defp undecidable_finding(%{key: key, condition: condition}, root) do
    {lead, position} = cause(condition, root)

    %Finding{
      code: "response.undecidable",
      message:
        "the condition #{inspect(condition)} #{lead}, so whether this question was asked of the visitor is not established" <>
          span(position),
      field: "condition",
      node_key: Finding.node_key(key),
      position: position
    }
  end

  # Which of the three fired, and the place there is one for. A condition that
  # compiles was undecided against this root, and the evaluator names a place
  # for some of those and none for others - an identifier the root does not
  # carry is located, a key missing from a map it holds is not. A condition
  # that does not compile is located by the parser, and is the same defect the
  # document layer reports as `document.invalid_condition`. A condition that is
  # not a string never reached the parser and has no place to name.
  defp cause(condition, root) when is_binary(condition) do
    case Predicator.compile(condition) do
      {:ok, _instructions} -> undecided(Predicator.evaluate(condition, root))
      {:error, error} -> {"is not valid predicator", Compilers.error_position(error)}
    end
  end

  defp cause(_condition, _root), do: {"is not a string", nil}

  # A condition that compiles and was undecided, told apart by what the
  # evaluator answered and by nothing else: no code here walks the condition's
  # reads against the root. Three answers each name what went wrong. An unbound
  # top-level name is a name the root does not carry; a value that is decided
  # but is not a boolean is a condition that does not answer true or false; an
  # evaluation error, such as a division by zero or a function the evaluator
  # does not know, is a condition that fails to evaluate. Two answers do not: `:undefined`
  # comes back both for a key missing from a map the root holds and for operands
  # of types an operator does not compare, and a type mismatch comes back both
  # for a real type error and for a missing key under an operator that wants a
  # boolean or a number. Those, and any error not named here, take one wording
  # that names neither cause. The place is the evaluator's wherever it gave one,
  # whichever wording the answer takes.
  defp undecided({:error, %UndefinedVariableError{} = error}),
    do:
      {"reads a name the root this screen was validated with does not carry",
       Compilers.error_position(error)}

  defp undecided({:error, %EvaluationError{} = error}),
    do: {"fails to evaluate", Compilers.error_position(error)}

  defp undecided({:error, error}), do: {"could not be decided", Compilers.error_position(error)}
  defp undecided({:ok, :undefined}), do: {"could not be decided", nil}
  defp undecided({:ok, _not_a_boolean}), do: {"does not answer true or false", nil}

  # The place is appended from the position rather than from the numbers it was
  # built out of, so the message and the field cannot disagree about whether
  # there is one.
  defp span(%{line: line, column: column}), do: " (line #{line}, column #{column})"
  defp span(nil), do: ""

  # -- the per-button opt-out -------------------------------------------------

  # `validates` defaults to true, so a button this screen does not carry - and
  # no button at all - validates. Only a button that says `false` out loud
  # skips the checks, which is what lets a Back button leave a half-filled
  # screen without an error.
  #
  # The opt-out belongs to the press rather than to the screen, which the
  # amendment to `docs/adr/0002-element-document.md` headed "a keyless button
  # cannot opt out, and a call naming no button never does" decides. A call
  # naming no pressed button has no button to read `validates` from, so it
  # runs the checks in full: that is every arity-3 call, and it is an arity-4
  # call handed `nil` as well. The clause below is what says so, and it is
  # also what keeps a button node carrying no `key` out of the match - the
  # node's absent key would otherwise compare equal to the absent press and
  # silence every finding on the screen at once.
  defp opted_out?(_screen, nil), do: false

  defp opted_out?(screen, pressed_button_key) do
    case Enum.find(screen.nodes, &button?(&1, pressed_button_key)) do
      nil -> false
      button -> Map.get(button, :validates, true) == false
    end
  end

  # The key reaching here is never `nil`, so a button node carrying no `key`
  # is never a candidate: nothing can press a button nothing can name, and a
  # keyless node sitting in front of a keyed one hides it from nobody.
  defp button?(node, key), do: node[:type] == "button" and node[:key] == key

  # -- one node ---------------------------------------------------------------

  defp node_findings(%{type: @choice_type} = node, responses),
    do: choice_findings(node, Map.get(responses, node[:key]))

  defp node_findings(%{type: @boolean_type} = node, responses),
    do: boolean_findings(node, Map.get(responses, node[:key]))

  defp node_findings(node, responses) do
    if Enum.any?(@declaring_fields, &Map.has_key?(node, &1)) do
      checks(node, Map.get(responses, node[:key]))
    else
      []
    end
  end

  # A blank response is either the one thing `required` is about or nothing at
  # all: a format has nothing to say about text a visitor did not type, and
  # reporting both would tell an author twice about one empty field.
  defp checks(node, response) do
    cond do
      not blank?(response) -> format_findings(node, response)
      Map.get(node, :required, false) == true -> [required_finding(node)]
      true -> []
    end
  end

  defp blank?(nil), do: true
  defp blank?(response) when is_binary(response), do: String.trim(response) == ""
  defp blank?(_response), do: false

  defp required_finding(node) do
    finding(
      node,
      "response.required",
      "required",
      "#{inspect(label(node))} has to be answered"
    )
  end

  # -- the choice types -------------------------------------------------------

  # A choice question answers at most one finding, the first of the checks the
  # amendment to `docs/adr/0002-element-document.md` headed "two choice node
  # types" orders: nothing selected, the shape `select` fixes, a value no
  # option carries, and the selection bounds. Its `format` is a field nothing
  # consults, so no clause here reads it.
  #
  # A `select` that is neither "one" nor "many" is the document's defect,
  # reported at admit; no shape can be read from it, so the response is held
  # to `required` and to nothing else, as a format name the package does not
  # know holds a response to nothing.
  defp choice_findings(node, response) do
    select = Map.get(node, :select)

    cond do
      nothing_selected?(select, response) -> unanswered(node)
      select not in ["one", "many"] -> []
      not choice_shape?(select, response) -> [choice_shape_finding(node, select)]
      true -> option_findings(node, select, response)
    end
  end

  # What counts as nothing selected is fixed by `select`: an empty string is
  # no option under "one", and an empty list no options under "many". A list
  # under "one" and a string under "many" are the wrong shape, empty or not.
  # Under a `select` neither value names, any of the three empty forms is
  # nothing selected, since no shape says which one the visitor meant.
  defp nothing_selected?(_select, nil), do: true
  defp nothing_selected?("one", response), do: response == ""
  defp nothing_selected?("many", response), do: response == []
  defp nothing_selected?(_select, response), do: response in ["", []]

  # An empty selection on a question that is not required is accepted whatever
  # its bounds, as a blank text response that is not required is never put to
  # its format.
  defp unanswered(node) do
    if Map.get(node, :required, false) == true, do: [required_finding(node)], else: []
  end

  defp choice_shape?("one", response), do: is_binary(response)

  defp choice_shape?("many", response) do
    is_list(response) and Enum.all?(response, &is_binary/1) and
      length(Enum.uniq(response)) == length(response)
  end

  defp choice_shape_finding(node, "one") do
    finding(
      node,
      "response.invalid_shape",
      "select",
      "#{inspect(label(node))} is answered with one option's value, a string, and the response is not one"
    )
  end

  defp choice_shape_finding(node, "many") do
    finding(
      node,
      "response.invalid_shape",
      "select",
      "#{inspect(label(node))} is answered with a list of different option values, each a string, and the response is not one"
    )
  end

  # Values are compared as written: none is trimmed or folded, so a response
  # carrying an option's value with a space around it is not that option.
  defp option_findings(node, select, response) do
    values = if select == "one", do: [response], else: response
    offered = offered_values(node)

    case Enum.reject(values, &(&1 in offered)) do
      [] when select == "many" -> selection_findings(node, length(values))
      [] -> []
      strays -> [not_an_option_finding(node, strays)]
    end
  end

  defp offered_values(node) do
    case Map.get(node, :answer_options) do
      options when is_list(options) -> for %{value: value} <- options, do: value
      _absent -> []
    end
  end

  defp not_an_option_finding(node, strays) do
    finding(
      node,
      "response.not_an_option",
      "answer_options",
      "#{inspect(label(node))} offers no option with the value #{Enum.map_join(strays, ", ", &inspect/1)}"
    )
  end

  # The bounds are counts of options. A bound that is not a non-negative
  # integer is the document's defect, `document.invalid_selection_bounds`,
  # raised before a visitor arrives, so it bounds nothing here.
  defp selection_findings(node, count) do
    min = Map.get(node, :min_selections)
    max = Map.get(node, :max_selections)

    cond do
      count?(min) and count < min ->
        [selection_finding(node, "min_selections", "at least", min, count)]

      count?(max) and count > max ->
        [selection_finding(node, "max_selections", "at most", max, count)]

      true ->
        []
    end
  end

  defp count?(bound), do: is_integer(bound) and bound >= 0

  defp selection_finding(node, field, direction, bound, count) do
    finding(
      node,
      "response.out_of_range",
      field,
      "#{inspect(label(node))} takes #{direction} #{bound} of its options, and #{count} were picked"
    )
  end

  # A boolean question is a lone checkbox: absent or null is nothing selected,
  # and `false` is the visitor declining, which a question that is required
  # does not accept.
  defp boolean_findings(node, nil), do: unanswered(node)

  defp boolean_findings(node, response) when is_boolean(response) do
    if response == false and Map.get(node, :required, false) == true do
      [
        finding(
          node,
          "response.required",
          "required",
          "#{inspect(label(node))} has to be answered yes, and the response is false"
        )
      ]
    else
      []
    end
  end

  defp boolean_findings(node, _response) do
    [
      finding(
        node,
        "response.invalid_shape",
        "type",
        "#{inspect(label(node))} is answered true or false, and the response is neither"
      )
    ]
  end

  # -- the formats ------------------------------------------------------------

  defp format_findings(node, response) do
    case Map.fetch(node, :format) do
      {:ok, format} -> check(format, node, response)
      :error -> []
    end
  end

  # A format name the package does not know is already a document finding -
  # `document.unknown_format`, raised before a visitor arrives - so there is
  # nothing left for a response to be wrong about.
  defp check("email", node, response),
    do: matching(@email, node, response, "an email address")

  defp check("phone", node, response), do: phone(node, response)
  defp check("pattern", node, response), do: pattern(node, response)
  defp check("integer", node, response), do: numeric(node, response, :integer)
  defp check("number", node, response), do: numeric(node, response, :number)
  defp check(_unknown, _node, _response), do: []

  defp matching(regex, node, response, what) when is_binary(response) do
    if Regex.match?(regex, String.trim(response)) do
      []
    else
      [format_finding(node, "#{inspect(response)} is not #{what}")]
    end
  end

  defp matching(_regex, node, response, what),
    do: [format_finding(node, "#{inspect(response)} is not #{what}")]

  # A phone number is punctuation a visitor chose plus the digits that carry
  # the meaning, so the shape is checked loosely and the digits are counted:
  # seven is the shortest subscriber number in use.
  defp phone(node, response) when is_binary(response) do
    trimmed = String.trim(response)
    digits = trimmed |> String.graphemes() |> Enum.count(&(&1 in ~w(0 1 2 3 4 5 6 7 8 9)))

    if Regex.match?(@phone, trimmed) and digits >= 7 do
      []
    else
      [format_finding(node, "#{inspect(response)} is not a phone number")]
    end
  end

  defp phone(node, response),
    do: [format_finding(node, "#{inspect(response)} is not a phone number")]

  # The pattern is the author's, and it has to match the whole response: a
  # pattern anchored at neither end would admit anything carrying a match
  # somewhere inside it, which is not what an author writing one means.
  defp pattern(node, response) do
    case Compilers.compile_pattern(Map.get(node, :pattern)) do
      {:ok, regex} -> matching(regex, node, response, "in the form this question asks for")
      :error -> unreadable_pattern(node)
    end
  end

  # A pattern the package cannot compile is already a document finding -
  # `document.invalid_pattern`, raised before a visitor arrives - so there is
  # nothing left for a response to be wrong about, exactly as for a format name
  # the package does not know. Reporting it here as well would tell an author
  # about one defect from two layers. The case that is left is a question
  # asking for the `pattern` format and declaring no pattern at all: the
  # document check has no expression to read, and no response can be in a form
  # the question never states.
  defp unreadable_pattern(node) do
    if Map.has_key?(node, :pattern), do: [], else: [pattern_finding(node)]
  end

  defp pattern_finding(node) do
    %Finding{
      code: "response.format",
      message:
        "this question asks for a response in the form of a pattern and declares none, so nothing can satisfy it",
      field: "pattern",
      node_key: Finding.node_key(node[:key])
    }
  end

  # -- the numeric kinds and their range --------------------------------------

  defp numeric(node, response, kind) do
    case number(response, kind) do
      {:ok, value} -> range_findings(node, value)
      :error -> [format_finding(node, "#{inspect(response)} is not #{describe(kind)}")]
    end
  end

  defp describe(:integer), do: "a whole number"
  defp describe(:number), do: "a number"

  defp number(response, :integer) when is_integer(response), do: {:ok, response}
  defp number(response, :number) when is_number(response), do: {:ok, response}

  defp number(response, kind) when is_binary(response) do
    parse(String.trim(response), kind)
  end

  defp number(_response, _kind), do: :error

  defp parse(text, :integer) do
    case Integer.parse(text) do
      {value, ""} -> {:ok, value}
      _not_whole -> :error
    end
  end

  defp parse(text, :number) do
    case Float.parse(text) do
      {value, ""} -> {:ok, value}
      _not_a_number -> :error
    end
  end

  # `min` and `max` are the numeric kinds' own bounds: a bound that is not a
  # number is not a bound, and a question with no format has no numeric value
  # to bound, so neither is consulted anywhere else.
  defp range_findings(node, value) do
    cond do
      under?(Map.get(node, :min), value) ->
        [range_finding(node, "min", "at least", Map.get(node, :min), value)]

      over?(Map.get(node, :max), value) ->
        [range_finding(node, "max", "at most", Map.get(node, :max), value)]

      true ->
        []
    end
  end

  defp under?(bound, value) when is_number(bound), do: value < bound
  defp under?(_bound, _value), do: false

  defp over?(bound, value) when is_number(bound), do: value > bound
  defp over?(_bound, _value), do: false

  defp range_finding(node, field, direction, bound, value) do
    %Finding{
      code: "response.out_of_range",
      message: "#{inspect(label(node))} is #{direction} #{bound}, and #{value} is not",
      field: field,
      node_key: Finding.node_key(node[:key])
    }
  end

  # -- findings ---------------------------------------------------------------

  # Every site here that puts a node's key on a finding goes through
  # `Finding.node_key/1`, for the reason the document checks do: a key is a
  # string by the record the document implements, the field is typed that way,
  # and a key of any other form is one no host can look a node up by. This path
  # runs on every submission rather than once at authoring time, so it is the
  # half a host indexing findings by that field meets most often.
  defp format_finding(node, detail), do: finding(node, "response.format", "format", detail)

  defp finding(node, code, field, message) do
    %Finding{code: code, message: message, field: field, node_key: Finding.node_key(node[:key])}
  end

  # The label is what the visitor was asked, already rendered by resolution, so
  # a finding names the field the way the screen does rather than by its key.
  defp label(node) do
    case Map.get(node, :label) do
      label when is_binary(label) -> label
      _unlabelled -> node[:key]
    end
  end
end
