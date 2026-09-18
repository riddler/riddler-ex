### Fixed

- A tag or filter outside the template subset written inside an `elsif` body or
  a `case` branch body is refused, where it compiled before.
- A variable guarded by `default` inside an `elsif` body or a `case` branch
  body is missing in neither render mode, as it already was everywhere else.
