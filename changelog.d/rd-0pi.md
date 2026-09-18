### Added

- A finding carries `:position`, the `%{line: line, column: column}` in the
  source it refused, so an editor can point at a refused template construct
  without parsing the message; it is `nil` for a finding with no source span,
  and the message goes on naming the position in its own words.
