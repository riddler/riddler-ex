defmodule Riddler.Screens do
  @moduledoc """
  A document against one visitor: what they are shown, and what could not be
  decided.

  `Riddler.Screens.Document` answers whether a document is well formed, on its
  own, before anyone arrives. This module answers the other question: given a
  host's `context` and a visitor's `responses`, which elements are shown, what do
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
  of the question element it belongs to.

  A secret question's response is the one a condition and a template never
  read. Before any condition is evaluated or any template rendered, the
  response of every secret question the document declares, on any screen, is
  removed from the root they read: a template naming one renders the empty
  string and reports it in `missing_variables`, and a condition naming one is
  undecidable, hidden and reported, as for any variable the root does not
  carry. `Riddler.Screens.Document.validate/1` refuses a document that names
  one; this is what holds for a document no one validated. Response
  validation still reads the secret question's own response from the root the
  host passed.

  ## What resolution does to an element

  An element with no condition is shown. An element whose condition evaluates false is
  hidden silently, because that is the condition doing its job. An element whose
  condition cannot be evaluated - a variable the root does not carry, an
  operand of the wrong type, anything that is not true or false - is hidden
  *and* reported in `undecidable_conditions`: the author asked a question the
  runtime could not answer, and a visitor should not be shown an element on a
  guess.

  A container resolves to the first of its candidates whose condition holds,
  and the winner replaces the container, so nothing downstream needs to know a
  container was ever there. A container no candidate wins resolves to nothing.

  Every template field - `text`, `label` (a link's among them), `placeholder`,
  `help` and an image's `alt`, and the `label` and `description` of
  each of a choice question's `answer_options` - is rendered leniently: a
  variable the root does not carry renders as the empty string and is reported
  in `missing_variables`, so a visitor sees a screen rather than an error page.
  An option's `value` is literal and is left as written. An element that is hidden is never rendered, so it contributes no
  missing variables.

  An image's `src` is a URL or a path under `context`. A path is read from
  `"context"` when the image is shown, and the resolved image carries the
  value it reaches where that is an `https://` URL or a host-relative one, as
  `Riddler.Screens.Type.Image` states the rule; a `data:` URL is admitted only
  where the document wrote it. Where the path reaches nothing, a value that is
  not a string, or a URL the rule refuses, the image is absent from the
  resolved screen and reported in `missing_variables` under its key, its
  `variable` the path as written; the value is reported nowhere, and the
  image's `alt` is not rendered. No resolved image carries a path. A literal
  `src` the rule refuses is a document `validate/1` refuses; a document no one
  validated resolves without that image.

  A link's `href` is read in the same way, by the same rule, with no `data:`
  form whether written or read (`Riddler.Screens.Type.Link`): a link whose
  path reaches no URL the rule admits is absent and reported by its path, and
  its `label` is not rendered. A divider resolves to its `type` and `key`. A
  `text` carries its `style` where the document wrote one, and none where it
  did not.

  A choice question that names `answer_options_from` reads its options from
  `"context"` at that path when it is resolved, and carries them as
  `answer_options` and carries no `answer_options_from`. The options are the
  value at the path where it is a list each of whose entries is an object
  carrying a `"value"`, a string in the key shape, and a `"label"`, a
  string, with no value carried twice; each is taken as its value and its
  label and nothing else, in the order the list gives. Their labels are the
  host's data and are not rendered. A path that reaches nothing, or a value
  that is not such a list, resolves the question with no options and is
  reported in `missing_variables` under the question's key, its `variable`
  the path as written; an empty list is a question with no options and is not
  reported.

  The output carries no `condition` and no `checks` anywhere, and carries
  `writes` through untouched: what a button sets is the host's to apply when
  the visitor presses it.

  A shown question whose own response is not nothing answered has its
  `checks` read for one purpose: each check the root does not decide is
  reported in a third list of the diagnostics, `undecidable_checks`, an entry
  of the question's `key`, the check's `code` and its `condition`. Resolution
  raises nothing and hides nothing by a check, and the list is a key of the
  diagnostics only where it holds an entry.

  ## The value a question presents

  A resolved text, choice or boolean question carries no `default` and no
  `prefill`: resolution consumes them into `value`, which it sets from the
  first of these that yields one. A response the root holds for the question
  and that is not `null` is the value, as written whatever its shape, so a
  screen shown again after validation refused a response shows what the
  visitor sent. Else the value the `prefill` path reads from `"context"`, one
  string key at a time, where it is a value the question's `default` could be:
  of the question's response shape and, on a choice question, among its
  options. Else the `default`, put to the same test. A question none of them
  yields one for carries no `value`. A prefill path the context does not
  carry yields nothing and is reported nowhere.

  `value` is presentation only. Response validation reads the responses the
  root holds and never a `value`, so a required question showing a default
  that the visitor did not send back is unanswered.

  A resolved secret question carries no `default` or `prefill`, and one field
  resolution adds, `held`: `true` where the root the host passed holds the
  sealed form for the question, an object whose one key is `"sealed"` and
  whose value is a string, and `false` otherwise - nothing answered, the
  plaintext the visitor typed, or any other shape. It is read before the secret
  responses are removed from the root a condition and a template read, and it
  is all the element carries of the response: never the plaintext, never the
  sealed string.

  ## What a set of responses has to satisfy

  `validate_screen/3` and `validate_screen/4` answer the last question:
  whether what the visitor typed is enough to submit the screen. They resolve
  the screen first and check only what came back, so a question a condition hid
  cannot fail, and they consult what the element declares - `required`, `format`,
  and `min` and `max` on the numeric formats; a choice question's
  `answer_options`, `select` and selection bounds; and a boolean question's
  `true` or `false`. The arity-4 form takes the key of the button the visitor
  pressed and honours its `validates`.

  A question's `messages` maps a finding code to the text its author shows
  for it. A finding raised on that question's response whose code it keys
  carries that text as `author_message`, and its `message` is unchanged;
  every other built-in finding carries `author_message` `nil`.

  A question's `checks` are conditions its author writes over `context` and
  `responses`, evaluated after the built-in checks against the root a
  condition reads, which carries no secret question's response. A question
  the built-in checks raise a finding on answers that finding and none of its
  checks is evaluated, and neither is a question whose own response is
  nothing answered. Otherwise its checks are evaluated in order: the first
  the root decides false raises one finding, its `code` the check's, its
  `field` `"checks"`, its `author_message` the check's `message`, and a
  `message` naming the question and the check and quoting no response; a
  check the root does not decide raises nothing, and the next is evaluated.
  A question a condition hid has none of its checks evaluated.

  A secret question answers at most one finding, and none of its findings
  carries anything of the response. A response in the sealed form, an object
  whose one key is `"sealed"` and whose value is a string, is a held value: it
  satisfies `required` and is never checked again. Nothing answered - absent,
  `null` or a string of whitespace - is `response.required` where the
  question is required. Any other string is the plaintext the visitor typed,
  and nothing further is checked: the question declares no format. Any other
  value is `response.invalid_shape`, its `field` `"type"`.

  They take the same root `resolve/2` and `resolve_screen/3` take, and the
  responses they check are the ones inside it. The screen validated is the
  screen shown: a question the host's `context` made visible to this visitor
  is a question this visitor can fail. A condition that root could not decide
  is a finding rather than a pass wherever the press validates, because an element
  hidden from the validator and not from the visitor is the one case this
  cannot guess at. A choice question that reads its options from context is
  checked against the options that root's `"context"` holds, so a value the
  context offered when the screen was shown and no longer offers is
  `response.not_an_option`.

      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 2,
      ...>     "id" => "edoc_checkout",
      ...>     "screens" => [
      ...>       %{
      ...>         "key" => "card",
      ...>         "title" => "Your card",
      ...>         "elements" => [
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
      iex> Enum.map(hd(resolved.screens).elements, & &1.text)
      ["Charging Acme.", "The card on file expires soon."]
      iex> resolved.diagnostics
      %{missing_variables: [], undecidable_conditions: []}

  ## Rewriting a version 1 document

  `upgrade/1` rewrites a decoded version 1 document as version 2, the key and
  the version and nothing else, for a host migrating the documents it stores;
  `mix riddler.upgrade` does the same to a file. Admission never rewrites a
  document.
  """

  alias Riddler.Finding
  alias Riddler.Screens.Checks
  alias Riddler.Screens.ContextOptions
  alias Riddler.Screens.Document
  alias Riddler.Screens.Resolved
  alias Riddler.Screens.Seal
  alias Riddler.Screens.Type.SecretQuestion
  alias Riddler.Screens.Upgrade
  alias Riddler.Screens.Url
  alias Riddler.Screens.Validation
  alias Riddler.Screens.Value
  alias Riddler.Template

  # `undecidable_checks` is gathered beside the two lists and is a key of the
  # diagnostics a caller is handed only where it holds an entry, so a screen
  # with no check, or none undecided, reports the two lists alone.
  @empty_diagnostics %{missing_variables: [], undecidable_conditions: [], undecidable_checks: []}

  # The question types that present a `value`: every question type but the
  # secret question, which presents `held` instead.
  @valued_types ["text_question", "choice_question", "boolean_question"]

  @doc """
  Resolves every screen of a document against a root.

  Always `{:ok, resolved}`: resolution reports rather than refuses, so a
  condition it could not evaluate and a variable it could not find come back in
  the resolved document's diagnostics.

  The root is read for `"context"` and `"responses"` and nothing else; either
  one absent is the same as it being empty.

      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 2,
      ...>     "id" => "edoc_signup",
      ...>     "screens" => [
      ...>       %{
      ...>         "key" => "account",
      ...>         "title" => "Create your account",
      ...>         "elements" => [
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
      iex> {hd(resolved.screens).elements, resolved.diagnostics.undecidable_conditions}
      {[], [%{key: "account_greeting", condition: "responses.first_name != ''"}]}
  """
  @spec resolve(Document.t(), map()) :: {:ok, Resolved.t()}
  def resolve(%Document{} = document, root) when is_map(root) do
    root = normalize(root)
    scope = scope(document, root)

    {screens, diagnostics} =
      Enum.map_reduce(document.screens, @empty_diagnostics, &resolve_one(&1, scope, &2))

    {:ok,
     %Resolved{
       schema_version: document.schema_version,
       kind: document.kind,
       id: document.id,
       metadata: document.metadata,
       screens: Enum.map(screens, &unchecked/1),
       diagnostics: order(diagnostics)
     }}
  end

  @doc """
  Resolves the one screen a host is about to render.

  `{:ok, screen, diagnostics}`: the screen, and what resolving *that* screen
  could not decide. The diagnostics are the shape `resolve/2` carries on a
  resolved document - `missing_variables` and `undecidable_conditions`, both in
  document order, with `undecidable_checks` beside them where a check went
  undecided - narrowed to the one screen. A caller is never handed a
  screen whose resolution reported something without being handed the report,
  which is what lets a single-screen host tell an element hidden by a condition
  that held from an element hidden because the condition could not be decided.

  Returns `{:error, :no_such_screen}` when the document declares no screen
  under that key: asking for a screen that is not there is the host's mistake,
  not a visitor's, and is worth an error rather than an empty screen.

      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 2,
      ...>     "id" => "edoc_signup",
      ...>     "screens" => [
      ...>       %{
      ...>         "key" => "account",
      ...>         "title" => "Create your account",
      ...>         "elements" => [
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
      iex> {screen.key, screen.title, screen.elements}
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
    case checked_screen(document, screen_key, normalize(root)) do
      {:ok, screen, diagnostics} -> {:ok, unchecked(screen), diagnostics}
      {:error, :no_such_screen} = no_such_screen -> no_such_screen
    end
  end

  @doc """
  Validates a visitor's responses against the screen they were shown.

  `:ok`, or every reason the screen is not ready to be submitted. Checks run
  over the *resolved* screen and nothing else: the screen is resolved against
  the root the host resolved with, so an element a condition hid is an element the
  visitor never saw and cannot be held to. A question the visitor was never
  asked cannot fail.

  The root is the one `resolve/2` and `resolve_screen/3` take, read for
  `"context"` and `"responses"` and nothing else, and the responses that are
  checked are the ones inside it. A screen validated is the screen shown: a
  question a `context` condition made visible to this visitor is a question
  this visitor can fail.

  What is checked is what the element declares. `required` is unanswered when the
  response is absent or is a string of whitespace. `format` names one of the
  validation formats the internal Riddler.Screens.Document.formats/0 lists,
  and a blank response that is not required is not put to it - a format has
  nothing to say about text a visitor did not type. The numeric formats also
  honour `min` and `max` where the question declares them. A question whose
  `pattern` does not compile is not checked against that pattern here: the
  defect is the document's and `Riddler.Screens.Document.validate/1` reports it as
  `document.invalid_pattern`, so a host that validates responses without
  validating documents is not told, and every response to that question
  satisfies the pattern check.

  A choice question and a boolean question are checked whatever they
  declare, and each answers at most one finding, the first of these that
  applies. Nothing selected - absent or `null`, or `""` under `select:
  "one"`, `[]` under `select: "many"` - is `response.required` where the
  question is required and nothing otherwise, whatever its selection bounds.
  A response that is not the shape its type fixes - one string under
  `"one"`, a list of different strings under `"many"`, `true` or `false` for
  a boolean question - is `response.invalid_shape`. A required boolean
  question whose response is `false` is `response.required`. A value no
  option carries, compared as written, is `response.not_an_option`, one
  finding naming every such value. Under `"many"`, fewer values than
  `min_selections` or more than `max_selections` is `response.out_of_range`,
  its `field` naming the bound. A `format` on either type is a field nothing
  consults. A choice question whose `select` is neither value is the
  document's defect, reported as `document.invalid_select`, and its response
  is held to `required` and to nothing else.

  Every finding names the element it is about in `element_key`, the field that was
  not satisfied in `field`, and a stable `code`: `response.required`,
  `response.format`, `response.out_of_range`, `response.invalid_shape`,
  `response.not_an_option` or `response.undecidable`. There is one finding
  per failing element, because an empty field is one thing wrong with a screen
  and not three.

  `response.undecidable` is the one that is not about a response. A condition
  this root could not decide - a variable the root does not carry, an operand
  of the wrong type - is reported as a finding on the element that carries it,
  with `field` `"condition"`. So is a condition that is not valid predicator at
  all, and one that is not a string: the code is the one fail-closed answer for
  every condition resolution could not decide, so that a host which skipped
  `Riddler.Screens.Document.validate/1` is told rather than let through. The
  `message` says which of the three it was, and carries the place the compiler
  or the evaluator gave where there is one, as `position` does. For a
  condition that compiles, the message also says what the evaluator answered:
  a name the root does not carry, a value that is not true or false, or an
  evaluation error such as a division by zero or an unknown function. Where
  the evaluator's answer does not tell a missing key from an operand of the
  wrong type, the message says only that the condition could not be decided.
  A condition that does not parse is also the document's own
  `document.invalid_condition`, which is where an author fixing the document
  is told about it.

  A condition that could not be decided says the
  root the host handed in does not carry what the document asks about, which
  is a defect in the call rather than a property of the visitor, so treating
  the element as hidden and answering `:ok` would accept a submission nobody
  checked. It is reported wherever the pressed button validates. The press
  that does not is one through a button declaring `validates` as `false`,
  which answers `:ok` without running a check at all - see
  `validate_screen/4`. This arity-3 form presses no button, so there is no
  press to read `validates` from and it reports the finding whatever buttons
  the screen carries. A button declaring `validates` as `false` and carrying
  no key at all is no exception: the opt-out is a property of a press, and
  nothing can press a button nothing can name.

  A condition this root *decides* false is a different thing and stays silent:
  the element is hidden, and a question the visitor was never asked cannot fail.
  So is a variable a template wanted and the root did not carry - that renders
  as the empty string, is reported in `missing_variables`, and is no finding.

  `{:error, :no_such_screen}` comes straight back from `resolve_screen/3`: a
  host asking about a screen the document does not declare is told so rather
  than told its responses are fine.

  A secret question's response that validation accepted as plaintext is
  sealed by the host, through `seal_secrets/4`, before the responses reach its
  engine.

      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 2,
      ...>     "id" => "edoc_checkout",
      ...>     "screens" => [
      ...>       %{
      ...>         "key" => "card",
      ...>         "title" => "Your card",
      ...>         "elements" => [
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
      iex> {finding.code, finding.element_key, finding.field}
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
      ...>   "elements" => [
      ...>     %{"type" => "text_question", "key" => "billing_email", "label" => "Receipt to", "required" => true},
      ...>     %{"type" => "button", "key" => "card_back", "label" => "Back", "outcome" => "went_back", "validates" => false},
      ...>     %{"type" => "button", "key" => "card_pay", "label" => "Pay", "outcome" => "paid"}
      ...>   ]
      ...> }
      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 2,
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

    case checked_screen(document, screen_key, root) do
      {:ok, screen, diagnostics} ->
        Validation.validate(
          screen,
          diagnostics,
          root,
          reading(document, root),
          pressed_button_key
        )

      {:error, :no_such_screen} = no_such_screen ->
        no_such_screen
    end
  end

  @typedoc """
  The host's sealer: a function of one plaintext string answering
  `{:ok, sealed}`, `sealed` a string only the host's own key opens, or
  `{:error, reason}`.
  """
  @type sealer :: (String.t() -> {:ok, String.t()} | {:error, term()})

  @doc """
  Seals the responses to a screen's secret questions with the host's sealer.

  A host calls it between validation and its engine: once
  `validate_screen/3` or `/4` has answered `:ok` against a root holding what
  the visitor typed, this replaces each secret question's plaintext with the
  sealed form, `%{"sealed" => sealed}`, so the engine, the Journey's stored
  root and everything downstream of them hold the sealed form and never the
  plaintext. `responses` is the string-keyed map of responses the host is
  about to hand its engine, the `"responses"` half of a root and not the
  root.

  `sealer` is the host's own function, passed in this call and kept nowhere:
  it takes one plaintext and answers `{:ok, sealed}` with `sealed` a string,
  or `{:error, reason}`. This function is pure apart from it: it consults no
  store and keeps nothing between calls. A sealed string is an opaque handle;
  nothing in this package reads it, compares it or opens it.

  What one call does:

    * It seals every secret question the named screen declares, a variant's
      candidates included, whatever its condition: it takes no `context` and
      reads no condition. Each plaintext is passed to the sealer once, in
      document order.
    * A response that is absent stays absent; one that is nothing answered,
      `nil` or a string of whitespace, is left as written; one already in the
      sealed form is left as it is and the sealer is not called for it. Every
      response that is not a secret question's is untouched.
    * Before the sealer is first applied, it refuses what it cannot seal,
      every finding in document order: a response to one of the screen's
      secret questions that is neither text nor the sealed form is
      `response.invalid_shape`, its `field` `"type"`; and a response that is
      not absent, nothing answered or the sealed form to a secret question
      only another screen declares is `response.unsealed_secret`, its `field`
      `"sealed"`, because that question was not validated with this screen.
      Where there is any, the answer is `{:error, findings}` and the sealer is
      never called.
    * A sealer answer other than `{:ok, sealed}` with `sealed` a string stops
      the call at that question: the answer is `{:error, [finding]}`, the one
      finding `response.seal_failed`, its `field` `"sealed"`, and no partly
      sealed map is answered. A sealer that raises raises through this call;
      nothing here rescues the host's own function.

  No finding carries the plaintext, the sealer's `reason` or a sealed string:
  each names the secret question by its key. Every finding here carries
  `author_message` `nil`, because these refuse the host's call and not a
  visitor's response.

  `{:error, :no_such_screen}` for a screen key the document does not declare,
  as `resolve_screen/3` answers it.

      iex> document =
      ...>   Riddler.Screens.Document.admit(%{
      ...>     "schema_version" => 2,
      ...>     "id" => "edoc_patron_registration",
      ...>     "screens" => [
      ...>       %{
      ...>         "key" => "card_pin",
      ...>         "title" => "Protect your card",
      ...>         "elements" => [
      ...>           %{
      ...>             "type" => "secret_question",
      ...>             "key" => "library_pin",
      ...>             "label" => "Choose a PIN for your library card",
      ...>             "required" => true
      ...>           }
      ...>         ]
      ...>       }
      ...>     ]
      ...>   })
      iex> sealer = fn _plaintext -> {:ok, "EXAMPLE-SEALED-HANDLE"} end
      iex> responses = %{"first_name" => "Ada", "library_pin" => "EXAMPLE-PIN"}
      iex> Riddler.Screens.seal_secrets(document, "card_pin", responses, sealer)
      {:ok, %{"first_name" => "Ada", "library_pin" => %{"sealed" => "EXAMPLE-SEALED-HANDLE"}}}
      iex> failing = fn _plaintext -> {:error, :key_unavailable} end
      iex> {:error, [finding]} = Riddler.Screens.seal_secrets(document, "card_pin", responses, failing)
      iex> {finding.code, finding.element_key, finding.field}
      {"response.seal_failed", "library_pin", "sealed"}
      iex> Riddler.Screens.seal_secrets(document, "branch", responses, sealer)
      {:error, :no_such_screen}
  """
  @spec seal_secrets(Document.t(), term(), map(), sealer()) ::
          {:ok, map()} | {:error, [Finding.t()]} | {:error, :no_such_screen}
  def seal_secrets(%Document{} = document, screen_key, responses, sealer)
      when is_map(responses) and is_function(sealer, 1) do
    case Enum.find(document.screens, &(&1.key == screen_key)) do
      nil -> {:error, :no_such_screen}
      screen -> Seal.seal(document, screen, screen_key, responses, sealer)
    end
  end

  @typedoc """
  Why `upgrade/1` refuses a document: it is not a screen document,
  `Riddler.Screens.Document.admit/1` answering `nil` for it
  (`:not_a_document`); it is a version 1 document carrying an `elements` key
  on a screen or an element (`:other_version_spelling`); or its
  `schema_version` is neither 1 nor 2 (`:unsupported_version`).
  """
  @type upgrade_error :: :not_a_document | :other_version_spelling | :unsupported_version

  @doc """
  Rewrites a decoded version 1 screen document as version 2.

  It makes exactly two changes: `schema_version` becomes `2`, and the `nodes`
  of every screen and of every `variant` becomes `elements`, its list as
  written. Nothing else in the document is read or changed, so a document that
  is wrong stays wrong in the same way and is refused by the same findings. A
  `nodes` on an element whose type reads no children is a field admission
  drops at either version, and it is left as written. A document that declares
  no `schema_version`, or `1`, is version 1.

  It is for a host's own migration over the documents it stores, and
  `mix riddler.upgrade` is the same rewrite over a file. Nothing at admit
  rewrites a document: `Riddler.Screens.Document.admit/1` reads a version 1
  document as version 1, and only this call, when a host makes it, rewrites
  one.

  A version 2 document is answered unchanged, so the call is idempotent. It
  refuses, with the reason `t:upgrade_error/0` names, a document `admit/1`
  answers `nil` for, a version 1 document that already carries an `elements`
  key on a screen or on an element at any depth - the rename would collide
  with it, or version 2 would read it - and a document of any other
  version. A version 1 document with findings of its own, an unknown type
  say, is upgraded, and keeps them.

      iex> version_one = %{
      ...>   "id" => "patron_registration",
      ...>   "screens" => [
      ...>     %{
      ...>       "key" => "patron_details",
      ...>       "title" => "Get your library card",
      ...>       "nodes" => [
      ...>         %{
      ...>           "type" => "variant",
      ...>           "key" => "card_notice",
      ...>           "nodes" => [
      ...>             %{"type" => "text", "key" => "card_notice_adult", "text" => "Your card is ready the same day."}
      ...>           ]
      ...>         }
      ...>       ]
      ...>     }
      ...>   ]
      ...> }
      iex> {:ok, version_two} = Riddler.Screens.upgrade(version_one)
      iex> version_two["schema_version"]
      2
      iex> [%{"key" => "patron_details", "elements" => [notice]}] = version_two["screens"]
      iex> Enum.map(notice["elements"], & &1["key"])
      ["card_notice_adult"]
      iex> Riddler.Screens.upgrade(version_two)
      {:ok, version_two}
      iex> Riddler.Screens.upgrade(%{"screens" => "three of them"})
      {:error, :not_a_document}
      iex> Riddler.Screens.upgrade(%{"schema_version" => 3, "screens" => []})
      {:error, :unsupported_version}
      iex> colliding = put_in(version_one, ["screens", Access.at(0), "elements"], [])
      iex> Riddler.Screens.upgrade(colliding)
      {:error, :other_version_spelling}
  """
  @spec upgrade(term()) :: {:ok, map()} | {:error, upgrade_error()}
  def upgrade(document), do: Upgrade.upgrade(document)

  # -- screens ---------------------------------------------------------------

  # The one screen resolved with its shown questions still carrying their
  # `checks`, which response validation reads. `resolve_screen/3` hands a
  # caller the screen without them, as `resolve/2` hands every screen.
  defp checked_screen(document, screen_key, root) do
    case Enum.find(document.screens, &(&1.key == screen_key)) do
      nil ->
        {:error, :no_such_screen}

      screen ->
        {resolved, diagnostics} = resolve_one(screen, scope(document, root), @empty_diagnostics)
        {:ok, resolved, order(diagnostics)}
    end
  end

  # A resolved element carries no `checks`, as it carries no `condition`: both
  # are what the host decides with, and neither is handed to a client as part
  # of the element. Resolution collapses every container to its winner, so a
  # resolved screen's elements are all leaves.
  defp unchecked(screen),
    do: %{screen | elements: Enum.map(screen.elements, &Map.delete(&1, :checks))}

  # `scope` is `{root, held, responses}`: the root a condition, a template and
  # a check read, the keys of the secret questions that hold a sealed value,
  # and the responses the host passed, which say whether a question was
  # answered.
  defp scope(document, root),
    do: {reading(document, root), held(document, root), root["responses"]}

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

  # The root a condition and a template read: the host's root without the
  # response of any secret question the document declares. A document with no
  # secret question reads the root it was handed, unchanged.
  defp reading(document, root) do
    case Document.secret_keys(document) do
      [] -> root
      secrets -> Map.update!(root, "responses", &Map.drop(&1, secrets))
    end
  end

  # The keys of the secret questions whose response in the host's root is the
  # sealed form. It is read from the root the host passed, before `reading/2`
  # removes those responses, and it is all a resolved secret question carries of
  # one: whether a value is held, never the value.
  defp held(document, root) do
    responses = root["responses"]

    for key <- Document.secret_keys(document),
        SecretQuestion.sealed?(Map.get(responses, key)),
        do: key
  end

  defp resolve_one(screen, scope, diagnostics) do
    {nodes, diagnostics} = resolve_nodes(screen.elements, scope, diagnostics)
    {%{key: screen.key, title: screen.title, elements: nodes}, diagnostics}
  end

  # -- elements -----------------------------------------------------------------

  defp resolve_nodes(nodes, scope, diagnostics) do
    {resolved, diagnostics} =
      Enum.reduce(nodes, {[], diagnostics}, fn node, {acc, diagnostics} ->
        case shown(node, scope, diagnostics) do
          {nil, diagnostics} -> {acc, diagnostics}
          {resolved, diagnostics} -> {[resolved | acc], diagnostics}
        end
      end)

    {Enum.reverse(resolved), diagnostics}
  end

  # An element is shown, or it is not and `nil` says so. The two reasons it is not
  # are different things: a false condition is silent, an undecidable one is
  # reported, and a container that no candidate won is neither - the container
  # asked a question and every answer was no.
  defp shown(node, {root, _held, _responses} = scope, diagnostics) do
    case decide(node, root, diagnostics) do
      {true, diagnostics} -> present(node, scope, diagnostics)
      {false, diagnostics} -> {nil, diagnostics}
    end
  end

  defp present(node, scope, diagnostics) do
    case Map.fetch(node, :elements) do
      {:ok, candidates} when is_list(candidates) -> winner(candidates, scope, diagnostics)
      _not_a_container -> resolve_leaf(node, scope, diagnostics)
    end
  end

  # The element's templates are rendered first, so that options read from the
  # context, which are the host's data and not templates, are never rendered;
  # then a choice question that names a context path for its options reads
  # them; then the element is presented, its value put to the options it is
  # shown. A path that read no list of options is reported under the
  # question's key, after any variable its templates wanted. A container that
  # carried its candidates under the other version's key only is resolved as
  # a leaf, as a container carrying none is, and what admission marked it
  # with is the document's refusal, not a field of the element.
  #
  # An element carrying a URL has it read first: one whose path reached no URL
  # the rule admits is absent, reported once by its path, and its templates
  # are never rendered, so it contributes no other missing variable.
  #
  # A shown question whose own response is not nothing answered has every
  # check its root does not decide reported in `undecidable_checks`, whether
  # or not response validation would reach it: the list is what the root
  # could not decide. Nothing is raised or hidden by a check here.
  defp resolve_leaf(node, {root, held, responses}, diagnostics) do
    node = Map.delete(node, :other_version_spelling)

    case Url.resolve(node, root["context"]) do
      {:drop, variables} ->
        {nil, missing(diagnostics, node[:key], variables)}

      {:ok, node} ->
        {node, diagnostics} = render(node, root, diagnostics)
        {node, unread} = ContextOptions.resolve(node, root["context"])

        diagnostics =
          diagnostics
          |> missing(node[:key], unread)
          |> undecided_checks(node, root, responses)

        {presented(node, root, held), diagnostics}
    end
  end

  defp undecided_checks(diagnostics, node, root, responses) do
    if Validation.nothing_answered?(node, Map.get(responses, node[:key])) do
      diagnostics
    else
      Map.update!(diagnostics, :undecidable_checks, fn reported ->
        Enum.reverse(Checks.undecidable(node, root), reported)
      end)
    end
  end

  # A resolved element carries no condition. A secret question carries no initial
  # value either: one written on it is `document.secret_initial_value`, and a
  # document no one validated does not pass it on. It carries `held` instead,
  # true exactly where the host's root holds the sealed form for it, and
  # nothing else of the response: not the plaintext, not the sealed string.
  defp presented(%{type: "secret_question"} = node, _root, held) do
    node
    |> Map.drop([:condition | SecretQuestion.initial_values()])
    |> Map.put(:held, node[:key] in held)
  end

  defp presented(%{type: type} = node, root, _held) when type in @valued_types do
    node
    |> Map.delete(:condition)
    |> Value.present(root)
  end

  defp presented(node, _root, _held), do: Map.delete(node, :condition)

  # First match wins: the candidates are considered in order and the first
  # whose condition holds replaces the container.
  defp winner([], _scope, diagnostics), do: {nil, diagnostics}

  defp winner([candidate | rest], {root, _held, _responses} = scope, diagnostics) do
    case decide(candidate, root, diagnostics) do
      {true, diagnostics} -> present(candidate, scope, diagnostics)
      {false, diagnostics} -> winner(rest, scope, diagnostics)
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
    {node, diagnostics} =
      Enum.reduce(Document.template_fields(), {node, diagnostics}, fn field,
                                                                      {node, diagnostics} ->
        render_field(node, field, root, diagnostics, node[:key])
      end)

    render_options(node, root, diagnostics)
  end

  # A choice question's option labels and descriptions are templates, after
  # the element's own fields and in the order the options are listed; each
  # option's `value` is literal and left as written. An option's template is
  # not a field of the element, so it is read here beside the document's list,
  # through `Document.option_template_fields/0`, as `validate/1` refuses it
  # beside that list. A variable one wants is reported under the question's
  # key. Only a choice question carries `answer_options`: on every other type
  # admission drops the field.
  defp render_options(%{answer_options: options} = node, root, diagnostics)
       when is_list(options) do
    {options, diagnostics} =
      Enum.map_reduce(options, diagnostics, &render_option(&1, root, &2, node[:key]))

    {%{node | answer_options: options}, diagnostics}
  end

  defp render_options(node, _root, diagnostics), do: {node, diagnostics}

  defp render_option(option, root, diagnostics, key) do
    Enum.reduce(Document.option_template_fields(), {option, diagnostics}, fn field,
                                                                             {option, diagnostics} ->
      render_field(option, field, root, diagnostics, key)
    end)
  end

  defp render_field(holder, field, root, diagnostics, key) when is_map(holder) do
    with {:ok, source} when is_binary(source) <- Map.fetch(holder, field),
         {:ok, compiled} <- Template.compile(source),
         {:ok, text, missing} <- Template.render(compiled, root, :lenient) do
      {Map.put(holder, field, text), missing(diagnostics, key, missing)}
    else
      # An absent field has nothing to render. A template that does not compile
      # is a document finding, raised before a visitor arrives. Resolution
      # neither repeats it nor invents text for it: the source stands, and the
      # author is told by `validate/1`.
      _absent_or_refused -> {holder, diagnostics}
    end
  end

  defp render_field(holder, _field, _root, diagnostics, _key), do: {holder, diagnostics}

  defp missing(diagnostics, _key, []), do: diagnostics

  defp missing(diagnostics, key, variables) do
    Map.update!(diagnostics, :missing_variables, fn reported ->
      Enum.reduce(variables, reported, &[%{key: key, variable: &1} | &2])
    end)
  end

  # Every list is built by prepending, so each is reversed once at the end
  # and comes back in document order. `undecidable_checks` is a key only where
  # it holds an entry.
  defp order(diagnostics) do
    ordered = %{
      missing_variables: Enum.reverse(diagnostics.missing_variables),
      undecidable_conditions: Enum.reverse(diagnostics.undecidable_conditions)
    }

    case diagnostics.undecidable_checks do
      [] -> ordered
      reported -> Map.put(ordered, :undecidable_checks, Enum.reverse(reported))
    end
  end
end
