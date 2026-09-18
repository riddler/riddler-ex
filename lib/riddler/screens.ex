defmodule Riddler.Screens do
  @moduledoc """
  A document against one visitor: what they are shown, and what could not be
  decided.

  `Riddler.Screens.Document` answers whether a document is well formed, on its
  own, before anyone arrives. This module answers the other question: given a
  host's `context` and a visitor's `responses`, which nodes are shown, what do
  their templates say, and which container won. `resolve/2` answers it for a
  whole document and `resolve_screen/3` for the one screen a host is about to
  render.

  Both are pure and total over anything an admitted document can hold: they
  consult no store, raise on nothing, and report what they could not decide
  rather than refusing it. Both report through the same pair of diagnostics:
  `resolve/2` carries them on the resolved document, `resolve_screen/3` answers
  with them beside the screen.

  ## The root

  The root is the map a condition and a template both read, and it has exactly
  two keys: `"context"`, what the host knows, and `"responses"`, what the
  visitor has submitted so far. Both are string-keyed, because both are decoded
  JSON, and a response is addressed `responses.<key>` where the key is the key
  of the question node it belongs to.

  ## What resolution does to a node

  A node with no condition is shown. A node whose condition evaluates false is
  hidden silently, because that is the condition doing its job. A node whose
  condition cannot be evaluated - a variable the root does not carry, an
  operand of the wrong type, anything that is not true or false - is hidden
  *and* reported in `undecidable_conditions`: the author asked a question the
  runtime could not answer, and a visitor should not be shown a node on a
  guess.

  A container resolves to the first of its candidates whose condition holds,
  and the winner replaces the container, so nothing downstream needs to know a
  container was ever there. A container no candidate wins resolves to nothing.

  Every template field - `text`, `label` and `placeholder` - is rendered
  leniently: a variable the root does not carry renders as the empty string and
  is reported in `missing_variables`, so a visitor sees a screen rather than an
  error page. A node that is hidden is never rendered, so it contributes no
  missing variables.

  The output carries no `condition` anywhere, and carries `writes` through
  untouched: what a button sets is the host's to apply when the visitor presses
  it.

  ## What a set of responses has to satisfy

  `validate_screen/3` and `validate_screen/4` answer the last question:
  whether what the visitor typed is enough to submit the screen. They resolve
  the screen first and check only what came back, so a question a condition hid
  cannot fail, and they consult what the node declares - `required`, `format`,
  and `min` and `max` on the numeric formats. The arity-4 form takes the key of
  the button the visitor pressed and honours its `validates`.

  They take the same root `resolve/2` and `resolve_screen/3` take, and the
  responses they check are the ones inside it. The screen validated is the
  screen shown: a question the host's `context` made visible to this visitor
  is a question this visitor can fail. A condition that root could not decide
  is a finding rather than a pass wherever the press validates, because a node
  hidden from the validator and not from the visitor is the one case this
  cannot guess at.

      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 1,
      ...>     "id" => "edoc_checkout",
      ...>     "screens" => [
      ...>       %{
      ...>         "key" => "card",
      ...>         "title" => "Your card",
      ...>         "nodes" => [
      ...>           %{
      ...>             "type" => "text",
      ...>             "key" => "card_intro",
      ...>             "text" => "Charging {{ context.tenant_name }}."
      ...>           },
      ...>           %{
      ...>             "type" => "text",
      ...>             "key" => "card_expiring",
      ...>             "condition" => "context.card_expires_within_days < 30",
      ...>             "text" => "The card on file expires soon."
      ...>           }
      ...>         ]
      ...>       }
      ...>     ]
      ...>   })
      iex> root = %{"context" => %{"tenant_name" => "Acme", "card_expires_within_days" => 9}}
      iex> {:ok, resolved} = Riddler.Screens.resolve(document, root)
      iex> Enum.map(hd(resolved.screens).nodes, & &1.text)
      ["Charging Acme.", "The card on file expires soon."]
      iex> resolved.diagnostics
      %{missing_variables: [], undecidable_conditions: []}
  """

  alias Riddler.Finding
  alias Riddler.Screens.Document
  alias Riddler.Screens.Resolved
  alias Riddler.Screens.Validation
  alias Riddler.Template

  @empty_diagnostics %{missing_variables: [], undecidable_conditions: []}

  @doc """
  Resolves every screen of a document against a root.

  Always `{:ok, resolved}`: resolution reports rather than refuses, so a
  condition it could not evaluate and a variable it could not find come back in
  the resolved document's diagnostics.

  The root is read for `"context"` and `"responses"` and nothing else; either
  one absent is the same as it being empty.

      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 1,
      ...>     "id" => "edoc_signup",
      ...>     "screens" => [
      ...>       %{
      ...>         "key" => "account",
      ...>         "title" => "Create your account",
      ...>         "nodes" => [
      ...>           %{
      ...>             "type" => "text",
      ...>             "key" => "account_greeting",
      ...>             "condition" => "responses.first_name != ''",
      ...>             "text" => "Nice to meet you, {{ responses.first_name }}."
      ...>           }
      ...>         ]
      ...>       }
      ...>     ]
      ...>   })
      iex> {:ok, resolved} = Riddler.Screens.resolve(document, %{})
      iex> {hd(resolved.screens).nodes, resolved.diagnostics.undecidable_conditions}
      {[], [%{key: "account_greeting", condition: "responses.first_name != ''"}]}
  """
  @spec resolve(Document.t(), map()) :: {:ok, Resolved.t()}
  def resolve(%Document{} = document, root) when is_map(root) do
    root = normalize(root)

    {screens, diagnostics} =
      Enum.map_reduce(document.screens, @empty_diagnostics, &resolve_one(&1, root, &2))

    {:ok,
     %Resolved{
       schema_version: document.schema_version,
       kind: document.kind,
       id: document.id,
       metadata: document.metadata,
       screens: screens,
       diagnostics: order(diagnostics)
     }}
  end

  @doc """
  Resolves the one screen a host is about to render.

  `{:ok, screen, diagnostics}`: the screen, and what resolving *that* screen
  could not decide. The diagnostics are the shape `resolve/2` carries on a
  resolved document - `missing_variables` and `undecidable_conditions`, both in
  document order - narrowed to the one screen. A caller is never handed a
  screen whose resolution reported something without being handed the report,
  which is what lets a single-screen host tell a node hidden by a condition
  that held from a node hidden because the condition could not be decided.

  Returns `{:error, :no_such_screen}` when the document declares no screen
  under that key: asking for a screen that is not there is the host's mistake,
  not a visitor's, and is worth an error rather than an empty screen.

      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 1,
      ...>     "id" => "edoc_signup",
      ...>     "screens" => [
      ...>       %{
      ...>         "key" => "account",
      ...>         "title" => "Create your account",
      ...>         "nodes" => [
      ...>           %{
      ...>             "type" => "text",
      ...>             "key" => "account_greeting",
      ...>             "condition" => "responses.first_name != ''",
      ...>             "text" => "Nice to meet you."
      ...>           }
      ...>         ]
      ...>       }
      ...>     ]
      ...>   })
      iex> {:ok, screen, diagnostics} = Riddler.Screens.resolve_screen(document, "account", %{})
      iex> {screen.key, screen.title, screen.nodes}
      {"account", "Create your account", []}
      iex> diagnostics
      %{
        missing_variables: [],
        undecidable_conditions: [
          %{key: "account_greeting", condition: "responses.first_name != ''"}
        ]
      }
      iex> Riddler.Screens.resolve_screen(document, "plan", %{})
      {:error, :no_such_screen}
  """
  @spec resolve_screen(Document.t(), term(), map()) ::
          {:ok, Resolved.screen(), Resolved.diagnostics()} | {:error, :no_such_screen}
  def resolve_screen(%Document{} = document, screen_key, root) when is_map(root) do
    case Enum.find(document.screens, &(&1.key == screen_key)) do
      nil ->
        {:error, :no_such_screen}

      screen ->
        {resolved, diagnostics} = resolve_one(screen, normalize(root), @empty_diagnostics)
        {:ok, resolved, order(diagnostics)}
    end
  end

  @doc """
  Validates a visitor's responses against the screen they were shown.

  `:ok`, or every reason the screen is not ready to be submitted. Checks run
  over the *resolved* screen and nothing else: the screen is resolved against
  the root the host resolved with, so a node a condition hid is a node the
  visitor never saw and cannot be held to. A question the visitor was never
  asked cannot fail.

  The root is the one `resolve/2` and `resolve_screen/3` take, read for
  `"context"` and `"responses"` and nothing else, and the responses that are
  checked are the ones inside it. A screen validated is the screen shown: a
  question a `context` condition made visible to this visitor is a question
  this visitor can fail.

  What is checked is what the node declares. `required` is unanswered when the
  response is absent or is a string of whitespace. `format` names one of the
  validation formats `Riddler.Screens.Document.formats/0` lists, and a blank
  response that is not required is not put to it - a format has nothing to say
  about text a visitor did not type. The numeric formats also honour `min` and
  `max` where the question declares them.

  Every finding names the node it is about in `node_key`, the field that was
  not satisfied in `field`, and a stable `code`: `response.required`,
  `response.format`, `response.out_of_range` or `response.undecidable`. There
  is one finding per failing node, because an empty field is one thing wrong
  with a screen and not three.

  `response.undecidable` is the one that is not about a response. A condition
  this root could not decide - a variable the root does not carry, an operand
  of the wrong type - is reported as a finding on the node that carries it,
  with `field` `"condition"`. A condition that could not be decided says the
  root the host handed in does not carry what the document asks about, which
  is a defect in the call rather than a property of the visitor, so treating
  the node as hidden and answering `:ok` would accept a submission nobody
  checked. It is reported wherever the pressed button validates. The press
  that does not is one through a button declaring `validates` as `false`,
  which answers `:ok` without running a check at all - see
  `validate_screen/4`. This arity-3 form presses no button, and a button that
  is not there carries the default, so a call through it reports the finding -
  unless the screen carries a button declaring `validates` as `false` and no
  key at all, which is a document `Riddler.Screens.Document.validate/1`
  reports as defective.

  A condition this root *decides* false is a different thing and stays silent:
  the node is hidden, and a question the visitor was never asked cannot fail.
  So is a variable a template wanted and the root did not carry - that renders
  as the empty string, is reported in `missing_variables`, and is no finding.

  `{:error, :no_such_screen}` comes straight back from `resolve_screen/3`: a
  host asking about a screen the document does not declare is told so rather
  than told its responses are fine.

      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 1,
      ...>     "id" => "edoc_checkout",
      ...>     "screens" => [
      ...>       %{
      ...>         "key" => "card",
      ...>         "title" => "Your card",
      ...>         "nodes" => [
      ...>           %{
      ...>             "type" => "text_question",
      ...>             "key" => "billing_email",
      ...>             "label" => "Where should the receipt go?",
      ...>             "required" => true,
      ...>             "format" => "email"
      ...>           }
      ...>         ]
      ...>       }
      ...>     ]
      ...>   })
      iex> Riddler.Screens.validate_screen(document, "card", %{"responses" => %{"billing_email" => "ada@example.com"}})
      :ok
      iex> {:error, [finding]} = Riddler.Screens.validate_screen(document, "card", %{"responses" => %{"billing_email" => "ada"}})
      iex> {finding.code, finding.node_key, finding.field}
      {"response.format", "billing_email", "format"}
      iex> {:error, [finding]} = Riddler.Screens.validate_screen(document, "card", %{})
      iex> finding.code
      "response.required"
      iex> Riddler.Screens.validate_screen(document, "billing", %{})
      {:error, :no_such_screen}
  """
  @spec validate_screen(Document.t(), term(), map()) ::
          :ok | {:error, [Finding.t()]} | {:error, :no_such_screen}
  def validate_screen(%Document{} = document, screen_key, root) when is_map(root),
    do: validate_screen(document, screen_key, root, nil)

  @doc """
  Validates the responses the way the button the visitor pressed asks for.

  The same checks as `validate_screen/3`, with one addition: the pressed
  button's `validates`. It defaults to true, so a button that says nothing
  validates the screen it submits; a button that declares `false` answers
  `:ok` without running a check, which is what lets a Back button leave a
  half-filled screen. A key that names no button on the resolved screen
  validates too, because the default is what a button that is not there
  carries.

      iex> screen = %{
      ...>   "key" => "card",
      ...>   "title" => "Your card",
      ...>   "nodes" => [
      ...>     %{"type" => "text_question", "key" => "billing_email", "label" => "Receipt to", "required" => true},
      ...>     %{"type" => "button", "key" => "card_back", "label" => "Back", "outcome" => "went_back", "validates" => false},
      ...>     %{"type" => "button", "key" => "card_pay", "label" => "Pay", "outcome" => "paid"}
      ...>   ]
      ...> }
      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 1,
      ...>     "id" => "edoc_checkout",
      ...>     "screens" => [screen]
      ...>   })
      iex> Riddler.Screens.validate_screen(document, "card", %{}, "card_back")
      :ok
      iex> {:error, [finding]} = Riddler.Screens.validate_screen(document, "card", %{}, "card_pay")
      iex> finding.code
      "response.required"
  """
  @spec validate_screen(Document.t(), term(), map(), term()) ::
          :ok | {:error, [Finding.t()]} | {:error, :no_such_screen}
  def validate_screen(%Document{} = document, screen_key, root, pressed_button_key)
      when is_map(root) do
    root = normalize(root)

    case resolve_screen(document, screen_key, root) do
      {:ok, screen, diagnostics} ->
        Validation.validate(screen, diagnostics, root["responses"], pressed_button_key)

      {:error, :no_such_screen} = no_such_screen ->
        no_such_screen
    end
  end

  # -- screens ---------------------------------------------------------------

  defp normalize(root) do
    %{
      "context" => submap(root, "context"),
      "responses" => submap(root, "responses")
    }
  end

  defp submap(root, key) do
    case Map.get(root, key) do
      map when is_map(map) and not is_struct(map) -> map
      _absent -> %{}
    end
  end

  defp resolve_one(screen, root, diagnostics) do
    {nodes, diagnostics} = resolve_nodes(screen.nodes, root, diagnostics)
    {%{key: screen.key, title: screen.title, nodes: nodes}, diagnostics}
  end

  # -- nodes -----------------------------------------------------------------

  defp resolve_nodes(nodes, root, diagnostics) do
    {resolved, diagnostics} =
      Enum.reduce(nodes, {[], diagnostics}, fn node, {acc, diagnostics} ->
        case shown(node, root, diagnostics) do
          {nil, diagnostics} -> {acc, diagnostics}
          {resolved, diagnostics} -> {[resolved | acc], diagnostics}
        end
      end)

    {Enum.reverse(resolved), diagnostics}
  end

  # A node is shown, or it is not and `nil` says so. The two reasons it is not
  # are different things: a false condition is silent, an undecidable one is
  # reported, and a container that no candidate won is neither - the container
  # asked a question and every answer was no.
  defp shown(node, root, diagnostics) do
    case decide(node, root, diagnostics) do
      {true, diagnostics} -> present(node, root, diagnostics)
      {false, diagnostics} -> {nil, diagnostics}
    end
  end

  defp present(node, root, diagnostics) do
    case Map.fetch(node, :nodes) do
      {:ok, candidates} when is_list(candidates) -> winner(candidates, root, diagnostics)
      _not_a_container -> render(Map.delete(node, :condition), root, diagnostics)
    end
  end

  # First match wins: the candidates are considered in order and the first
  # whose condition holds replaces the container.
  defp winner([], _root, diagnostics), do: {nil, diagnostics}

  defp winner([candidate | rest], root, diagnostics) do
    case decide(candidate, root, diagnostics) do
      {true, diagnostics} -> present(candidate, root, diagnostics)
      {false, diagnostics} -> winner(rest, root, diagnostics)
    end
  end

  # -- conditions ------------------------------------------------------------

  defp decide(node, root, diagnostics) do
    case Map.fetch(node, :condition) do
      {:ok, condition} -> evaluate(condition, node[:key], root, diagnostics)
      :error -> {true, diagnostics}
    end
  end

  defp evaluate(condition, key, root, diagnostics) when is_binary(condition) do
    case Predicator.evaluate(condition, root) do
      {:ok, true} -> {true, diagnostics}
      {:ok, false} -> {false, diagnostics}
      _undecidable -> {false, undecidable(diagnostics, key, condition)}
    end
  end

  defp evaluate(condition, key, _root, diagnostics),
    do: {false, undecidable(diagnostics, key, condition)}

  defp undecidable(diagnostics, key, condition) do
    Map.update!(diagnostics, :undecidable_conditions, fn reported ->
      [%{key: key, condition: condition} | reported]
    end)
  end

  # -- templates -------------------------------------------------------------

  defp render(node, root, diagnostics) do
    # The list is the document's - `Riddler.Screens.Document.template_fields/0`.
    # Rendering and refusing are two passes over the same fields, and a field
    # added there is rendered here without a second edit.
    Enum.reduce(Document.template_fields(), {node, diagnostics}, fn field, {node, diagnostics} ->
      case Map.fetch(node, field) do
        {:ok, source} when is_binary(source) ->
          render_field(node, field, source, root, diagnostics)

        _absent ->
          {node, diagnostics}
      end
    end)
  end

  defp render_field(node, field, source, root, diagnostics) do
    with {:ok, compiled} <- Template.compile(source),
         {:ok, text, missing} <- Template.render(compiled, root, :lenient) do
      {Map.put(node, field, text), missing(diagnostics, node[:key], missing)}
    else
      # A template that does not compile is a document finding, raised before a
      # visitor arrives. Resolution neither repeats it nor invents text for it:
      # the source stands, and the author is told by `validate/1`.
      _refused -> {node, diagnostics}
    end
  end

  defp missing(diagnostics, _key, []), do: diagnostics

  defp missing(diagnostics, key, variables) do
    Map.update!(diagnostics, :missing_variables, fn reported ->
      Enum.reduce(variables, reported, &[%{key: key, variable: &1} | &2])
    end)
  end

  # Both lists are built by prepending, so both are reversed once at the end
  # and come back in document order.
  defp order(diagnostics) do
    %{
      missing_variables: Enum.reverse(diagnostics.missing_variables),
      undecidable_conditions: Enum.reverse(diagnostics.undecidable_conditions)
    }
  end
end
