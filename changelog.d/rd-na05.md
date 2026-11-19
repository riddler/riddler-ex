### Added

- `Riddler.Journey.present/3` admits `{:waiting, info}` and answers the waiting state with `"reason"` (a string) and `"retry_after_ms"` (a non-negative integer) beside it, each only where `info` carries it; an `info` that is not a map, or carries either key with the wrong type, answers `{:error, :unknown_status}`.
- The conformance corpus's `journey.present` cases state what a waiting status with info answers, its refusals included.
