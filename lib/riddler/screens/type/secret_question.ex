defmodule Riddler.Screens.Type.SecretQuestion do
  @moduledoc """
  A question whose response is a secret the visitor types: a line of text the
  host keeps only in a form its own key opens, such as the PIN a new patron
  chooses for a library card.

  `label` is what the visitor is asked, and it is a template. `help` is a line
  of guidance shown beside the question, and it is a template too. `required`
  says whether a response has to be given and defaults to false.

  A secret question carries neither `default` nor `prefill`. Either would be a
  value the question starts from - a literal the author wrote into the
  document, or a value read out of the host's `context` - and a secret is a
  value only the visitor supplies. One written on a secret question is not
  dropped as a field the type does not name would be: it is refused,
  `document.secret_initial_value`, its `field` naming which, because the
  author has written a secret into the document, or asked the context for one,
  and is told so. The finding names the field and never what it holds.

  Any other field - a `placeholder`, a `format`, a `pattern` - is one the type
  does not name and admission drops it. No format is ever put to a secret
  response, because a format check writes the response it refused into its
  finding.

  What a secret question's response may be, and how it is validated, is
  `Riddler.Screens.validate_screen/3`'s; that no template, condition or write
  reads it is `Riddler.Screens.Document.validate/1`'s and
  `Riddler.Screens.resolve/2`'s.

      iex> node = %{type: "secret_question", key: "library_pin", label: "Choose a PIN for your library card", required: true}
      iex> Riddler.Screens.Type.SecretQuestion.validate(node)
      []

      iex> node = %{type: "secret_question", key: "library_pin", label: "Choose a PIN", prefill: "context.card_pin"}
      iex> [finding] = Riddler.Screens.Type.SecretQuestion.validate(node)
      iex> {finding.code, finding.field}
      {"document.secret_initial_value", "prefill"}
  """

  @behaviour Riddler.Screens.Type

  alias Riddler.Finding

  # `default` and `prefill` are named so that admission carries them to
  # `validate/1`, which refuses them; they are never part of a resolved secret
  # question.
  @initial_values [:default, :prefill]

  @impl true
  def fields, do: %{required: [:label], optional: [:required, :help] ++ @initial_values}

  @impl true
  def validate(node) do
    required_findings(node) ++ initial_value_findings(node)
  end

  @doc false
  @spec initial_values() :: [atom()]
  def initial_values, do: @initial_values

  # The sealed form: an object whose one key is `"sealed"` and whose value is
  # a string. It is the one response a secret question holds as a value: what
  # response validation accepts without checking it again, and what a resolved
  # secret question reports as `held`.
  @doc false
  @spec sealed?(term()) :: boolean()
  def sealed?(%{"sealed" => handle} = response) when is_binary(handle),
    do: map_size(response) == 1

  def sealed?(_response), do: false

  # `required` says whether a response has to be given, so a value that is not
  # a boolean is a question whose rule nothing can read. Checked only where the
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
              "required says whether the visitor has to give a response, true or false, not #{inspect(required)}",
            field: "required",
            node_key: Finding.node_key(node[:key])
          }
        ]

      :error ->
        []
    end
  end

  # One finding per field written, `default` before `prefill`. The message
  # names the field and never its value: a default is the secret itself, and
  # it is not repeated back.
  defp initial_value_findings(node) do
    for field <- @initial_values, Map.has_key?(node, field) do
      %Finding{
        code: "document.secret_initial_value",
        message:
          "a secret question starts from no value, so it carries no #{field}; its response is only what the visitor types",
        field: Atom.to_string(field),
        node_key: Finding.node_key(node[:key])
      }
    end
  end
end
