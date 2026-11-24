defmodule Riddler.Screens.Type.BooleanQuestion do
  @moduledoc """
  A question a visitor answers yes or no: a lone checkbox or toggle.

  `label` is what the visitor is asked or agrees to, and it is a template.
  `help` is a line of guidance shown beside the question, and it is a template
  too.
  The response is `true` or `false`. `required` defaults to false, and true
  means the response must be `true` - the shape of "tick to agree to the
  borrowing rules", where an unticked box is the visitor declining rather than
  an empty field. `default` is `true` or `false`, presented when nothing else
  yields a value, and `prefill` a path under `context` whose value it presents
  first.
  `messages` maps a code response validation raises on this question -
  `response.required` or `response.invalid_shape` - to the plain string its
  author shows for it, which a finding with that code carries as
  `author_message`.
  `format` is carried and never consulted. A boolean question
  carries no `style`: one written on it is a field its type does not name, and
  admission drops it.

      iex> node = %{type: "boolean_question", key: "agrees_to_rules", label: "I agree to the borrowing rules.", required: true}
      iex> Riddler.Screens.Type.BooleanQuestion.validate(node)
      []

      iex> node = %{type: "boolean_question", key: "agrees_to_rules", label: "I agree to the borrowing rules.", required: "yes"}
      iex> [finding] = Riddler.Screens.Type.BooleanQuestion.validate(node)
      iex> {finding.code, finding.field}
      {"document.invalid_required", "required"}
  """

  @behaviour Riddler.Screens.Type

  alias Riddler.Finding
  alias Riddler.Screens.Messages
  alias Riddler.Screens.Value

  @impl true
  def fields,
    do: %{
      required: [:label],
      optional: [:help, :required, :format] ++ Value.fields() ++ Messages.fields()
    }

  @impl true
  def validate(node),
    do: required_findings(node) ++ Value.findings(node) ++ Messages.findings(node)

  # `required` says whether the box has to be ticked, so a value that is not a
  # boolean is a question whose rule nothing can read. Checked only where the
  # question declares one; an absent `required` is false.
  defp required_findings(node) do
    case Map.fetch(node, :required) do
      {:ok, required} when is_boolean(required) ->
        []

      {:ok, required} ->
        [
          %Finding{
            code: "document.invalid_required",
            message:
              "required says whether the visitor has to answer yes, true or false, not #{inspect(required)}",
            field: "required",
            element_key: Finding.element_key(node[:key])
          }
        ]

      :error ->
        []
    end
  end
end
