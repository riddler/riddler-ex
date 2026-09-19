### Fixed

- `Riddler.Screens.Document.admit/1` answers `nil` for a document carrying a
  `nodes` that is not a list of nodes on a node whose type reads none - every
  type but `variant`, and a type the package does not know. The published
  document schema already refused it; 0.2.0 admitted it and said nothing.
  Remove that `nodes`, or write it as a list of nodes, which is admitted and
  ignored.
