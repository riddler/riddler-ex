### Fixed

- A finding `Riddler.Screens.validate_screen/3` and `/4` raise carries a
  `node_key` that is a string or `nil`, as document validation's already did;
  a node keyed with anything else put that raw value on the finding before,
  which a host indexing findings by that field cannot look a node up by. Give
  every node a string `key`, which `Riddler.Screens.Document.validate/1`
  already asks for as `document.invalid_key`.
