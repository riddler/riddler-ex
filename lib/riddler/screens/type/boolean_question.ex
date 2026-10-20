defmodule Riddler.Screens.Type.BooleanQuestion do
  @moduledoc """
  A question a visitor answers yes or no: a lone checkbox or toggle.

  `label` is what the visitor is asked or agrees to, and it is a template.
  The response is `true` or `false`. `required` defaults to false, and true
  means the response must be `true` - the shape of "tick to agree to the
  borrowing rules", where an unticked box is the visitor declining rather than
  an empty field. `format` is carried and never consulted. A boolean question
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

  @impl true
  def fields, do: %{required: [:label], optional: [:required, :format]}

  # `required` says whether the box has to be ticked, so a value that is not a
  # boolean is a question whose rule nothing can read. Checked only where the
  # question declares one; an absent `required` is false.
  @impl true
  def validate(node) do
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
            node_key: Finding.node_key(node[:key])
          }
        ]

      :error ->
        []
    end
  end
end
