### Added

- `Riddler.Journey.present/3` reads a `"progress"` screen option, a map of `"step"` and `"of"`, each an integer of at least 1 with `"step"` not above `"of"`, and carries it beside `"moves"` on the screen answer as `%{"step" => n, "of" => m}`; a malformed one answers `{:error, :unknown_status}`, and a host that passes no `"progress"` sees every answer unchanged. The presented answer schema admits the optional `progress` object, and the conformance corpus's `journey.present` cases state both.
