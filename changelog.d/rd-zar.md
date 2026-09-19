### Fixed

- `{% liquid %}`, which the template subset excludes as an alternate spelling
  for tags it already admits, is refused wherever the parser reads one. In
  0.2.0 a liquid tag holding only admitted tags compiled after a `raw` or
  `comment` marker written in a string that an `endif`, `else`, `endfor`,
  `comment` or `endcomment` tag discards, after a comment whose opener carried
  trailing text, or after a `raw` or `comment` block whose closer carried
  trailing text. That was a conformance gap: a template this runtime admitted
  in a spelling a runtime implementing the subset need not accept.
- The characters of a liquid tag inside a `raw` or `comment` block are text
  where the block's opener or closer carries trailing text, as they are
  everywhere else inside such a block; 0.2.0 refused the template.
