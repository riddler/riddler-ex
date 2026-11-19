# Seal and unseal a secret answer

This page shows how to ask a visitor for a secret, such as a PIN, with a
`secret_question`, and how your host seals the answer before it reaches your
execution and opens it again when it needs it. It uses patron registration: a
visitor chooses a PIN for a new library card.

It assumes you already have a document that admits and validates; if not,
start from the basic usage in the README.

## What is yours and what is Riddler's

Riddler checks the answer and hands you the result of your own sealer. The
sealing key, the sealer, the unsealer and the store are yours:

- You write the sealer, a function of one string. Riddler applies it inside
  one call and keeps it nowhere.
- You write the unsealer. Riddler has no function that opens a sealed string.
- You keep the sealed string, and the key that opens it.

The rest of this page is the order those pieces run in.

## Ask for the PIN

Put a `secret_question` on a screen. It needs a `label`, and takes an
optional `required` and an optional `help`:

```json
{
  "type": "secret_question",
  "key": "library_pin",
  "label": "Choose a PIN for your library card",
  "help": "Four to eight digits, as printed on your card at {{ context.branch_name }}.",
  "required": true
}
```

A secret question carries no `default` and no `prefill`; a document that
gives it either is refused with `document.secret_initial_value`. A template
or condition that reads the question's response, or a button that writes to
it, is refused with `document.secret_reference`.

The question's response is addressed `responses.library_pin`, as any
response is. When you resolve or present the screen, the question carries
`held` and never a value: `true` where the root holds a sealed answer for it,
`false` otherwise.

## Write the sealer

A sealer takes the plaintext string and answers `{:ok, sealed}`, with
`sealed` a string, or `{:error, reason}`. What the string holds is yours.
This sketch calls a vault module of your own; `MyHost.Vault` is not part of
Riddler and does not exist until you write it:

```elixir
sealer = fn plaintext ->
  case MyHost.Vault.encrypt(plaintext) do
    {:ok, ciphertext, key_version} -> {:ok, "v#{key_version}:#{ciphertext}"}
    {:error, reason} -> {:error, reason}
  end
end
```

Riddler does not read, compare or open the string, so the `v1:` prefix above
is a choice of this host, not something Riddler asks for. Putting the key
version inside the string is a good one, because the unsealer needs it later.

## Seal between validation and the engine

When a submit arrives, run the steps in this order:

1. Check the screen with `Riddler.Screens.validate_screen/3,4`, against a
   root that holds the plaintext. A required question left blank is
   `response.required`.
2. Only when that answers `:ok`, call `Riddler.Screens.seal_secrets/4` with
   the document, the screen's key, the responses and your sealer.
3. Hand the answer to your execution, never the plaintext.

```elixir
{:ok, responses} =
  Riddler.Screens.seal_secrets(document, "card_pin", submitted_responses, sealer)
#=> {:ok,
#    %{
#      "first_name" => "Ada",
#      "library_pin" => %{"sealed" => "v3:EXAMPLE-SEALED-HANDLE"}
#    }}
```

`seal_secrets/4` replaces the plaintext response to each secret question the
named screen declares with `{"sealed": string}`, once per question, in
document order. It leaves every other response as it was. A response that is
absent stays absent, one that is blank (`null`, or only whitespace) is left
as written, and one already in the sealed form is left as it is, with your
sealer not called for it.

Riddler has no stepper, so the order is yours to keep. A host that hands the
plaintext to its execution before this call has stored the PIN unsealed.

### When sealing is refused

A refusal comes back as `{:error, ...}`. The first two findings below are found
before your sealer is first applied, so it is never called; the third stops the
call at the question whose seal failed:

- `response.invalid_shape`, with `field` `"type"`: a secret question's
  response is neither text nor the sealed form.
- `response.unsealed_secret`: a plaintext response to a secret question that
  another screen declares. Riddler refuses it because that question was not
  validated with this screen.
- `response.seal_failed`, with `field` `"sealed"`: your sealer answered
  something other than `{:ok, string}`. The call stops at that question and
  answers no partly sealed map.
- `{:error, :no_such_screen}`: the document declares no screen under that key.

A sealer that raises raises through `seal_secrets/4`; Riddler does not rescue
your function.

## Keep the key versions until the Journey is pruned

Riddler never reads the sealed string, so it cannot tell which key sealed it.
That bookkeeping is the host's. A sealed string stays in the Journey's root
for as long as the Journey does, so:

- Rotate the sealing key by adding a new version and sealing new answers with
  it. Do not delete an old version while any Journey still holds a string
  sealed under it.
- Retire a key version only when the last Journey that holds a string sealed
  under it has been pruned.

This is advice to a host, not something Riddler checks.

## Unseal when you need the PIN

Unsealing is a function of yours that reads the key version out of the
string and opens it with that version's key:

```elixir
unseal = fn "v" <> rest ->
  [version, ciphertext] = String.split(rest, ":", parts: 2)
  MyHost.Vault.decrypt(String.to_integer(version), ciphertext)
end
```

Call it from your own code, at the point your host needs the PIN, such as
comparing it with what a visitor types at the desk. Take the sealed string
from the root's `responses`, where `seal_secrets/4` left it. Riddler is not
involved, and nothing it answers will hold the opened value.

## Overwrite the response with a marker once the credential is stored

Often the host copies the credential into its own store once it is sealed, a
card record, say, and no longer needs the sealed string in the Journey's
root. Then replace it there. The marker has to be in the sealed form:

```elixir
marker = %{"sealed" => "stored"}
```

An object whose one key is `"sealed"` with a string value is a held value.
It satisfies `required` and is never checked again, so the question still
reads as answered and the screen validates. Do not use a bare string such as
`"stored"`: that is a plaintext as far as Riddler is concerned, and it would
be validated and sealed like a PIN. This is again advice to a host, and the
marker's text is yours.

## What Riddler never sees

- **The key.** It is in your sealer and your unsealer, never in the document,
  the root, a response or anything Riddler answers.
- **The sealed string's contents.** Riddler holds it and passes it on, and
  never opens, compares or logs it.
- **The plaintext, outside your call.** It exists between the visitor's
  submit and your call to `seal_secrets/4`. Riddler's findings and
  diagnostics name the question by its key and never carry the plaintext, the
  sealer's `reason` or the sealed string, and nothing in the package logs or
  emits telemetry.
- **Any rendering of it.** A presented secret question says `held` and
  carries no value, so a client has nothing to echo back.

The sealed string leaves Riddler in one place only: the `{:ok, responses}`
answer of `seal_secrets/4`.

## See also

- `Riddler.Screens.seal_secrets/4` for the function, its refusals and its
  doctests.
- `Riddler.Screens.validate_screen/4` for how a secret question is checked.
- [Present a Journey: a screen, waiting or done](present-a-journey.md) for
  what a presented screen carries.
