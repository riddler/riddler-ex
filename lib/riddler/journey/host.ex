defmodule Riddler.Journey.Host do
  @moduledoc """
  The host's own loop, as a behaviour: the four callbacks a renderer drives
  any host through.

  A host implements this behaviour to start a Journey, say where one is,
  take a submit and take a back request; this package calls none of the
  callbacks. It steps nothing, keeps nothing and moves no Journey. The
  Journey is named by a string the host chooses, which this package never
  reads.

  | Callback | What the host answers |
  |---|---|
  | `c:start/2` | `{:ok, journey, answer}` for the Journey it started, or `{:error, :no_such_journey}` |
  | `c:present/1` | `{:ok, scope, answer}`, the Journey's scope beside where it is, or `{:error, :no_such_journey}` |
  | `c:submit/2` | `{:ok, answer}`, `{:error, findings}`, or `{:error, :no_such_journey}` |
  | `c:back/2` | `{:ok, answer}`, `{:error, findings}`, or `{:error, :no_such_journey}` |

  `answer` is what `Riddler.Journey.present/3` answers inside `{:ok, ...}`
  for the status the host's engine gives. The submit and the back request a
  host is handed are what `Riddler.Journey.decode_submit/1` answers inside
  `{:ok, ...}`. The findings are `Riddler.Finding` structs: a submit's
  refused by `Riddler.Journey.decode_submit/1`, or a screen's refused by
  `Riddler.Screens.validate_screen/3,4`.

  `c:start/2` answers the refusal for a Path the host does not have and for
  a scope whose kind is not the Path's; the three others answer it for a
  Journey the host does not have. It is the refusal
  `Riddler.Journey.Access.check/4` gives, so a renderer shows one thing for
  both. `c:present/1` answers the scope so that a renderer has it for its
  check on mount, and holds it for the checks after, since a scope does not
  change once the Journey starts.

  ## What a renderer asks, and when

  A renderer asks `Riddler.Journey.Access.check/4` with the Journey's scope:

    * before a start, with `:present` and the scope the Journey is to be
      started under, before `c:start/2` is called, so that no Journey is
      started under a scope the actor does not belong to;
    * on mount, with `:present`, after `c:present/1` and before anything of
      the answer is shown;
    * on every submit, with `:submit`, before `c:submit/2` is called;
    * on every back, with `:back`, before `c:back/2` is called.

  On `{:error, :no_such_journey}` it shows the one refusal, shows nothing of
  the Journey, and calls no callback that would start or step it. It asks
  again on every submit and every back rather than once, because whether an
  actor belongs to a scope is the host's, and can change while a Journey is
  open. This package renders nothing and sees no renderer, so it cannot
  enforce the order: it is the contract a renderer is built to.

  ## Example

  Patron registration: the library's host implements the four callbacks
  over its own engine and its own Path records. What each body does is the
  host's; only the answers are this behaviour's:

      defmodule Library.RegistrationHost do
        @behaviour Riddler.Journey.Host

        @impl true
        def start(path, scope) do
          # {:ok, journey, answer}, or {:error, :no_such_journey} for a Path
          # the host does not have, or when
          # Riddler.Journey.Access.check_kind(scope, kind) refuses the
          # scope against the kind the Path's record names.
        end

        @impl true
        def present(journey) do
          # {:ok, scope, answer}, or {:error, :no_such_journey}.
        end

        @impl true
        def submit(journey, submit) do
          # {:ok, answer}, {:error, findings}, or {:error, :no_such_journey}.
        end

        @impl true
        def back(journey, back_request) do
          # {:ok, answer}, {:error, findings}, or {:error, :no_such_journey}.
        end
      end
  """

  alias Riddler.Journey
  alias Riddler.Journey.Scope

  @typedoc "The host's own name for a Journey, which this package never reads."
  @type journey :: String.t()

  @doc """
  Starts a Journey of the Path named `path` under `scope`, and answers
  `{:ok, journey, answer}`: the host's name for the Journey and what
  `Riddler.Journey.present/3` answers for where it starts. Answers
  `{:error, :no_such_journey}` for a Path the host does not have and for a
  scope whose kind is not the Path's.
  """
  @callback start(path :: String.t(), Scope.t()) ::
              {:ok, journey(), Journey.answer()} | {:error, :no_such_journey}

  @doc """
  Where the Journey named `journey` is: `{:ok, scope, answer}`, the scope it
  was started under beside what `Riddler.Journey.present/3` answers for it.
  Answers `{:error, :no_such_journey}` for a Journey the host does not have.
  """
  @callback present(journey()) ::
              {:ok, Scope.t(), Journey.answer()} | {:error, :no_such_journey}

  @doc """
  Takes a submit, as `Riddler.Journey.decode_submit/1` answers it, for the
  Journey named `journey`. Answers `{:ok, answer}` for where the Journey is
  after it, `{:error, findings}` for a submit or a screen refused, or
  `{:error, :no_such_journey}` for a Journey the host does not have.
  """
  @callback submit(journey(), Journey.submit()) ::
              {:ok, Journey.answer()}
              | {:error, [Riddler.Finding.t()]}
              | {:error, :no_such_journey}

  @doc """
  Takes a back request, as `Riddler.Journey.decode_submit/1` answers it, for
  the Journey named `journey`. Answers `{:ok, answer}` for where the Journey
  is after it, `{:error, findings}`, or `{:error, :no_such_journey}` for a
  Journey the host does not have.
  """
  @callback back(journey(), Journey.back_request()) ::
              {:ok, Journey.answer()}
              | {:error, [Riddler.Finding.t()]}
              | {:error, :no_such_journey}
end
