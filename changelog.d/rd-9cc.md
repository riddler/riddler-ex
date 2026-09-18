### Fixed

- `Riddler.Template.compile/1` and `Riddler.Screens.Document.validate/1` answer
  findings rather than raising for a template the parser refuses without saying
  where, such as `{% render %}` or `{% assign e %}`; the finding carries the
  `template.parse_error` code, no position, and a message that names no place.
