### Added

- `priv/schemas/presented-answer.schema.json`, a JSON Schema (draft 7) for what `Riddler.Journey.present/3` returns inside `{:ok, ...}`, so a client can check an answer and generate its node types from it: the three states, the screen with its nodes typed for `heading`, `text`, `text_question`, `choice_question`, `boolean_question` and `button`, and `moves`, `reason`, `retry_after_ms` and `result` optional on their states; a node of any other type still validates.
