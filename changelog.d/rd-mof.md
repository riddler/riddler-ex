### Fixed

- `{% liquid %}`, which the template subset excludes as an alternate spelling
  for tags it already admits, is refused where a template printed the
  characters of a `raw` or `comment` block's markers around it - from a string
  literal or from a bracket subscript - and so hid it from the check.
