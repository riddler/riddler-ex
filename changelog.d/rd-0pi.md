### Added

- A finding carries `:position`, the `%{line: line, column: column}` in the
  source it refused, so an editor can point at a refused template construct
  without parsing the message. A template refusal sets it wherever the parser
  gave it a place, and a `document.invalid_template` finding carries the
  position of the template refusal it wraps. Every other finding leaves it
  `nil`, including a parse error the parser could not locate and
  `document.invalid_condition`, whose message names a line and a column the
  finding does not carry. The message goes on naming the position in its own
  words wherever there is one.
