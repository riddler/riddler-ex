### Added

- `Riddler.Template.compile/1` accepts a template only when every tag and
  filter in it is inside the template subset, reporting one `Riddler.Finding`
  per refused construct rather than the first.
- `Riddler.Template.render/3` renders a compiled template as text in lenient
  or strict mode, returning the paths that were missing in lenient and an
  error carrying them in strict.
