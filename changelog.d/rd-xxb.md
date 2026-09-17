### Changed

- `Riddler.Screens.Document.validate/1` reports the envelope and boolean
  shapes the screen document record states, each only where the document
  carries the field: `document.invalid_schema_version` for a `schema_version`
  other than 1, `document.invalid_id` for an `id` that is not a string,
  `document.invalid_title` for a screen `title` that is not a string,
  `document.invalid_required` for a question's `required` that is not a
  boolean, and `document.invalid_validates` and `document.invalid_style` for a
  button's `validates` that is not a boolean and `style` that is not a string.
  A document that carried one of these off-shape validated clean before and
  now carries a finding; correct the field in the document, or omit it, since
  an absent field is unchanged and still raises nothing.
