### Added

- `mix riddler.corpus` emits the conformance corpus and the JSON schemas into a
  riddler_spec checkout, byte-stable and with a `generated_by` header naming the
  version and the source file, refusing to emit a corpus this implementation
  does not satisfy; `--check` reports drift instead of writing.
