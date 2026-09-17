### Changed

- **Breaking:** `Riddler.Screens.validate_screen/3` and `/4` answer
  `{:error, [%Riddler.Finding{code: "response.undecidable"}]}` where they
  answered `:ok` for a screen carrying a condition the root could not decide;
  the finding names the node in `node_key` and `"condition"` in `field`. A
  button declaring `validates` as `false` is unaffected and still answers `:ok`
  without running a check. Carry in the root every `context` and
  `responses` key the document's conditions read, giving a key the visitor has
  not answered yet its blank value rather than leaving it out, or change the
  condition to one that decides against a root without it.
