### Fixed

- A tag outside the template subset written between output tags that print the
  characters of a `raw` or `comment` block's opener and closer is refused,
  where it was admitted and executed before.
