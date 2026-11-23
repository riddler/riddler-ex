### Added

- `Riddler.Journey.Scope`, the scope a Journey runs under: `new/2` answers `{:ok, %Scope{kind: kind, id: id}}` for two strings of at least one byte and `{:error, :invalid_scope}` otherwise, `to_data/1` gives the data form a host keeps, `%{"kind" => kind, "id" => id}`, and `from_data/1` reads that form back, refusing anything else, a struct included; neither string is read for what it means, and the conformance corpus's new `journey.from_data` capability states what the data form and the values near it read back to.
