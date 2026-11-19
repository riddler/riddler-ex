defmodule Riddler.Screens.Value do
  @moduledoc false

  # A question's `default` and `prefill`, and the `value` a resolved question
  # node presents from them. Shared by the three question types that take
  # both - `text_question`, `choice_question` and `boolean_question` - and by
  # `Riddler.Screens`, which presents the value. A secret question takes
  # neither and presents no value; its refusal of both is its own.
  #
  # A `default` is a literal the author writes, of the question's response
  # shape: a string for a text question; for a choice question one authored
  # option's value under `select: "one"` and a list of distinct authored
  # option values under `"many"`; `true` or `false` for a boolean question.
  # A `prefill` is a path of dotted segments under `context`, read when the
  # screen is resolved.
  #
  # The presented value is the first of these that yields one: a response
  # the root holds for the question, as written; the value at the prefill's
  # path, where it is one the question's default could be; the default, put
  # to the same test. A node none of them yields one for carries no value.
  # The value is presentation only: response validation reads the responses
  # the root holds and never a value.
  #
  # No part of the package's surface.

  alias Riddler.Finding

  @choice_type "choice_question"
  @boolean_type "boolean_question"

  # Anchored with \A and \z, as an option's value is, so a segment with a
  # trailing newline is not a key-shaped segment.
  @segment_shape ~r/\A[a-z][a-z0-9_]*\z/

  @doc false
  @spec fields() :: [atom()]
  def fields, do: [:default, :prefill]

  # -- admission ---------------------------------------------------------------

  @doc false
  @spec findings(map()) :: [Finding.t()]
  def findings(node), do: default_findings(node) ++ prefill_findings(node)

  # A default is held to the question's response shape and, on a choice
  # question, to its authored options, and to nothing else: not to a format,
  # a pattern or a selection bound, which it meets as a response when it is
  # submitted. A choice question whose `select` is neither value has no shape
  # to read, is already refused for its `select`, and its default is not
  # checked.
  defp default_findings(node) do
    with {:ok, default} <- Map.fetch(node, :default),
         true <- shape_readable?(node),
         false <- fits?(node, default, authored_values(node)) do
      [
        %Finding{
          code: "document.invalid_default",
          message: default_message(node, default),
          field: "default",
          node_key: Finding.node_key(node[:key])
        }
      ]
    else
      _fits_or_unchecked -> []
    end
  end

  defp default_message(%{type: @choice_type, select: "many"}, default) do
    "the default #{inspect(default)} is not a list of different values, each one this question's own options carry"
  end

  defp default_message(%{type: @choice_type}, default) do
    "the default #{inspect(default)} is not the value of one of this question's own options"
  end

  defp default_message(%{type: @boolean_type}, default) do
    "the default of a boolean question is true or false, not #{inspect(default)}"
  end

  defp default_message(_text_question, default) do
    "the default of a text question is a string, as a response to it is, not #{inspect(default)}"
  end

  defp prefill_findings(node) do
    with {:ok, prefill} <- Map.fetch(node, :prefill),
         :error <- context_path(prefill) do
      [
        %Finding{
          code: "document.invalid_context_path",
          message:
            "the prefill #{inspect(prefill)} is not a path under context: a string of dotted segments starting at context, at least one more after it, each a lower-case letter followed by lower-case letters, digits and underscores",
          field: "prefill",
          node_key: Finding.node_key(node[:key])
        }
      ]
    else
      _absent_or_path -> []
    end
  end

  @doc false
  @spec context_path(term()) :: {:ok, [String.t()]} | :error
  def context_path(path) when is_binary(path) do
    case String.split(path, ".") do
      ["context" | [_one | _more] = segments] ->
        if Enum.all?(segments, &Regex.match?(@segment_shape, &1)),
          do: {:ok, segments},
          else: :error

      _not_under_context ->
        :error
    end
  end

  def context_path(_not_a_string), do: :error

  # -- presentation ------------------------------------------------------------

  @doc false
  @spec present(map(), map()) :: map()
  def present(node, root) do
    presented = Map.drop(node, fields())

    case value(node, root) do
      {:ok, value} -> Map.put(presented, :value, value)
      :none -> presented
    end
  end

  defp value(node, root) do
    with :none <- held_response(node, root["responses"]),
         :none <- prefilled(node, root["context"]) do
      defaulted(node)
    end
  end

  # A response the root holds, and is not null, as written whatever its
  # shape: a screen shown again after validation refused a response shows
  # what the visitor sent.
  defp held_response(%{key: key}, responses) when is_binary(key) and is_map(responses) do
    case Map.get(responses, key) do
      nil -> :none
      response -> {:ok, response}
    end
  end

  defp held_response(_node, _responses), do: :none

  # The value at the path, where the path reaches one and it is a value the
  # question's default could be. A path that reaches nothing, or passes
  # through a value that is not an object, yields nothing, and is reported
  # nowhere.
  defp prefilled(node, context) do
    with {:ok, prefill} <- Map.fetch(node, :prefill),
         {:ok, segments} <- context_path(prefill),
         {:ok, found} <- walk(context, segments) do
      fitting(node, found)
    else
      _nothing -> :none
    end
  end

  defp walk(found, []), do: {:ok, found}

  defp walk(map, [segment | rest]) when is_map(map) and not is_struct(map) do
    case Map.fetch(map, segment) do
      {:ok, next} -> walk(next, rest)
      :error -> :error
    end
  end

  defp walk(_not_an_object, _segments), do: :error

  # Put to the same test as a prefill, so a host that resolves a document no
  # one validated never presents a default of the wrong shape.
  defp defaulted(node) do
    case Map.fetch(node, :default) do
      {:ok, default} -> fitting(node, default)
      :error -> :none
    end
  end

  defp fitting(node, candidate) do
    if shape_readable?(node) and fits?(node, candidate, authored_values(node)),
      do: {:ok, candidate},
      else: :none
  end

  # -- the response shape ------------------------------------------------------

  defp shape_readable?(%{type: @choice_type} = node),
    do: Map.get(node, :select) in ["one", "many"]

  defp shape_readable?(_node), do: true

  defp fits?(%{type: @choice_type, select: "one"}, value, offered),
    do: is_binary(value) and value in offered

  defp fits?(%{type: @choice_type, select: "many"}, values, offered) do
    is_list(values) and Enum.all?(values, &(is_binary(&1) and &1 in offered)) and
      Enum.uniq(values) == values
  end

  defp fits?(%{type: @boolean_type}, value, _offered), do: is_boolean(value)
  defp fits?(_text_question, value, _offered), do: is_binary(value)

  # The values the question's own options carry, the strings only. A choice
  # question whose options are not a list carries none, so no default or
  # prefill is one of them.
  defp authored_values(%{type: @choice_type} = node) do
    case Map.get(node, :answer_options) do
      options when is_list(options) ->
        for %{value: value} <- options, is_binary(value), do: value

      _none ->
        []
    end
  end

  defp authored_values(_node), do: []
end
