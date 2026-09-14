### Added

- An element document is admitted from decoded JSON and validated on its own,
  with every reason it is refused reported at once: unknown node types,
  duplicate or misshapen keys, missing fields, heading levels out of range,
  conditions that do not parse, templates outside the subset, malformed
  writes, unknown formats, and variants that are empty or bury a default.
