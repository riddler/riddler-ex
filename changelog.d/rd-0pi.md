### Added

- A finding carries `:position`, the `%{line: line, column: column}` in the
  source it refused, so an editor can point at a refused template construct
  without parsing the message. A template refusal sets it wherever the parser
  gave it a place, and a `document.invalid_template` finding carries the
  position of the template refusal it wraps; a refusal with no place - a parse
  error the parser could not locate, or a finding about the document itself -
  leaves it `nil`, and the message goes on naming the position in its own
  words.
