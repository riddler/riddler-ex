### Added

- The `date`, `time` and `datetime` formats on a `text_question`: `date` is `YYYY-MM-DD`, a calendar date that exists; `time` is `HH:MM` or `HH:MM:SS`, 24-hour; `datetime` is a date and a time joined by `T`, then `Z` or an offset `+HH:MM` or `-HH:MM`, with no fraction of a second and no lower-case `t` or `z`. The response stays the string the visitor typed, read with the whitespace around it set aside; one that is not a string in the format's shape is `response.format`, and one before `min` or after `max` is `response.out_of_range`, both bounds inclusive. A `time` written `HH:MM` is the same time as `HH:MM:00`, and two `datetime` values are compared as the instants they name.
- The refusal the date and time formats bring: `document.invalid_bound`, its `field` the bound, for a `min` or `max` on a date, time or datetime question that is not a string in the format's shape, and, its `field` `"max"`, for a `min` after its `max`. A bound under a format that reads none is still consulted by nothing and raises nothing.
- The presented-answer schema enumerates `date`, `time` and `datetime` among a text question's formats. An answer carrying one of them does not validate against an earlier release's schema; a screen that uses none of them validates against both.

### Fixed

- A `min` or `max` that is not a number on a question whose format is `integer` or `number` is refused at admit as `document.invalid_bound`, its `field` the bound. riddler 0.8.0 admitted it and it bounded nothing, so a document carrying one, such as `"min": "18"` or `"max": null`, is now refused: write the bound as a number, or leave it out. A numeric `min` above its `max` is admitted as before.
