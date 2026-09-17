### Fixed

- A template that prints the characters of a `{% liquid %}` opener from a
  string literal compiles and renders them, instead of being refused as though
  it held the tag.
