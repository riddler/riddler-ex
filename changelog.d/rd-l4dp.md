### Added

- A screen document may declare `schema_version` 2, which spells the children of a screen and of a `variant` `elements`; a version 1 document, or one declaring no version, still spells them `nodes` and is admitted, validated and resolved as before.
- `document.other_version_spelling` refuses a screen or a `variant` carrying the other version's key, `nodes` at version 2 or `elements` at version 1, with one finding naming the key; nothing under that key is read, and nothing is rewritten at admit. At version 1 the refused `elements` may hold any value, as 0.7.0 dropped it.

### Changed

- `Riddler.Finding`'s field `node_key` is `element_key`, the same value by the same rule; read `finding.element_key` where you read `finding.node_key`.
- The admitted `Riddler.Screens.Document` and the resolved `Riddler.Screens.Resolved` carry a screen's and a `variant`'s children as `elements` where they carried `nodes`, for a document of either version; read or match `elements`.
- `Riddler.Screens.Type.node_t/0` is `Riddler.Screens.Type.element/0`, and `Riddler.Screens.Type.Variant` names its candidates `:elements` in `fields/0` and `"elements"` in the field of its own findings when it is called directly (`Riddler.Screens.Document.validate/1` at version 1 still answers `"nodes"`).
- A version 1 document whose screen or `variant` carries an `elements` key, which was dropped before, is refused with `document.other_version_spelling`: remove the key from the document, or write the document at version 2.
- The screen document schema types `elements` beside `nodes`, requires a screen to carry one of the two, and types `elements` on a screen and an element only where a document is read from `elements`, at version 2; a host validating documents against it before admitting them takes the new schema.
- A document at a schema version this package does not implement, written in the `elements` form, is now admitted and refused with `document.invalid_schema_version`, where 0.7.0 answered `nil` for it.
