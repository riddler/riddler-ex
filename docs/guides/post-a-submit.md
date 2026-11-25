# Post a submit

This page shows how to take what a client sends when a visitor presses a
button, check it, and hand your execution only what it should keep, and
what a client sends when the visitor goes back. It uses
patron registration: a visitor fills in the first screen of a library card
application and presses Continue.

It assumes you already present screens with `Riddler.Journey.present/3`; if
not, start from [Present a Journey: a screen, waiting or
done](present-a-journey.md).

## What a client sends

A submit is a JSON object of three keys, all required:

```json
{
  "screen": "patron_details",
  "outcome": "details_submitted",
  "responses": {"reminder_email": "ada@example.com"}
}
```

- `"screen"` is the key of the screen the client was shown.
- `"outcome"` is the outcome of the button the visitor pressed. It is the
  only thing the submit says about the button.
- `"responses"` is what the visitor entered on that screen, keyed by question
  key. A screen with no question sends `{}`.

The package ships the shape as `priv/schemas/submit.schema.json`, so a client
in another language can check what it is about to send.

How the bytes reach your host is not Riddler's: decode them into a term with
your own JSON library, then hand the term over.

## Check the shape with `decode_submit/1`

`Riddler.Journey.decode_submit/1` checks the shape and nothing else:

```elixir
Riddler.Journey.decode_submit(%{
  "screen" => "patron_details",
  "outcome" => "details_submitted",
  "responses" => %{"reminder_email" => "ada@example.com"},
  "sent_at" => "2026-11-18T10:00:00Z"
})
#=> {:ok,
#    %{
#      "screen" => "patron_details",
#      "outcome" => "details_submitted",
#      "responses" => %{"reminder_email" => "ada@example.com"}
#    }}
```

A key the client sends beside the three is dropped, as `"sent_at"` is above.
Each value is kept as the client sent it.

A submit that fails the shape is `{:error, findings}`. Every defect is
reported in one pass, in the order `"screen"`, `"outcome"`, `"responses"`:

```elixir
{:error, findings} =
  Riddler.Journey.decode_submit(%{
    "screen" => "patron_details",
    "responses" => ["ada@example.com"]
  })

Enum.map(findings, &{&1.code, &1.field})
#=> [{"submit.missing_field", "outcome"}, {"submit.invalid_field", "responses"}]
```

- `submit.not_an_object`, its `field` `nil`: the value is not a JSON object
  (a struct is not one either). This is the only finding then.
- `submit.missing_field`: the object lacks a key. `field` names it.
- `submit.invalid_field`: `"screen"` or `"outcome"` is not a string, or
  `"responses"` is not an object. `field` names it.

Nothing a client can send makes the decoder raise.

## Compare the screen with where your execution is

The decoder reads no document and no execution. Two checks stay with you,
and both come before you look at a single response.

1. **The screen.** Compare `submit["screen"]` with the key of the screen your
   execution is at now. They differ when the client is behind: a second tab,
   a retried request, a screen your execution has already moved on from. Do
   not validate the responses against the wrong screen. Answer the client
   with what your execution is at now, by presenting it again.
2. **The outcome.** Present your current screen and check that
   `submit["outcome"]` is among `moves["outcomes"]` in the answer. An outcome
   names one move: no two buttons a screen can show together raise the same
   outcome, which is why the submit carries the outcome and no button key.

How you refuse is yours: Riddler has no code for a stale screen or an unknown
outcome, because it never sees your execution.

## Validate with the button that was pressed

`Riddler.Screens.validate_screen/4` honours the pressed button's `validates`,
so a Back button can leave a half-filled screen. It takes the button's key,
and the submit carries an outcome, so find the button on the screen you
presented:

```elixir
button =
  Enum.find(screen["elements"], &(&1["type"] == "button" and &1["outcome"] == outcome))

root = %{"context" => context, "responses" => responses}

Riddler.Screens.validate_screen(document, screen_key, root, button["key"])
```

The root carries your `context`, and the client's `responses` as the
visitor sent them.

A key that names no button validates, because that is what a button that is
not there defaults to. So do the outcome check above first; it is what
guarantees a button was found.

## Seal before the engine

A screen with a `secret_question` has one more step, between validation and
your engine: `Riddler.Screens.seal_secrets/4` replaces the plaintext response
to each secret question with the sealed form, so your execution and the
stored root never hold the plaintext. Pass it the same `responses`, the
screen key and your sealer. The pieces and their order are in [Seal and
unseal a secret answer](seal-a-secret-answer.md).

## Put the steps together

One host function, in the order above. `MyHost` is not part of Riddler and
does not exist until you write it; `sealer` is the function that page shows:

```elixir
def post(document, screen_key, context, raw_submit, sealer) do
  with {:ok, submit} <- Riddler.Journey.decode_submit(raw_submit),
       :ok <- same_screen(submit["screen"], screen_key),
       {:ok, %{"screen" => screen, "moves" => moves}} <-
         Riddler.Journey.present(document, {:screen, screen_key}, %{"context" => context}),
       :ok <- known_outcome(submit["outcome"], moves),
       button = Enum.find(screen["elements"], &(&1["type"] == "button" and &1["outcome"] == submit["outcome"])),
       root = %{"context" => context, "responses" => submit["responses"]},
       :ok <- Riddler.Screens.validate_screen(document, screen_key, root, button["key"]),
       {:ok, responses} <-
         Riddler.Screens.seal_secrets(document, screen_key, submit["responses"], sealer) do
    MyHost.advance(submit["outcome"], responses)
  end
end

defp same_screen(key, key), do: :ok
defp same_screen(_sent, _current), do: {:error, :stale_screen}

defp known_outcome(outcome, %{"outcomes" => outcomes}),
  do: if(outcome in outcomes, do: :ok, else: {:error, :unknown_outcome})
```

The `with` stops at the first step that does not answer as written, and
returns what that step returned. Each `{:error, ...}` is yours to turn into an
answer for the client.

## Take a client going back

When you present a screen with `"back"` true in its options, the answer's
`"moves"` carries `"back"` true, and the visitor may ask to go back. Say
the visitor is on `card_delivery`, the screen after `patron_details` where
they choose how the library card reaches them:

```elixir
Riddler.Journey.present(document, {:screen, "card_delivery", %{"back" => true}}, root)
#=> {:ok, %{"state" => "screen", "screen" => ..., "moves" =>
#      %{"outcomes" => ["delivery_chosen"], "back" => true}}}
```

To go back, the client sends a second shape, the back request:

```json
{"screen": "card_delivery", "back": true}
```

- `"screen"` is the key of the screen the client was shown, a string, as in
  a submit.
- `"back"` is `true`.
- There is no `"outcome"`: going back presses no button. There is no
  `"responses"` either: what the visitor entered on the screen being left
  was never submitted, and it is dropped.

Hand it to the same decoder. `decode_submit/1` answers a map with no
`"outcome"` and `"back"` true as a back request, and drops every other key,
`"responses"` included:

```elixir
Riddler.Journey.decode_submit(%{
  "screen" => "card_delivery",
  "back" => true,
  "responses" => %{"delivery_method" => "mail"}
})
#=> {:ok, %{"screen" => "card_delivery", "back" => true}}
```

A back request with no `"screen"` is refused with `submit.missing_field`,
and one whose `"screen"` is not a string with `submit.invalid_field`, each
the one finding, its `field` `"screen"`. Two shapes near a back request are
not one:

- A map that carries `"outcome"` is a submit, whatever its `"back"` holds,
  and is decoded as one. A client that means to go back sends no outcome.
- A map with no `"outcome"` whose `"back"` is anything other than `true` is
  a submit with no outcome, refused with `submit.missing_field` on
  `"outcome"` and the submit's other findings.

Tell the two apart by `"back"` in the decoded map, then take the host's
step. The decoder reads no document and no execution: it does not check
that you presented `"back"` true for that screen, and it does not compare
`"screen"` with the screen your execution is at. Which screen going back
reaches, and whether it is allowed from where the execution is, are your
workflow engine's. Raise its back event, then pass `present/3` the status
it answers, as for any step: here, that the execution is at
`patron_details` again.

The responses your root already holds stay as they are. A back request
changes nothing in the root: `"reminder_email"`, submitted on
`patron_details`, is still there, and `"delivery_method"` never reached
it.

## Tell the client what was wrong

`decode_submit/1` and `validate_screen/3,4` both refuse with a list of
`Riddler.Finding` structs. Send them to the client as a list of objects with
the finding's keys, `code`, `message`, `field`, `element_key`, `position` and
`author_message`, every key present. `Map.from_struct/1` gives you the map to
encode. The package ships the shape as `priv/schemas/finding.schema.json`.

A client switches on `code`, which does not change when the wording does. Where
`author_message` is a string it is the text the document's author wrote for
that code, and a client shows it; where it is `null`, the client shows its own
text. How the list reaches the client, beside or instead of a presented
answer, is yours.

## See also

- `Riddler.Journey.decode_submit/1` for the decoder and its findings.
- `Riddler.Screens.validate_screen/4` for the check and the `validates`
  opt-out.
- [Seal and unseal a secret answer](seal-a-secret-answer.md) for the step
  before your engine.
- `Riddler.Journey.Host` for the four callbacks a renderer drives your loop
  through, `back/2` the one that takes a back request.
