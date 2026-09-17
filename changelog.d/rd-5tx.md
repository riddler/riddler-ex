### Fixed

- A variable used only in the condition of an `unless` is no longer reported
  as missing, in either render mode, which is what an `if` condition already
  did.
