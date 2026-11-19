### Added

- A `text_question`, `choice_question` or `boolean_question` takes `help`, a line of guidance shown beside the question and a template like `label`: `Riddler.Screens.resolve/2`, `Riddler.Screens.resolve_screen/3` and `Riddler.Journey.present/3` render it, report a variable the root does not carry in `missing_variables` under the question's key, and `priv/schemas/presented-answer.schema.json` types it as an optional string on all four question types.

### Changed

- A `help` on a text, choice or boolean question, which 0.4.0 admitted and dropped, is now kept and rendered, and `Riddler.Screens.Document.validate/1` refuses one that is not a string or holds a construct outside the template subset as `document.invalid_template`. Fix such a document by correcting the help or removing it.
