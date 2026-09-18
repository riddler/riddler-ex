### Fixed

- The characters of a tag outside the subset written as a bracket subscript,
  as in `{{ responses["{% liquid %}"] }}`, render as text instead of being
  refused, matching what the same characters in an ordinary string literal
  already did.
