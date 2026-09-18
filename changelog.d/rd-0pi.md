### Added

- A finding carries `:position`, the `%{line: line, column: column}` in the
  source it refused, so an editor can point at a refused template construct
  without parsing the message. Every template refusal sets it, and a
  `document.invalid_template` finding carries the position of the template
  refusal it wraps. Every other finding leaves it `nil` - the document checks,
  the `response.*` checks, and a `document.invalid_condition` the compiler
  gave a place for, whose message names a line and a column the finding does
  not carry. The message goes on naming the position in its own words wherever
  there is one.
