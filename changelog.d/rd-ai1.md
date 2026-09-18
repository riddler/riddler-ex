### Changed

- The `document.invalid_condition` finding carries the source position its own
  message names, in `position`, for a condition the parser refused and located.
  A condition that never reached the parser - one that is not a string - still
  carries none, and its sentence still names none. The code, field, node key
  and message are unchanged, so a host switching on any of them needs no edit;
  a host reading `position` to point an author at the condition no longer has
  to parse that sentence for the line and the column.
