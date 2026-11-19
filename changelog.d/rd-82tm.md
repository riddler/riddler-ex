### Added

- `Riddler.Journey.present/3` admits `{:screen, key, opts}`, where `opts` is a string-keyed map whose `"back"`, where present, is a boolean; `{:screen, key, %{}}` answers exactly what `{:screen, key}` answers, and an `opts` that is not a map, a struct included, or whose `"back"` is not a boolean answers `{:error, :unknown_status}`.
- The conformance corpus's `journey.present` cases state what a screen status with opts answers, its refusals included, and its `screens.admit` cases state the new refusal of a repeated outcome and its variant exception.

### Changed

- Every screen answer of `Riddler.Journey.present/3` carries `"moves"` beside `"screen"`: `{"outcomes": [...], "back": boolean}`, the outcome of each shown button in document order and `back` true only where the host passed `"back" => true` in the screen opts. A client reads what it may submit from `"moves"` rather than from the nodes; the existing `journey.present` screen cases in the corpus are restated with it, and the presented answer schema now requires it on a screen state.
- `Riddler.Screens.Document.validate/1` refuses a document in which two buttons that one screen can show together raise the same `outcome`, with the new finding `document.duplicate_outcome` on the later button (`field` `"outcome"`); buttons in different candidates of one variant are never shown together and are not compared. A document that was accepted before and has two such buttons is now refused: give each button its own outcome, or put the buttons in different candidates of a variant.
