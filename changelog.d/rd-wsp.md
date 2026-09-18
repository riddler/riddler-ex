### Fixed

- Response validation reports a screen's findings where a button carrying no
  key declared `validates` as `false` and the call named no pressed button; it
  answered `:ok` with every finding silenced before. Give every button in the
  document a `key`, which `Riddler.Screens.Document.validate/1` already asks
  for as `document.invalid_key`.
