### Added

- A finding carries `:position`, the `%{line: line, column: column}` in the
  source it refused, so an editor can point at a refused template construct
  without parsing the message. Every template refusal sets it, and a
  `document.invalid_template` finding carries the position of the template
  refusal it wraps; a finding with no source span leaves it `nil`, and the
  message goes on naming the position in its own words.
