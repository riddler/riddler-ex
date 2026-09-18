### Fixed

- A tag outside the template subset written between the characters of a `raw`
  or `comment` block's opener and closer is refused, where a template printing
  those characters - from a string literal or from a bracket subscript - hid it
  from the check and let it execute.
- A verbatim block whose closing tag carries trailing text, as
  `{% endraw xyz %}` does, ends where the parser ends it, so a tag written
  after it is checked rather than skipped.
