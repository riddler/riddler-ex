### Added

- A `text_question`, `choice_question`, `boolean_question` or `secret_question` takes `messages`, an object mapping a finding code its type raises on a response to a plain string its author shows for it; the resolved and presented question carries it as written, and `priv/schemas/presented-answer.schema.json` types it as an optional object of strings on all four question types.
- `Riddler.Finding` gains `author_message`, a string or `nil`: `Riddler.Screens.validate_screen/3` and `/4` set it on a finding raised on a question's response whose code that question's `messages` keys, and leave `message` this package's own sentence. Every other finding carries `nil`, and the finding's data form carries the key on every finding.
- `priv/schemas/finding.schema.json` names `author_message`, a string or null, as a required sixth key.

### Changed

- A `messages` on a question, which 0.4.0 admitted and dropped, is now kept, carried on the resolved and presented question, and checked: `Riddler.Screens.Document.validate/1` refuses one that is not an object, or holds a value that is not a string, as `document.invalid_messages`, and a key that is not a code the question's type raises on a response as `document.unknown_message_code`. Fix such a document by correcting the messages or removing them.
