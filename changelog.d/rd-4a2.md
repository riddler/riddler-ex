### Removed

- **Breaking:** `Riddler.Screens.validate_responses/3` and `/4` are gone; call
  `Riddler.Screens.validate_screen/3` or `/4` with the same root you resolved
  the screen with, moving the responses map you used to pass into that root
  under `"responses"`.

### Added

- `Riddler.Screens.validate_screen/3` and `/4` validate against the root the
  host resolved with, so a required question a `context` condition showed the
  visitor is one the visitor can fail, where the removed pair resolved against
  an empty `context` and let the blank through.
