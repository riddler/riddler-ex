### Changed

- The `generated_by` header `mix riddler.corpus` writes into each emitted case
  file names the source file and no version, so an emitted corpus is
  byte-identical across releases; re-emit once to pick up the new header, and
  point anything that parsed a version out of that string at the request that
  carried the emit instead.
