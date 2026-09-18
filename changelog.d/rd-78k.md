### Changed

- **Breaking:** the conformance corpus capability `screens.validate_responses`
  is now `screens.validate_screen`, and its cases moved from
  `corpus/screens/validate_responses.json` to
  `corpus/screens/validate_screen.json`. The capability was named for a
  function this package removed; it now names the one it calls. Nothing else
  about the cases changed and every case answers what it answered before. A
  runtime held to this corpus should dispatch on the new string and read the
  renamed file: the old string is an unknown capability, not an alias.
