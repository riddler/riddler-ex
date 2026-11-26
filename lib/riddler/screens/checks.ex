defmodule Riddler.Screens.Checks do
  @moduledoc false

  # A question's `checks`: conditions its author writes, each of which the
  # question's response has to satisfy, as the amendment to
  # `docs/adr/0002-element-document.md` headed "a question's `checks`,
  # conditions its author writes and the host's validation evaluates"
  # decides. Shared by admission, which carries them atom-keyed, by
  # resolution, which reports a check the root does not decide, and by
  # response validation, which raises a failing check's finding.
  #
  # A check is a predicator condition and nothing else. It is evaluated
  # against the root an element's condition is evaluated against, the host's
  # root with every secret question's response removed, so no check is ever
  # decided against a secret's value.
  #
  # No part of the package's surface.

  alias Riddler.Finding

  # The element types that take `checks`. On any other element a `checks` is
  # refused at admit rather than dropped, so that a check an author wrote is
  # never a check that silently never runs.
  @question_types ["text_question", "choice_question", "boolean_question", "secret_question"]

  # The three fields of a check, each required, in the order an entry missing
  # several of them is reported.
  @fields [:condition, :code, :message]

  # An author's code: `check` and one or more segments after it, each in the
  # key shape. This package raises no code beginning `check.` itself, so an
  # author's code never collides with one of the package's.
  @code_shape ~r/^check(\.[a-z][a-z0-9_]*)+$/

  @doc false
  @spec question_types() :: [String.t()]
  def question_types, do: @question_types

  @doc false
  @spec fields() :: [atom()]
  def fields, do: @fields

  @doc false
  @spec code?(term()) :: boolean()
  def code?(code), do: is_binary(code) and Regex.match?(@code_shape, code)

  # -- admission --------------------------------------------------------------

  # A list of checks is admitted entry by entry: an entry that is an object
  # is carried atom-keyed, with the three fields it wrote and nothing else,
  # as an option is; any other entry, and a `checks` that is not a list, is
  # carried as written for `Riddler.Screens.Document.validate/1` to refuse.
  @doc false
  @spec admit(term()) :: term()
  def admit(checks) when is_list(checks), do: Enum.map(checks, &admit_entry/1)
  def admit(checks), do: checks

  defp admit_entry(raw) when is_map(raw) and not is_struct(raw) do
    for field <- @fields,
        spelling = Atom.to_string(field),
        Map.has_key?(raw, spelling),
        into: %{},
        do: {field, Map.fetch!(raw, spelling)}
  end

  defp admit_entry(raw), do: raw

  # -- reading ----------------------------------------------------------------

  # The well-formed part of a question's `checks`, which is all resolution
  # and validation read: in a document no one validated, a `checks` that is
  # not a list is no checks, and an entry that is not an object, or whose
  # `condition`, `code` or `message` is absent or is not a string, is skipped,
  # so every value a finding or a diagnostics entry carries is a string the
  # document wrote. An element that is not a question has none.
  @doc false
  @spec readable(map()) :: [%{condition: String.t(), code: String.t(), message: String.t()}]
  def readable(%{type: type, checks: checks}) when type in @question_types and is_list(checks) do
    Enum.filter(checks, &readable?/1)
  end

  def readable(_node), do: []

  defp readable?(%{condition: condition, code: code, message: message}),
    do: is_binary(condition) and is_binary(code) and is_binary(message)

  defp readable?(_entry), do: false

  # Whether the root decides a check's condition, and which way: exactly where
  # the evaluator answers `{:ok, true}` or `{:ok, false}`, as an element's
  # condition is decided. Every other answer leaves it undecidable.
  @doc false
  @spec decide(String.t(), map()) :: boolean() | :undecidable
  def decide(condition, root) do
    case Predicator.evaluate(condition, root) do
      {:ok, decided} when is_boolean(decided) -> decided
      _undecidable -> :undecidable
    end
  end

  # Every check of a question its root does not decide, as the diagnostics
  # entries resolution reports, in the order of the question's `checks`.
  @doc false
  @spec undecidable(map(), map()) :: [%{key: term(), code: String.t(), condition: String.t()}]
  def undecidable(node, root) do
    for check <- readable(node), decide(check.condition, root) == :undecidable do
      %{key: node[:key], code: check.code, condition: check.condition}
    end
  end

  # -- response validation ------------------------------------------------------

  # The finding of the first check the root decides false, or none: the
  # checks are evaluated in list order, an undecidable one raises nothing and
  # the next is evaluated, and none after the first that fails is.
  @doc false
  @spec findings(map(), map(), String.t()) :: [Finding.t()]
  def findings(node, root, label) do
    case Enum.find(readable(node), &(decide(&1.condition, root) == false)) do
      nil -> []
      check -> [finding(node, check, label)]
    end
  end

  # The message is this package's own sentence, naming the question by its
  # rendered label and the check by its code. It quotes neither the response
  # nor the condition, so no finding a check raises carries a response, a
  # secret question's or any other. The author's text rides beside it.
  defp finding(node, check, label) do
    %Finding{
      code: check.code,
      message: "#{inspect(label)} fails the check #{inspect(check.code)}",
      field: "checks",
      element_key: Finding.element_key(node[:key]),
      author_message: check.message
    }
  end
end
