defmodule Riddler.Screens.Type.TextQuestion do
  @moduledoc """
  A question a visitor answers with a line of text.

  `label` is what the visitor is asked, and it is a template. `placeholder`
  is the hint shown in the empty field, and it is a template too. `required`
  says whether an empty response is acceptable and defaults to false.
  `format` names a validation format this package knows - `email` is the one
  the signup wizard uses - and the format's own check belongs to response
  validation; what this type checks is that the name is one the package will
  recognize when a response arrives, because an author who misspells a
  format should be told while they are authoring rather than when a visitor
  submits.

  Three fields belong to a format rather than to the question, and each is
  read only by the format that owns it. `pattern` is the regular expression
  the `pattern` format holds a response to, and it has to match the whole
  response. `min` and `max` are the bounds the `integer` and `number` formats
  hold a response between. A question that declares one without the format
  that reads it declares something nothing consults.

      iex> Riddler.Screens.Type.TextQuestion.validate(%{type: "text_question", key: "email", label: "Work email", format: "email"})
      []

      iex> node = %{type: "text_question", key: "email", label: "Work email", format: "e-mail"}
      iex> [finding] = Riddler.Screens.Type.TextQuestion.validate(node)
      iex> finding.code
      "document.unknown_format"
  """

  @behaviour Riddler.Screens.Type

  alias Riddler.Finding
  alias Riddler.Screens.Document

  @impl true
  def fields,
    do: %{required: [:label], optional: [:placeholder, :required, :format, :pattern, :min, :max]}

  @impl true
  def validate(node) do
    required_findings(node) ++ format_findings(node)
  end

  # `required` says whether an empty response is acceptable, so a value that
  # is not a boolean is a question whose emptiness rule nothing can read.
  # Checked only where the question declares one; an absent `required` is
  # false, which the moduledoc states and response validation applies.
  defp required_findings(node) do
    case Map.fetch(node, :required) do
      {:ok, required} when is_boolean(required) ->
        []

      {:ok, required} ->
        [
          %Finding{
            code: "document.invalid_required",
            message:
              "required says whether an empty response is acceptable, true or false, not #{inspect(required)}",
            field: "required",
            node_key: node[:key]
          }
        ]

      :error ->
        []
    end
  end

  defp format_findings(node) do
    case Map.fetch(node, :format) do
      {:ok, format} ->
        if format in Document.formats() do
          []
        else
          [
            %Finding{
              code: "document.unknown_format",
              message:
                "#{inspect(format)} is not a validation format this package knows; the formats are #{Enum.join(Document.formats(), ", ")}",
              field: "format",
              node_key: node[:key]
            }
          ]
        end

      :error ->
        []
    end
  end
end
