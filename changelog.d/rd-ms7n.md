### Changed

- `Riddler.Screens.Document.validate/1` refuses a button whose `outcome` is there and is not a string, `null` included, with a new `document.invalid_outcome` finding (its `field` `"outcome"`, its `node_key` the button's key), where 0.5.0 accepted the document; write each button's `outcome` as a string. A button with no `outcome` is still `document.missing_field` only, and the conformance corpus's `screens.admit` cases state the refusal.
