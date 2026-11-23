defmodule Riddler.Journey do
  @moduledoc """
  A Journey's step as data: a screen, waiting, or done.

  A Journey is one visitor's execution through a set of screens, and the
  execution is the host's: its workflow engine waits for the visitor, waits
  on a back office, and moves from one screen to the next. This module gives
  the host one answer to carry to a client at each step, whatever the host
  is, one rule for the context it sends as the Journey goes on, and one check
  of the shape of what a client sends back.

  Every function here is pure. They consult no store, start no process, keep
  no state between calls and read no execution; there is no behaviour to
  implement and nothing here calls the host back. Which step comes next,
  where a root is kept, how an answer reaches a client and which visitor a
  Journey belongs to are the host's.

  ## The status

  The host maps its execution onto one of three values and passes it:

    * `{:screen, key}`, or `{:screen, key, opts}` - the visitor is to be
      shown the screen the document declares under `key`, and `opts` may say
      that the host lets the visitor go back from it, and how far through
      the Journey the visitor is;
    * `:waiting`, or `{:waiting, info}` - the execution is waiting on
      something that is not the visitor, and `info` may say why and when a
      client should ask again;
    * `:done`, or `{:done, result}` - the execution has finished, and
      `result` is what the host has to show for it.

  `present/3` answers a string-keyed map whose `"state"` is `"screen"`,
  `"waiting"` or `"done"`, with `"screen"` and `"moves"` beside it exactly
  when the state is a screen, `"progress"` beside a screen state exactly when
  the host supplied it, `"reason"` and `"retry_after_ms"` beside a waiting state
  exactly when the host supplied them, and `"result"` beside a done state
  exactly when the host supplied one. String keys throughout, so the answer
  can be put on any wire as JSON as it stands.

  ## The root

  The root is the one every `Riddler.Screens` function takes: `"context"`,
  what the host knows, and `"responses"`, what the visitor has submitted so
  far. `put_context/2` replaces its `"context"` whole each time the host
  sends a new one, and leaves the responses as they were.

  ## The submit

  What a client sends back when the visitor presses a button is a submit: a
  JSON object of three keys, `"screen"`, the key of the screen it was shown,
  `"outcome"`, the outcome of the button pressed, and `"responses"`, what the
  visitor entered on that screen, keyed by question key. `decode_submit/1`
  checks that shape and nothing else; that the screen is the one the host's
  execution is at and that the outcome is among the moves it presented are
  the host's checks, before it validates the responses with
  `Riddler.Screens.validate_screen/3,4`.

  What a client sends when the visitor goes back from a screen presented
  with `"back"` true is a back request: `"screen"`, the key of the screen it
  was shown, and `"back"`, `true`, with no `"outcome"`, since going back
  presses no button. `decode_submit/1` tells the two apart and checks the
  back request's shape too. Which screen going back reaches is the host's
  engine's: the host raises its engine's back event, and the responses the
  root already holds stay as they are.

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
  alias Riddler.Finding
  alias Riddler.Screens
  alias Riddler.Screens.Document

  @submit_keys ["screen", "outcome", "responses"]

  @typedoc "Where the host's execution is for the visitor."
  @type status ::
          {:screen, screen_key :: term()}
          | {:screen, screen_key :: term(), screen_opts()}
          | :waiting
          | {:waiting, waiting_info()}
          | :done
          | {:done, result :: map()}

  @typedoc """
  Optionally `"back"` => `t:boolean/0` and `"progress"` => `%{"step" =>
  t:pos_integer/0, "of" => t:pos_integer/0}`. Other keys are not read.
  """
  @type screen_opts :: map()

  @typedoc """
  Optionally `"reason"` => `t:String.t/0` and `"retry_after_ms"` =>
  `t:non_neg_integer/0`. Other keys are not read.
  """
  @type waiting_info :: map()

  @typedoc """
  The root every `Riddler.Screens` function takes: `"context"` and
  `"responses"`, each a string-keyed map. Other keys are carried and never
  read.
  """
  @type root :: map()

  @typedoc """
  `"state"` => `"screen"` | `"waiting"` | `"done"`; only when `"state"` is
  `"screen"`, `"screen"` => `t:screen/0` and `"moves"` => `t:moves/0`, and,
  only where the host supplied it, `"progress"` => `%{"step" =>
  t:pos_integer/0, "of" => t:pos_integer/0}`; only on a waiting answer, and
  each only where the host supplied it, `"reason"`
  => `t:String.t/0` and `"retry_after_ms"` => `t:non_neg_integer/0`; and
  only on a done answer, and only where the host supplied it, `"result"` =>
  `t:map/0`.
  """
  @type answer :: %{
          required(String.t()) => String.t() | non_neg_integer() | screen() | moves() | map()
        }

  @typedoc """
  `"outcomes"` => `[t:String.t/0]`, the outcome of each shown button in
  document order, and `"back"` => `t:boolean/0`.
  """
  @type moves :: %{required(String.t()) => [String.t()] | boolean()}

  @typedoc """
  `"key"`, `"title"`, `"nodes"` (the resolved nodes, string-keyed) and
  `"diagnostics"` => `%{"missing_variables" => [...],
  "undecidable_conditions" => [...]}`.
  """
  @type screen :: %{required(String.t()) => term()}

  @typedoc """
  `"screen"` => `t:String.t/0`, `"outcome"` => `t:String.t/0` and
  `"responses"` => `t:map/0`, and no other key.
  """
  @type submit :: %{required(String.t()) => String.t() | map()}

  @typedoc """
  `"screen"` => `t:String.t/0` and `"back"` => `true`, and no other key.
  """
  @type back_request :: %{required(String.t()) => String.t() | true}

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

  Beside `"screen"` the answer carries `"moves"`, what a client may submit
  from that screen, so that a client reads it and never derives it from the
  nodes. `"outcomes"` is the `outcome` of each button among the screen's
  `"nodes"`, in document order: a button a condition hid, or a candidate that
  did not win its container, is not among them, and a screen that shows no
  button lists `[]`. No two buttons a screen can show together raise one
  outcome in a document `Riddler.Screens.Document.validate/1` accepts, so no
  outcome is listed twice. `"back"` is `true` exactly when the host passed
  `{:screen, key, opts}` with `"back"` true in `opts`, and `false`
  otherwise. `opts` is a string-keyed map; a key it carries beside `"back"`
  and `"progress"` is not read and nothing of it reaches the answer, so
  `{:screen, key, %{}}` answers exactly what `{:screen, key}` answers.

  Beside `"moves"` the answer carries `"progress"`, `%{"step" => n, "of" =>
  m}`, exactly when `opts` carries a `"progress"`: a map of `"step"` and
  `"of"`, each an integer of at least 1, with `"step"` not above `"of"`. A
  key the progress map carries beside those two is not read and nothing of
  it reaches the answer. Where `opts` carries no `"progress"`, the answer has
  no `"progress"` key. This module counts no steps: how far through a Path a
  visitor is, is the host's engine's to know, and a client draws progress
  only when the answer carries it.

  A text, choice or boolean question's node carries `"value"` where a
  response the root holds, its prefill or its default yields one, as
  `Riddler.Screens` describes, and never its `"default"` or `"prefill"`.

  A secret question's node carries `"held"`, `true` where the root holds the
  sealed form for it and `false` otherwise, and nothing more of its response:
  the plaintext a visitor typed and the sealed string a host keeps are nowhere
  in the answer.

  For `:waiting` and `:done` the answer is the state alone, and the document
  is not read.

  For `{:waiting, info}` the answer is the waiting state with `"reason"` and
  `"retry_after_ms"` beside it, each only where `info` carries it: `info` is a
  string-keyed map whose `"reason"`, where present, is a string saying why the
  execution waits, and whose `"retry_after_ms"`, where present, is a
  non-negative integer, the milliseconds the host suggests a client waits
  before it asks again. A key `info` carries beside those two is not read and
  nothing of it reaches the answer, so `{:waiting, %{}}` answers exactly what
  `:waiting` answers. The document is not read here either.

  For `{:done, result}` the answer is the done state with `"result"` beside
  it: `result` is the host's map, carried whole in the answer's data form -
  a struct inside it becomes a map, an atom key a string, and an atom value
  other than `true`, `false` and `nil` a string - and nothing in it is read.
  That it holds only what JSON can carry once so encoded is the host's to
  keep, as the context's is. `{:done, %{}}` answers `"result"` as an empty
  map. The document is not read here either.

  A key the document does not declare is `{:error, :no_such_screen}`, the
  answer `Riddler.Screens.resolve_screen/3` gives for it. A status outside the
  three is `{:error, :unknown_status}`, so a host that builds its status from
  its own data is told rather than handed an exception. So is `{:screen,
  key, opts}` whose `opts` is not a map (a struct included), whose `"back"`
  is not a boolean, or whose `"progress"` is not a map (a struct included),
  lacks `"step"` or `"of"`, or carries one that is not an integer or is
  below 1, or a `"step"` above `"of"`, whatever `key` names. So is `{:waiting,
  info}` whose `info` is not a map (a struct included), whose `"reason"` is
  not a string, or whose `"retry_after_ms"` is not an integer or is below
  zero, and so is `{:done, result}` whose `result` is not a map (a struct
  included).

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
         },
         "moves" => %{"outcomes" => ["details_submitted"], "back" => false}
       }}
      iex> {:ok, %{"moves" => moves}} =
      ...>   Riddler.Journey.present(document, {:screen, "patron_details", %{"back" => true}}, %{})
      iex> moves
      %{"outcomes" => ["details_submitted"], "back" => true}
      iex> Riddler.Journey.present(document, {:screen, "patron_details", %{"back" => "yes"}}, %{})
      {:error, :unknown_status}
      iex> Riddler.Journey.present(
      ...>   document,
      ...>   {:waiting, %{"reason" => "card_number_pending", "retry_after_ms" => 5000}},
      ...>   %{}
      ...> )
      {:ok, %{"state" => "waiting", "reason" => "card_number_pending", "retry_after_ms" => 5000}}
      iex> Riddler.Journey.present(document, {:waiting, %{"retry_after_ms" => -1}}, %{})
      {:error, :unknown_status}
      iex> Riddler.Journey.present(document, :done, %{})
      {:ok, %{"state" => "done"}}
      iex> Riddler.Journey.present(document, {:done, %{"card_number" => "EXAMPLE-CARD-0001"}}, %{})
      {:ok, %{"state" => "done", "result" => %{"card_number" => "EXAMPLE-CARD-0001"}}}
      iex> Riddler.Journey.present(document, {:done, ["EXAMPLE-CARD-0001"]}, %{})
      {:error, :unknown_status}
      iex> Riddler.Journey.present(document, {:screen, "card_pickup"}, %{})
      {:error, :no_such_screen}
      iex> Riddler.Journey.present(document, :card_issued, %{})
      {:error, :unknown_status}
  """
  @spec present(Document.t(), term(), root()) ::
          {:ok, answer()} | {:error, :no_such_screen} | {:error, :unknown_status}
  def present(%Document{} = document, {:screen, key}, root) when is_map(root),
    do: present_screen(document, key, false, nil, root)

  def present(%Document{} = document, {:screen, key, opts}, root) when is_map(root) do
    with {:ok, back} <- back(opts),
         {:ok, progress} <- progress(opts) do
      present_screen(document, key, back, progress, root)
    else
      :error -> {:error, :unknown_status}
    end
  end

  def present(%Document{}, :waiting, root) when is_map(root), do: {:ok, %{"state" => "waiting"}}

  def present(%Document{}, {:waiting, info}, root) when is_map(root) do
    case waiting_data(info) do
      {:ok, data} -> {:ok, Map.put(data, "state", "waiting")}
      :error -> {:error, :unknown_status}
    end
  end

  def present(%Document{}, :done, root) when is_map(root), do: {:ok, %{"state" => "done"}}

  def present(%Document{}, {:done, result}, root)
      when is_map(root) and is_map(result) and not is_struct(result),
      do: {:ok, %{"state" => "done", "result" => Encoding.to_data(result)}}

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

  @doc """
  The submit or the back request a client sent, checked for its shape.

  `submit` is the submit as decoded data: a host decodes the bytes it
  received into a term, and how they arrive is the transport's. The answer is
  `{:ok, submit}`, the string-keyed map of exactly `"screen"`, `"outcome"` and
  `"responses"`, each value as the client sent it - a key the client sent
  beside them is dropped - or `{:ok, back_request}` for a back request, or
  `{:error, findings}`.

  A map that carries no `"outcome"` and whose `"back"` is `true` is a back
  request. Its `"screen"` is checked as a submit's is, raising
  `submit.missing_field` when it is absent and `submit.invalid_field` when it
  is not a string, and the answer is `{:ok, %{"screen" => key, "back" =>
  true}}`: every other key the client sent beside them, a `"responses"`
  included, is dropped. Every other value is a submit, decoded as below: a
  map carrying `"outcome"` is a submit whatever its `"back"` holds, and
  `"back"` is dropped as a key beside the three; a map with no `"outcome"`
  whose `"back"` is anything but `true` is a submit with no outcome.

  A value that is not a map, a struct included, is the one finding
  `submit.not_an_object`, its `:field` `nil`. Otherwise each of the three keys
  is checked, in the order `"screen"`, `"outcome"`, `"responses"`, and each
  that fails raises one finding, so a client learns every defect in one pass:
  `submit.missing_field` for a key the map does not carry, and
  `submit.invalid_field` for a `"screen"` or `"outcome"` that is not a string
  or a `"responses"` that is not a map (a struct included). The `:field` of
  either names the key; `:node_key` and `:position` are `nil`.

  No document and no execution is read, so the screen is not compared with
  the screen the host's execution is at and the outcome is not checked
  against the moves the host presented: both are the host's checks. The
  responses are not looked into: what they have to satisfy is
  `Riddler.Screens.validate_screen/3,4`'s. Nothing a client can send makes
  this raise.

  Patron registration: the visitor gives an email for due-date reminders and
  presses Continue.

      iex> Riddler.Journey.decode_submit(%{
      ...>   "screen" => "patron_details",
      ...>   "outcome" => "details_submitted",
      ...>   "responses" => %{"reminder_email" => "ada@example.com"},
      ...>   "sent_at" => "2026-11-18T10:00:00Z"
      ...> })
      {:ok,
       %{
         "screen" => "patron_details",
         "outcome" => "details_submitted",
         "responses" => %{"reminder_email" => "ada@example.com"}
       }}
      iex> {:error, findings} =
      ...>   Riddler.Journey.decode_submit(%{
      ...>     "screen" => "patron_details",
      ...>     "responses" => ["ada@example.com"]
      ...>   })
      iex> Enum.map(findings, &{&1.code, &1.field})
      [{"submit.missing_field", "outcome"}, {"submit.invalid_field", "responses"}]
      iex> {:error, [finding]} = Riddler.Journey.decode_submit("patron_details")
      iex> {finding.code, finding.field}
      {"submit.not_an_object", nil}

  The visitor picks how the library card reaches them on `card_delivery`,
  then goes back before pressing Continue. What they picked is dropped:

      iex> Riddler.Journey.decode_submit(%{
      ...>   "screen" => "card_delivery",
      ...>   "back" => true,
      ...>   "responses" => %{"delivery_method" => "mail"}
      ...> })
      {:ok, %{"screen" => "card_delivery", "back" => true}}
      iex> {:error, [finding]} = Riddler.Journey.decode_submit(%{"back" => true})
      iex> {finding.code, finding.field}
      {"submit.missing_field", "screen"}

  An outcome beside `"back"` is a submit, and a `"back"` that is not `true`
  is a submit with no outcome:

      iex> Riddler.Journey.decode_submit(%{
      ...>   "screen" => "card_delivery",
      ...>   "back" => true,
      ...>   "outcome" => "delivery_chosen",
      ...>   "responses" => %{"delivery_method" => "mail"}
      ...> })
      {:ok,
       %{
         "screen" => "card_delivery",
         "outcome" => "delivery_chosen",
         "responses" => %{"delivery_method" => "mail"}
       }}
      iex> {:error, findings} =
      ...>   Riddler.Journey.decode_submit(%{"screen" => "card_delivery", "back" => "yes"})
      iex> Enum.map(findings, &{&1.code, &1.field})
      [{"submit.missing_field", "outcome"}, {"submit.missing_field", "responses"}]
  """
  @spec decode_submit(term()) ::
          {:ok, submit() | back_request()} | {:error, [Finding.t()]}
  def decode_submit(submit) when is_map(submit) and not is_struct(submit) do
    if back_request?(submit) do
      case submit_findings(submit, "screen", "back request") do
        [] -> {:ok, %{"screen" => Map.fetch!(submit, "screen"), "back" => true}}
        findings -> {:error, findings}
      end
    else
      case Enum.flat_map(@submit_keys, &submit_findings(submit, &1, "submit")) do
        [] -> {:ok, Map.take(submit, @submit_keys)}
        findings -> {:error, findings}
      end
    end
  end

  def decode_submit(_submit) do
    {:error, [%Finding{code: "submit.not_an_object", message: "the submit is not a JSON object"}]}
  end

  # A back request is a map with no "outcome" whose "back" is exactly true;
  # any other "back" leaves the map a submit.
  defp back_request?(submit),
    do: Map.get(submit, "back") === true and not Map.has_key?(submit, "outcome")

  defp submit_findings(submit, key, shape) do
    case Map.fetch(submit, key) do
      :error ->
        [submit_finding("submit.missing_field", key, "the #{shape} carries no #{inspect(key)}")]

      {:ok, value} ->
        if submit_value?(key, value),
          do: [],
          else: [
            submit_finding(
              "submit.invalid_field",
              key,
              "the #{shape}'s #{inspect(key)} is not #{submit_kind(key)}"
            )
          ]
    end
  end

  defp submit_value?("responses", value), do: is_map(value) and not is_struct(value)
  defp submit_value?(_key, value), do: is_binary(value)

  defp submit_kind("responses"), do: "an object"
  defp submit_kind(_key), do: "a string"

  defp submit_finding(code, key, message), do: %Finding{code: code, field: key, message: message}

  # The waiting info's two keys, each kept only where the host supplied it
  # and each of its type; any other key is not read. A map that carries
  # either of the two with the wrong type, and anything that is not a plain
  # map, is `:error`, which `present/3` answers as a status outside the shapes.
  defp waiting_data(info) when is_map(info) and not is_struct(info) do
    data = Map.take(info, ["reason", "retry_after_ms"])

    if Enum.all?(data, fn {key, value} -> waiting_value?(key, value) end),
      do: {:ok, data},
      else: :error
  end

  defp waiting_data(_info), do: :error

  defp waiting_value?("reason", value), do: is_binary(value)
  defp waiting_value?("retry_after_ms", value), do: is_integer(value) and value >= 0

  defp present_screen(document, key, back, progress, root) do
    case Screens.resolve_screen(document, key, root) do
      {:ok, screen, diagnostics} ->
        answer = %{
          "state" => "screen",
          "screen" => screen_data(screen, diagnostics),
          "moves" => %{"outcomes" => outcomes(screen), "back" => back}
        }

        {:ok, put_progress(answer, progress)}

      {:error, :no_such_screen} = no_such_screen ->
        no_such_screen
    end
  end

  # The screen options' back key, kept only where it is a boolean; the
  # progress key is `progress/1`'s, and any other key is not read. A map that
  # carries `"back"` with another type, and anything that is not a plain map,
  # is `:error`, which `present/3` answers as a status outside the shapes.
  defp back(opts) when is_map(opts) and not is_struct(opts) do
    case Map.fetch(opts, "back") do
      {:ok, back} when is_boolean(back) -> {:ok, back}
      {:ok, _not_a_boolean} -> :error
      :error -> {:ok, false}
    end
  end

  defp back(_opts), do: :error

  # The screen options' progress, kept only where it is a plain map whose
  # `"step"` and `"of"` are integers of at least 1, `"step"` not above
  # `"of"`, and carried as those two keys alone; any other key of it is not
  # read. Absent, it is `nil`, and the answer carries no progress. Anything
  # else is `:error`, which `present/3` answers as a status outside the
  # shapes. `back/1` has already refused opts that are not a plain map.
  defp progress(opts) do
    case Map.fetch(opts, "progress") do
      {:ok, %{"step" => step, "of" => of} = progress}
      when not is_struct(progress) and is_integer(step) and is_integer(of) and step >= 1 and
             step <= of ->
        {:ok, %{"step" => step, "of" => of}}

      {:ok, _malformed} ->
        :error

      :error ->
        {:ok, nil}
    end
  end

  defp put_progress(answer, nil), do: answer
  defp put_progress(answer, progress), do: Map.put(answer, "progress", progress)

  # The outcome of each shown button, read from the resolved screen, where
  # hidden nodes are absent and every container is already its winner. Only
  # a document `validate/1` refuses can carry a shown button whose outcome is
  # not a string, or two shown buttons raising one outcome; for such a
  # document each string outcome is listed once, at its first button, so the
  # list stays what the presented answer's schema says it is.
  defp outcomes(screen) do
    for %{type: "button", outcome: outcome} <- screen.nodes,
        is_binary(outcome),
        uniq: true,
        do: outcome
  end

  defp screen_data(screen, diagnostics) do
    screen
    |> Map.put(:diagnostics, diagnostics)
    |> Encoding.to_data()
  end
end
