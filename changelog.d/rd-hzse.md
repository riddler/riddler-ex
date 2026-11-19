### Added

- `Riddler.Journey.decode_submit/1` checks the shape of a submit a client sends back (`"screen"` and `"outcome"` strings, `"responses"` an object) and answers `{:ok, submit}` with exactly those three keys, or `{:error, findings}` coded `submit.not_an_object`, `submit.missing_field` or `submit.invalid_field`, one per defect; it never raises on a value a client can send.
- `priv/schemas/submit.schema.json` and `priv/schemas/finding.schema.json`, JSON Schemas (draft 7) for the submit and for a finding as a host sends it to a client, every one of its five keys present.
- The conformance corpus gains the capability `journey.decode_submit`, with its cases in `corpus/journey/decode_submit.json`.
