### Fixed

- `Riddler.Screens.Document.admit/1` answers `nil` for a document whose `metadata` is written as `null`, as it does for any other value that is not an object, because the document schema types `metadata` as an object; a document that leaves `metadata` out is admitted exactly as before. A host that wrote `"metadata": null` writes an object, or leaves `metadata` out.
