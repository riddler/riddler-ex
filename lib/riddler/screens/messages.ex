defmodule Riddler.Screens.Messages do
  @moduledoc false

  # A question's `messages`: what the author says a refused response tells the
  # visitor, keyed by the code of the finding it is about. Shared by the four
  # question types, which admit it and hold it to the codes their type can
  # raise, and by response validation, which sets a finding's
  # `author_message` from it.
  #
  # `messages` is a JSON object. Each key is a code response validation can
  # raise on a response to a question of that type, and each value a plain
  # string in one language: not a template, rendered by nothing and
  # interpolating nothing. Which codes a type can raise is per type, not per
  # question, so a text question with no `format` may still key
  # `response.format`. `response.undecidable` is no type's, because it is
  # about a node's condition and not about a response.
  #
  # An author's message never replaces a finding's `message`, which stays this
  # package's own sentence; it rides beside it as `author_message`. And it
  # carries nothing of a response, so a secret question may key its codes too
  # and no finding comes to hold a secret's value.
  #
  # No part of the package's surface.

  alias Riddler.Finding

  @codes %{
    "text_question" => ["response.required", "response.format", "response.out_of_range"],
    "choice_question" => [
      "response.required",
      "response.invalid_shape",
      "response.not_an_option",
      "response.out_of_range"
    ],
    "boolean_question" => ["response.required", "response.invalid_shape"],
    "secret_question" => ["response.required", "response.invalid_shape"]
  }

  @doc false
  @spec fields() :: [atom()]
  def fields, do: [:messages]

  # The codes a question of this type can raise on a response, and so the
  # keys its `messages` may carry. A type with none takes no `messages`.
  @doc false
  @spec codes(term()) :: [String.t()]
  def codes(type), do: Map.get(@codes, type, [])

  # -- admission ---------------------------------------------------------------

  # Not an object is one finding, and a value that is not a string one finding
  # per such key, before any key it does not know: an author fixing the
  # document learns every defect in one pass. A key the type cannot raise is
  # one finding per key, the message naming it, in the order the keys sort,
  # so the same document always answers the same list.
  @doc false
  @spec findings(map()) :: [Finding.t()]
  def findings(node) do
    case Map.fetch(node, :messages) do
      {:ok, messages} when is_map(messages) and not is_struct(messages) ->
        entries = Enum.sort(messages)
        value_findings(node, entries) ++ code_findings(node, entries)

      {:ok, messages} ->
        [
          invalid(
            node,
            "messages maps a finding code to the text an author shows for it, an object, not #{inspect(messages)}"
          )
        ]

      :error ->
        []
    end
  end

  defp value_findings(node, entries) do
    for {code, text} <- entries, not is_binary(text) do
      invalid(
        node,
        "the message for #{inspect(code)} is the text an author shows, a string, not #{inspect(text)}"
      )
    end
  end

  defp code_findings(node, entries) do
    codes = codes(node[:type])

    for {code, _text} <- entries, code not in codes do
      %Finding{
        code: "document.unknown_message_code",
        message:
          "#{inspect(code)} is not a code a #{node[:type]} raises on a response; the codes it raises are #{Enum.join(codes, ", ")}",
        field: "messages",
        element_key: Finding.element_key(node[:key])
      }
    end
  end

  defp invalid(node, message) do
    %Finding{
      code: "document.invalid_messages",
      message: message,
      field: "messages",
      element_key: Finding.element_key(node[:key])
    }
  end

  # -- response validation -----------------------------------------------------

  # The findings response validation raised on one question's response, each
  # carrying the author's message for its code where the question's `messages`
  # holds one. A finding whose code it does not key, and every finding on a
  # question with no `messages`, is left as it was, `author_message` `nil`. A
  # value that is not a string is the document's defect, refused at admit, and
  # a document no one validated does not pass it on.
  @doc false
  @spec author(map(), [Finding.t()]) :: [Finding.t()]
  def author(%{messages: messages}, findings) when is_map(messages) and not is_struct(messages) do
    Enum.map(findings, fn finding ->
      case Map.get(messages, finding.code) do
        text when is_binary(text) -> %{finding | author_message: text}
        _not_keyed -> finding
      end
    end)
  end

  def author(_node, findings), do: findings
end
