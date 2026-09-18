### Fixed

- A tag outside the template subset is refused where a template printed the
  characters of a `raw` or `comment` block's markers around it, from a string
  literal or from a bracket subscript, and so hid it from the check.
- A tag outside the subset is refused where a block's closing tag carried
  trailing tokens - `{% endraw xyz %}` and `{% endraw "50%" %}` among them -
  and the block was read as running past that closer to a later one.
