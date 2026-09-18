### Changed

- The `response.undecidable` finding now says which of three things left the
  condition undecided - the root could not decide it, it is not valid
  predicator, or it is not a string - and carries the source position the
  compiler or the evaluator gave for it in `position` and in the message,
  where there is one. The code, field and node key are unchanged, so a host
  switching on the code needs no edit; a host asserting on the message text
  reads a new sentence.
