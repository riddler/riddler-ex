### Added

- The JSON schemas ship in the package, so a host that validates a document
  against one at runtime can read it from
  `Application.app_dir(:riddler, "priv/schemas")` instead of vendoring a copy.
