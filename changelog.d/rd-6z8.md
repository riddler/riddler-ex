### Removed

- `mix riddler.corpus` no longer reads the `RIDDLER_SPEC_PATH` environment
  variable. Pass the export directory as `--to PATH` instead.
- `mix riddler.corpus` no longer defaults to `../riddler_spec`, and it refuses
  to run without `--to`, `--check` included. Pass `--to PATH` naming the
  directory to export into, or the directory holding the copy to compare.
