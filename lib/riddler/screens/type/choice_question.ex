defmodule Riddler.Screens.Type.ChoiceQuestion do
  @moduledoc """
  A question a visitor answers by picking from a list of options.

  `label` is what the visitor is asked, and it is a template. `select` is
  `"one"` or `"many"`, and it fixes the shape of the response: one option's
  value under `"one"`, a list of option values under `"many"`.

  `answer_options` is the list of options, in the order the visitor is shown
  them. An option carries `value` and `label`. `value` is what the response
  holds when the visitor picks that option: a string in the key shape
  `[a-z][a-z0-9_]*`, so that a condition or a template compares a response
  with it as written, and unique among this question's own options. It is not
  a key, so two questions may both offer the same value. `label` is what the
  visitor reads, and it is a template. Admission keeps exactly those two
  fields of an option and drops any other, as it drops a node field a type
  does not name.

  `style` is a hint a renderer reads - `radio` or `dropdown` for one,
  `checkboxes` or `list` for many - from an open set the renderer owns; what
  this type checks is that it is a string. `required` defaults to false, and
  true means the visitor picks at least one option. `min_selections` and
  `max_selections` bound how many options a visitor picks, and they are read
  only under `select: "many"`. Each is a non-negative integer, a number with
  no fractional part counting as one - a bound written `2.0` is admitted as
  `2`. `format` is carried and never consulted: it is a field nothing reads,
  whatever it names.

      iex> node = %{type: "choice_question", key: "card_type", label: "Which library card would you like?", select: "one", answer_options: [%{value: "adult", label: "Adult card"}, %{value: "child", label: "Child card"}]}
      iex> Riddler.Screens.Type.ChoiceQuestion.validate(node)
      []

      iex> node = %{type: "choice_question", key: "pickup_branch", label: "Where will you collect your card?", select: "one", answer_options: [%{value: "riverside", label: "Riverside"}, %{value: "riverside", label: "Riverside (east entrance)"}]}
      iex> [finding] = Riddler.Screens.Type.ChoiceQuestion.validate(node)
      iex> {finding.code, finding.node_key}
      {"document.duplicate_option_value", "pickup_branch"}
  """

  @behaviour Riddler.Screens.Type

  alias Riddler.Finding

  @selects ["one", "many"]

  @value_shape ~r/^[a-z][a-z0-9_]*$/

  @bounds [:min_selections, :max_selections]

  @impl true
  def fields,
    do: %{
      required: [:label, :select, :answer_options],
      optional: [:style, :required, :min_selections, :max_selections, :format]
    }

  @impl true
  def validate(node) do
    key = Finding.node_key(node[:key])

    select_findings(node, key) ++
      options_findings(node, key) ++
      bounds_findings(node, key) ++
      required_findings(node, key) ++
      style_findings(node, key)
  end

  # -- select ------------------------------------------------------------------

  # An absent `select` is a missing field, which the document has already
  # reported; a `select` that is there and is neither value is a question
  # whose response shape nothing can read.
  defp select_findings(node, key) do
    case Map.fetch(node, :select) do
      {:ok, select} when select in @selects ->
        []

      {:ok, select} ->
        [
          %Finding{
            code: "document.invalid_select",
            message:
              ~s(select says whether the visitor picks one option or several, "one" or "many", not #{inspect(select)}),
            field: "select",
            node_key: key
          }
        ]

      :error ->
        []
    end
  end

  # -- answer_options ----------------------------------------------------------

  # Admission answers `nil` for an `answer_options` that is not a list of
  # objects, so what reaches here is a list of atom-keyed options, each
  # carrying the `value` and `label` the document wrote and nothing else. An
  # absent list is a missing field, which the document has already reported.
  defp options_findings(node, key) do
    case Map.fetch(node, :answer_options) do
      {:ok, []} ->
        [
          %Finding{
            code: "document.empty_answer_options",
            message: "a choice question offers at least one option, and this one offers none",
            field: "answer_options",
            node_key: key
          }
        ]

      {:ok, options} when is_list(options) ->
        options
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {option, position} -> option_findings(option, position, key) end)
        |> Kernel.++(duplicate_findings(options, key))

      _absent ->
        []
    end
  end

  # One finding per defect, so an option carrying neither field is told both.
  # Admission answers `nil` for an option that is not an object, so the last
  # clause answers only a node built by hand rather than admitted.
  defp option_findings(option, position, key) when is_map(option) do
    value_findings(option, position, key) ++ label_findings(option, position, key)
  end

  defp option_findings(option, position, key) do
    [
      invalid_option(
        "option #{position} is #{inspect(option)}, and an option carries a value and a label",
        key
      )
    ]
  end

  defp value_findings(option, position, key) do
    case Map.fetch(option, :value) do
      {:ok, value} when is_binary(value) ->
        if Regex.match?(@value_shape, value) do
          []
        else
          [
            invalid_option(
              "the value #{inspect(value)} of option #{position} starts with a lower-case letter and carries only lower-case letters, digits and underscores after it",
              key
            )
          ]
        end

      {:ok, value} ->
        [
          invalid_option(
            "option #{position} carries #{inspect(value)} as its value, and a value is a string",
            key
          )
        ]

      :error ->
        [
          invalid_option(
            "option #{position} carries no value, and the value is what the response holds when the visitor picks it",
            key
          )
        ]
    end
  end

  defp label_findings(option, position, key) do
    if Map.has_key?(option, :label) do
      []
    else
      [
        invalid_option(
          "option #{position} carries no label, and the label is what the visitor reads",
          key
        )
      ]
    end
  end

  defp invalid_option(message, key) do
    %Finding{
      code: "document.invalid_option",
      message: message,
      field: "answer_options",
      node_key: key
    }
  end

  # Values are compared as written, the strings only: a value that is not one
  # has its own finding, and a value of the wrong shape is still a value two
  # options can share. One finding per value used more than once, in the order
  # each first appears.
  defp duplicate_findings(options, key) do
    values = for %{value: value} <- options, is_binary(value), do: value
    counts = Enum.frequencies(values)

    for value <- Enum.uniq(values), counts[value] > 1 do
      %Finding{
        code: "document.duplicate_option_value",
        message:
          "the value #{inspect(value)} is carried by #{counts[value]} options; the options of one question carry different values",
        field: "answer_options",
        node_key: key
      }
    end
  end

  # -- bounds ------------------------------------------------------------------

  # A bound is read only under `select: "many"`, so one declared under any
  # other `select` - "one", a value that is neither, or none - is a bound
  # nothing reads, and the author is told so. Under "many" each is held to
  # being a non-negative integer no larger than the number of options, and the
  # pair to the lower not being above the upper. One finding per bound, the
  # first that applies.
  defp bounds_findings(node, key) do
    many? = Map.get(node, :select) == "many"
    count = option_count(node)

    single =
      for bound <- @bounds,
          {:ok, value} <- [Map.fetch(node, bound)],
          message = bound_problem(bound, value, many?, node[:select], count),
          message != nil,
          do: bounds_finding(bound, message, key)

    single ++ order_findings(node, many?, key)
  end

  defp bound_problem(bound, _value, false, select, _count) do
    "#{bound} is read only when select is \"many\", and this question's select is #{inspect(select)}"
  end

  defp bound_problem(bound, value, true, _select, count) do
    cond do
      not count?(value) ->
        "#{bound} is a number of options, an integer that is not negative, not #{inspect(value)}"

      count != nil and value > count ->
        "#{bound} is #{value}, and the question offers #{count} options"

      true ->
        nil
    end
  end

  defp order_findings(node, true, key) do
    with {:ok, min} <- Map.fetch(node, :min_selections),
         {:ok, max} <- Map.fetch(node, :max_selections),
         true <- count?(min) and count?(max) and min > max do
      [
        bounds_finding(
          :min_selections,
          "min_selections is #{min} and max_selections is #{max}; the lower bound is not above the upper",
          key
        )
      ]
    else
      _in_order -> []
    end
  end

  defp order_findings(_node, false, _key), do: []

  # Admission turns a bound with no fractional part into its integer, so a
  # float that reaches here has one and is not a count.
  defp count?(value), do: is_integer(value) and value >= 0

  defp option_count(node) do
    case Map.get(node, :answer_options) do
      options when is_list(options) -> length(options)
      _absent -> nil
    end
  end

  defp bounds_finding(bound, message, key) do
    %Finding{
      code: "document.invalid_selection_bounds",
      message: message,
      field: Atom.to_string(bound),
      node_key: key
    }
  end

  # -- required and style ------------------------------------------------------

  # `required` says whether the visitor has to pick something, so a value that
  # is not a boolean is a question whose emptiness rule nothing can read.
  defp required_findings(node, key) do
    case Map.fetch(node, :required) do
      {:ok, required} when is_boolean(required) ->
        []

      {:ok, required} ->
        [
          %Finding{
            code: "document.invalid_required",
            message:
              "required says whether the visitor has to pick an option, true or false, not #{inspect(required)}",
            field: "required",
            node_key: key
          }
        ]

      :error ->
        []
    end
  end

  # Which widget the hint names stays the renderer's, as it does for a
  # button's style; that it is a string is this package's, because a renderer
  # handed a number has no name to look up.
  defp style_findings(node, key) do
    case Map.fetch(node, :style) do
      {:ok, style} when is_binary(style) ->
        []

      {:ok, style} ->
        [
          %Finding{
            code: "document.invalid_style",
            message:
              "a style is the name a renderer looks up, a string, not #{inspect(style)}; which names there are is the renderer's",
            field: "style",
            node_key: key
          }
        ]

      :error ->
        []
    end
  end
end
