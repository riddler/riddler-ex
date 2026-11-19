### Added

- A `secret_question` node type, for a response such as a PIN that is never echoed: it carries `key`, `label`, `required` and a `help` template, and a document giving it a `default` or a `prefill` is refused with `document.secret_initial_value`.
- A document whose template, condition or button `writes` reads a secret question's response is refused with `document.secret_reference`; a document carrying no secret question is admitted as before.
- Resolution removes every secret question's response from the root a condition or a template reads, so a document no one validated renders the empty string for it and reports the condition as undecidable.
- `Riddler.Screens.validate_screen/3` and `/4` check a secret question on the plaintext the visitor typed: nothing answered is `response.required` where it is required, the sealed form `{"sealed": string}` is a held value that satisfies `required`, and any other shape is `response.invalid_shape`; no finding carries the response.
