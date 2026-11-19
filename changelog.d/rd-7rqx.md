### Added

- A resolved or presented `secret_question` node carries `held`, `true` where the root holds the sealed form for it and `false` otherwise, and never the plaintext, the sealed string or a `value`; `Riddler.Screens.resolve/2`, `Riddler.Screens.resolve_screen/3` and `Riddler.Journey.present/3` all answer it, and `priv/schemas/presented-answer.schema.json` enumerates the type, requiring `held` and refusing `value`.
