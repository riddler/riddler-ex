### Added

- `Riddler.Journey.present/3` admits `{:done, result}` and answers the done state with `"result"` beside it, the host's map carried whole in the answer's data form; a `result` that is not a map, a struct included, answers `{:error, :unknown_status}`, and `:done` answers as before.
- The conformance corpus's `journey.present` cases state what a done status with a result answers, its refusals included.
