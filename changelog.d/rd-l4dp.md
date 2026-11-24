### Added

- A screen document may declare `schema_version` 2, which spells the children of a screen and of a `variant` `elements`; a version 1 document, or one declaring no version, still spells them `nodes` and is admitted, validated and resolved as before.
- `document.other_version_spelling` refuses a screen or a `variant` carrying the other version's key, `nodes` at version 2 or `elements` at version 1, with one finding naming the key; nothing under that key is read, and nothing is rewritten at admit.

### Changed

- `Riddler.Finding`'s field `node_key` is `element_key`, the same value by the same rule; read `finding.element_key` where you read `finding.node_key`.
- The admitted `Riddler.Screens.Document` and the resolved `Riddler.Screens.Resolved` carry a screen's and a `variant`'s children as `elements` where they carried `nodes`, for a document of either version; read or match `elements`.
- `Riddler.Screens.Type.node_t/0` is `Riddler.Screens.Type.element/0`, and `Riddler.Screens.Type.Variant` names its candidates `:elements` in `fields/0` and `"elements"` in the field of its own findings.
- A version 1 document whose screen or `variant` carries an `elements` key, which was dropped before, is refused with `document.other_version_spelling`: remove the key from the document, or write the document at version 2.
- The screen document schema types `elements` beside `nodes` on a screen and an element and requires a screen to carry one of the two; a host validating documents against it before admitting them takes the new schema.
