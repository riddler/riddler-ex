### Added

- `Riddler.Journey.present/3` presents the status a host passes - `{:screen, key}`, `:waiting` or `:done` - as a string-keyed map whose `"state"` is `"screen"`, `"waiting"` or `"done"`, a screen carrying its resolved nodes and diagnostics, and `Riddler.Journey.put_context/2` replaces a root's `"context"` whole with the responses untouched; the corpus holds both as `journey.present` and `journey.put_context`.
