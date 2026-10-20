defmodule Riddler.Journey do
  @moduledoc """
  A Journey's step as data: a screen, waiting, or done.

  A Journey is one visitor's execution through a set of screens, and the
  execution is the host's: its workflow engine waits for the visitor, waits
  on a back office, and moves from one screen to the next. This module gives
  the host one answer to carry to a client at each step, whatever the host
  is, and one rule for the context it sends as the Journey goes on.

  Both functions are pure. They consult no store, start no process, keep no
  state between calls and read no execution; there is no behaviour to
  implement and nothing here calls the host back. Which step comes next,
  where a root is kept, how an answer reaches a client and which visitor a
  Journey belongs to are the host's.

  ## The status

  The host maps its execution onto one of three values and passes it:

    * `{:screen, key}` - the visitor is to be shown the screen the document
      declares under `key`;
    * `:waiting` - the execution is waiting on something that is not the
      visitor;
    * `:done` - the execution has finished.

  `present/3` answers a string-keyed map whose `"state"` is `"screen"`,
  `"waiting"` or `"done"`, with `"screen"` beside it exactly when the state
  is a screen. String keys throughout, so the answer can be put on any wire
  as JSON as it stands.

  ## The root

  The root is the one every `Riddler.Screens` function takes: `"context"`,
  what the host knows, and `"responses"`, what the visitor has submitted so
  far. `put_context/2` replaces its `"context"` whole each time the host
  sends a new one, and leaves the responses as they were.

  ## Example

  Patron registration: a visitor gets a library card.

      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 1,
      ...>     "id" => "patron_registration",
      ...>     "screens" => [
      ...>       %{
      ...>         "key" => "patron_details",
      ...>         "title" => "Get your library card",
      ...>         "nodes" => [
      ...>           %{
      ...>             "type" => "text",
      ...>             "key" => "welcome_back",
      ...>             "condition" => "context.returning == 'yes'",
      ...>             "text" => "Welcome back, {{ context.first_name }}."
      ...>           }
      ...>         ]
      ...>       }
      ...>     ]
      ...>   })
      iex> root = %{"context" => %{"returning" => "yes", "first_name" => "Ada"}}
      iex> {:ok, %{"state" => "screen", "screen" => screen}} =
      ...>   Riddler.Journey.present(document, {:screen, "patron_details"}, root)
      iex> Enum.map(screen["nodes"], & &1["text"])
      ["Welcome back, Ada."]
      iex> Riddler.Journey.present(document, :waiting, root)
      {:ok, %{"state" => "waiting"}}
      iex> {:ok, root} = Riddler.Journey.put_context(root, %{"first_name" => "Ada"})
      iex> {:ok, %{"screen" => screen}} =
      ...>   Riddler.Journey.present(document, {:screen, "patron_details"}, root)
      iex> {screen["nodes"], screen["diagnostics"]["undecidable_conditions"]}
      {[], [%{"key" => "welcome_back", "condition" => "context.returning == 'yes'"}]}
  """

  alias Riddler.Encoding
  alias Riddler.Screens
  alias Riddler.Screens.Document

  @typedoc "Where the host's execution is for the visitor."
  @type status :: {:screen, screen_key :: term()} | :waiting | :done

  @typedoc """
  The root every `Riddler.Screens` function takes: `"context"` and
  `"responses"`, each a string-keyed map. Other keys are carried and never
  read.
  """
  @type root :: map()

  @typedoc """
  `"state"` => `"screen"` | `"waiting"` | `"done"`, and, only when `"state"`
  is `"screen"`, `"screen"` => `t:screen/0`.
  """
  @type answer :: %{required(String.t()) => String.t() | screen()}

  @typedoc """
  `"key"`, `"title"`, `"nodes"` (the resolved nodes, string-keyed) and
  `"diagnostics"` => `%{"missing_variables" => [...],
  "undecidable_conditions" => [...]}`.
  """
  @type screen :: %{required(String.t()) => term()}

  @doc """
  The answer for the status the host passes.

  For `{:screen, key}`, the screen `Riddler.Screens.resolve_screen/3`
  resolves for that key and root, in data form: `"key"`, `"title"` and
  `"nodes"` as resolution leaves them - hidden nodes absent, each container
  collapsed to its winner, every template field rendered, no `condition`
  anywhere, `writes` carried through - and `"diagnostics"`, with
  `"missing_variables"` and `"undecidable_conditions"` in document order. The
  diagnostics ride inside the screen, so a caller is never handed a screen
  without the report of resolving it.

  For `:waiting` and `:done` the answer is the state alone, and the document
  is not read.

  A key the document does not declare is `{:error, :no_such_screen}`, the
  answer `Riddler.Screens.resolve_screen/3` gives for it. A status outside the
  three is `{:error, :unknown_status}`, so a host that builds its status from
  its own data is told rather than handed an exception.

  The root is read for `"context"` and `"responses"` and nothing else; an
  absent half is an empty map. No responses are checked here: whether a
  screen may be submitted is `Riddler.Screens.validate_screen/3,4`'s.

      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 1,
      ...>     "id" => "patron_registration",
      ...>     "screens" => [
      ...>       %{
      ...>         "key" => "patron_details",
      ...>         "title" => "Get your library card",
      ...>         "nodes" => [
      ...>           %{
      ...>             "type" => "button",
      ...>             "key" => "details_next",
      ...>             "label" => "Continue",
      ...>             "outcome" => "details_submitted"
      ...>           }
      ...>         ]
      ...>       }
      ...>     ]
      ...>   })
      iex> Riddler.Journey.present(document, {:screen, "patron_details"}, %{})
      {:ok,
       %{
         "state" => "screen",
         "screen" => %{
           "key" => "patron_details",
           "title" => "Get your library card",
           "nodes" => [
             %{
               "type" => "button",
               "key" => "details_next",
               "label" => "Continue",
               "outcome" => "details_submitted"
             }
           ],
           "diagnostics" => %{"missing_variables" => [], "undecidable_conditions" => []}
         }
       }}
      iex> Riddler.Journey.present(document, :done, %{})
      {:ok, %{"state" => "done"}}
      iex> Riddler.Journey.present(document, {:screen, "card_pickup"}, %{})
      {:error, :no_such_screen}
      iex> Riddler.Journey.present(document, :card_issued, %{})
      {:error, :unknown_status}
  """
  @spec present(Document.t(), term(), root()) ::
          {:ok, answer()} | {:error, :no_such_screen} | {:error, :unknown_status}
  def present(%Document{} = document, {:screen, key}, root) when is_map(root) do
    case Screens.resolve_screen(document, key, root) do
      {:ok, screen, diagnostics} ->
        {:ok, %{"state" => "screen", "screen" => screen_data(screen, diagnostics)}}

      {:error, :no_such_screen} = no_such_screen ->
        no_such_screen
    end
  end

  def present(%Document{}, :waiting, root) when is_map(root), do: {:ok, %{"state" => "waiting"}}
  def present(%Document{}, :done, root) when is_map(root), do: {:ok, %{"state" => "done"}}
  def present(%Document{}, _status, root) when is_map(root), do: {:error, :unknown_status}

  @doc """
  The root with its `"context"` replaced by `context`, whole.

  Nothing is merged: a key the previous context held and the new one does
  not is gone, which is what lets a host withdraw a flag by leaving it out.
  `"responses"` and every other key of the root are left exactly as they
  were, and a root with no `"context"` gets one.

  A context that is not a map is `{:error, :context_not_a_map}`, and so is a
  struct: `Riddler.Screens` reads a context that is not a plain map as an
  empty one, so putting one would answer a root every later call reads as
  carrying no context at all.

      iex> root = %{
      ...>   "context" => %{"first_name" => "Ada", "card_pending" => true},
      ...>   "responses" => %{"reminder_email" => "ada@example.com"}
      ...> }
      iex> Riddler.Journey.put_context(root, %{"first_name" => "Ada", "card_number" => "2915 0001 2345"})
      {:ok,
       %{
         "context" => %{"first_name" => "Ada", "card_number" => "2915 0001 2345"},
         "responses" => %{"reminder_email" => "ada@example.com"}
       }}
      iex> Riddler.Journey.put_context(root, ["first_name", "Ada"])
      {:error, :context_not_a_map}
  """
  @spec put_context(root(), term()) :: {:ok, root()} | {:error, :context_not_a_map}
  def put_context(root, context) when is_map(root) and is_map(context) and not is_struct(context),
    do: {:ok, Map.put(root, "context", context)}

  def put_context(root, _context) when is_map(root), do: {:error, :context_not_a_map}

  defp screen_data(screen, diagnostics) do
    screen
    |> Map.put(:diagnostics, diagnostics)
    |> Encoding.to_data()
  end
end
