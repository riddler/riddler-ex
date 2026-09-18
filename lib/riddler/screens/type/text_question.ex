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
  response; where the question asks for that format, whether the expression
  compiles at all is checked here, for the same reason the format name is -
  nothing a visitor could type would satisfy one that does not, so the author
  is told while they are authoring rather than when a visitor submits. On a
  question that does not ask for the `pattern` format, a `pattern` is a field
  nothing consults and nothing here reads it. `min` and `max` are the bounds
  the `integer` and `number` formats hold a response between. A question that
  declares one without the format that reads it declares something nothing
  consults.

      iex> node = %{type: "text_question", key: "pin", label: "PIN", format: "pattern", pattern: "[0-9"}
      iex> [finding] = Riddler.Screens.Type.TextQuestion.validate(node)
      iex> finding.code
      "document.invalid_pattern"

      iex> Riddler.Screens.Type.TextQuestion.validate(%{type: "text_question", key: "email", label: "Work email", format: "email"})
      []

      iex> node = %{type: "text_question", key: "email", label: "Work email", format: "e-mail"}
      iex> [finding] = Riddler.Screens.Type.TextQuestion.validate(node)
      iex> finding.code
      "document.unknown_format"
  """

  @behaviour Riddler.Screens.Type

  alias Riddler.Finding
  alias Riddler.Screens.Compilers
  alias Riddler.Screens.Document

  @impl true
  def fields,
    do: %{required: [:label], optional: [:placeholder, :required, :format, :pattern, :min, :max]}

  @impl true
  def validate(node) do
    required_findings(node) ++ format_findings(node) ++ pattern_findings(node)
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
            node_key: Finding.node_key(node[:key])
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
              node_key: Finding.node_key(node[:key])
            }
          ]
        end

      :error ->
        []
    end
  end

  # `pattern` is an expression the author wrote and the `pattern` format
  # compiles, so one that will not compile is a defect in the document and is
  # reported here rather than when a visitor submits: nothing a visitor could
  # type would satisfy it, so there is nothing about a response to report.
  #
  # Only where the format that reads it is declared. A `pattern` on a question
  # that does not ask for the `pattern` format is a field nothing consults,
  # which is what the record says of it, and a finding about an inert field
  # would be noise. So the check follows the format, not the field: no format,
  # or another format, and this raises nothing whatever the pattern says.
  defp pattern_findings(node) do
    if Map.get(node, :format) == "pattern" do
      declared_pattern_findings(node, Map.fetch(node, :pattern))
    else
      []
    end
  end

  # A question asking for the format and declaring no pattern at all declares
  # no expression for this check to read; response validation is where that
  # one is answered. Not a string is not an expression either, and it is the
  # same defect under the same code: the question declares something nothing
  # can compile.
  defp declared_pattern_findings(_node, :error), do: []

  defp declared_pattern_findings(node, {:ok, pattern}) do
    if usable?(pattern) do
      []
    else
      [
        %Finding{
          code: "document.invalid_pattern",
          message:
            "the pattern #{inspect(pattern)} is not an expression the pattern format can compile, so nothing could satisfy it",
          field: "pattern",
          node_key: Finding.node_key(node[:key])
        }
      ]
    end
  end

  # Usable means usable by the format that reads it, so the question is asked
  # of the format's own compiler rather than of a second one here: the anchors
  # are part of what it compiles, and a check with its own copy of them would
  # drift from the one that runs when a visitor submits.
  defp usable?(pattern), do: match?({:ok, _regex}, Compilers.compile_pattern(pattern))
end
