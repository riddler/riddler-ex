### Added

- `mix riddler.upgrade PATH` rewrites the screen document in one file from version 1 to version 2, in place: `schema_version` becomes `2` and the `nodes` of every screen and every `variant` becomes `elements`, every other byte as written. A version 2 document is left as it is; a file that is not JSON, a document `admit/1` answers `nil` for, a version 1 document already carrying an `elements` key and a document of another version are refused with exit status 1, writing nothing.
- `Riddler.Screens.upgrade/1` makes the same rewrite on a decoded document, for a host's own migration, answering `{:ok, document}` or `{:error, :not_a_document | :other_version_spelling | :unsupported_version}`. Nothing at admit rewrites a document.
