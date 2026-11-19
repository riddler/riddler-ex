defmodule Riddler.Screens.ContextOptions do
  @moduledoc false

  # A choice question's `answer_options_from`: a path under `context` naming
  # the list a question's options are read from when the screen is resolved,
  # in place of the `answer_options` the document writes. Admitted and checked
  # by `Riddler.Screens.Type.ChoiceQuestion`, and read by `Riddler.Screens`,
  # which resolves the options a question is shown and so the options a
  # response to it is validated against.
  #
  # The path is written as a `prefill` is - dotted segments under `context`,
  # each in the key shape - and is held to the same rule. A choice question
  # carries `answer_options` or `answer_options_from`, exactly one: both is
  # refused here, and neither is the document's `document.missing_field` on
  # `answer_options`, as it was before a question could name a path.
  #
  # The options are the value at the path where it is a list each of whose
  # entries is an object carrying a `"value"`, a string in the key shape, and
  # a `"label"`, a string, with no value carried twice. Each is taken as its
  # value and its label and nothing else, in the order the list gives them;
  # the labels are the host's data and are not templates. A path that reaches
  # nothing, or a value that is not such a list, is a question with no
  # options, reported in `missing_variables` with the path as written. An
  # empty list is a question with no options, and is not reported.
  #
  # No part of the package's surface.

  alias Riddler.Finding
  alias Riddler.Screens.Value

  # Anchored with \A and \z, as an authored option's value is.
  @value_shape ~r/\A[a-z][a-z0-9_]*\z/

  @doc false
  @spec fields() :: [atom()]
  def fields, do: [:answer_options_from]

  # -- admission ---------------------------------------------------------------

  @doc false
  @spec findings(map()) :: [Finding.t()]
  def findings(node), do: path_findings(node) ++ conflict_findings(node)

  defp path_findings(node) do
    with {:ok, path} <- Map.fetch(node, :answer_options_from),
         :error <- Value.context_path(path) do
      [
        %Finding{
          code: "document.invalid_context_path",
          message:
            "answer_options_from #{inspect(path)} is not a path under context: a string of dotted segments starting at context, at least one more after it, each a lower-case letter followed by lower-case letters, digits and underscores",
          field: "answer_options_from",
          node_key: Finding.node_key(node[:key])
        }
      ]
    else
      _absent_or_path -> []
    end
  end

  defp conflict_findings(node) do
    if Map.has_key?(node, :answer_options) and Map.has_key?(node, :answer_options_from) do
      [
        %Finding{
          code: "document.conflicting_options",
          message:
            "a choice question takes its options from answer_options or from answer_options_from, one of them, and this one carries both",
          field: "answer_options_from",
          node_key: Finding.node_key(node[:key])
        }
      ]
    else
      []
    end
  end

  # -- resolution --------------------------------------------------------------

  # The node with its options read from the context, and the paths to report
  # as missing: the path as written where it read no list of options, and
  # nothing otherwise. A question carrying both fields is refused at admit;
  # a document no one validated keeps the options it authored, and the path
  # is read for nothing. Either way the resolved node carries no
  # `answer_options_from`.
  @doc false
  @spec resolve(map(), map()) :: {map(), [String.t()]}
  def resolve(node, context) do
    case Map.fetch(node, :answer_options_from) do
      :error ->
        {node, []}

      {:ok, _path} when is_map_key(node, :answer_options) ->
        {Map.delete(node, :answer_options_from), []}

      {:ok, path} ->
        resolved = Map.delete(node, :answer_options_from)

        case read(path, context) do
          {:ok, options} -> {Map.put(resolved, :answer_options, options), []}
          :none -> {Map.put(resolved, :answer_options, []), reported(path)}
        end
    end
  end

  defp read(path, context) do
    with {:ok, segments} <- Value.context_path(path),
         {:ok, found} <- Value.walk(context, segments),
         {:ok, options} <- options(found) do
      {:ok, options}
    else
      _nothing -> :none
    end
  end

  # A path that is not a string has nothing to report it by; the document
  # refuses it at admit.
  defp reported(path) when is_binary(path), do: [path]
  defp reported(_not_a_string), do: []

  defp options(list) when is_list(list) do
    options = Enum.map(list, &option/1)
    values = for %{value: value} <- options, do: value

    if Enum.all?(options, &is_map/1) and Enum.uniq(values) == values,
      do: {:ok, options},
      else: :error
  end

  defp options(_not_a_list), do: :error

  defp option(%{"value" => value, "label" => label} = entry)
       when not is_struct(entry) and is_binary(value) and is_binary(label) do
    if Regex.match?(@value_shape, value), do: %{value: value, label: label}, else: nil
  end

  defp option(_not_an_option), do: nil
end
