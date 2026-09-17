### Changed

- A question that asks for the `pattern` format and declares a `pattern` that
  format cannot compile is now a finding against the document,
  `document.invalid_pattern` from `Riddler.Screens.Document.validate/1`,
  raised before a visitor arrives. Response validation no longer reports it:
  the defect is in the document, and nothing a visitor could type would
  satisfy such a pattern. This is breaking for a host that matched the old
  `response.format` finding with the field `pattern` on submission for such a
  question - read `document.invalid_pattern` from document validation instead,
  and correct the expression in that question. A `pattern` on a question that
  asks for another format, or for none, is unchanged: it is a field nothing
  consults, and it carries no finding at either layer whatever it says. A
  question naming the `pattern` format and declaring no pattern at all is
  unchanged too and still answers `response.format` with the field `pattern`,
  under new wording that names the missing pattern rather than calling it
  unusable.
