### Fixed

- `Riddler.Screens.Document.admit/1` answers `nil` for a document whose `id`,
  `kind`, screen `key` or `title`, or node `key`, `type` or `condition` is
  there and is not a string, `null` included, or whose `schema_version` is
  there and is not an integer. The published document schema already refused
  every one of them; 0.2.0 admitted them. Write each of those fields as a
  string, and `schema_version` as an integer, or leave it out.
- `document.invalid_id` and `document.invalid_title` are no longer raised: the
  only values that raised them are not a document.
