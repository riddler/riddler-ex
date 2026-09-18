### Fixed

- `{% liquid %}`, which the template subset excludes as an alternate spelling
  for tags it already admits, is refused where a template printed the
  characters of a `raw` or `comment` block's markers around it - from a string
  literal or from a bracket subscript - and so hid it from the check.
- `{% liquid %}` is refused where a block's end was read differently from the
  way the parser reads it: a closing tag carrying trailing tokens, as
  `{% endraw xyz %}` and `{% endraw "50%" %}` do, was run past, and a spelling
  that is not a closing tag at all, as `{% endraw, %}` and `{% endraw }} %}`
  are not, was taken for one.
