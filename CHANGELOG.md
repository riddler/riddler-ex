# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries for unreleased work are not written here directly. Each issue drops a
fragment in [`changelog.d/`](changelog.d/README.md); the fragments are assembled
into a version section at release. See that README for the format and for when a
change warrants an entry at all.

## [0.1.0] 2026-09-14

The first release. Riddler is a dynamic content runtime: a host authors content
as JSON documents - screens now; emails, images and feature flags forthcoming -
and Riddler resolves each against a visitor's context, while the host renders,
sends or serves what comes back. A document is admitted and validated on its
own, resolved against a host's context and a visitor's responses into the nodes
that visitor is shown, its templates compiled and rendered against the subset,
and the responses it collects validated against the screen they were shown. The
conformance corpus is authored here and emitted into riddler_spec so a second
implementation runs the same cases.

### Added

- `Riddler.Template.compile/1` accepts a template only when every tag and
  filter in it is inside the template subset, reporting one `Riddler.Finding`
  per refused construct rather than the first.
- `Riddler.Template.render/3` renders a compiled template as text in lenient
  or strict mode, returning the paths that were missing in lenient and an
  error carrying them in strict.
- A screen document is admitted from decoded JSON and validated on its own,
  with every reason it is refused reported at once: unknown node types,
  duplicate or misshapen keys, missing fields, heading levels out of range,
  conditions that do not parse, templates outside the subset, malformed
  writes, unknown formats, and variants that are empty or bury a default.
- A visitor's responses are validated against the screen they were shown:
  `required`, the `email`, `phone`, `pattern`, `integer` and `number` formats,
  and `min` and `max` on the numeric ones, with a question a condition hid
  unable to fail and a button declaring `validates` false able to submit
  without any check at all. A question may now carry `pattern`, `min` and
  `max` beside its `format`.
- A screen document resolves against a host's context and a visitor's
  responses into the nodes that visitor is shown, with hidden nodes absent,
  every container collapsed to its winner, every template rendered, and what
  could not be decided reported rather than refused.
- `mix riddler.corpus` emits the conformance corpus and the JSON schemas into a
  riddler_spec checkout, byte-stable and with a `generated_by` header naming the
  version and the source file, refusing to emit a corpus this implementation
  does not satisfy; `--check` reports drift instead of writing.
- A document's envelope carries `kind`, the content kind it belongs to. It is
  an optional string and it defaults to `screens`, so a document that names
  none is a screen document; the decided kind is carried through to the
  resolved document, and a kind this package has no runtime for is a
  `document.unknown_kind` finding naming the value.

### Changed

- The screens kind is named after the kind rather than after the nodes inside
  a screen: `Riddler.Elements` and everything under it is now
  `Riddler.Screens`, and the corpus capabilities `elements.admit`,
  `elements.resolve` and `elements.validate_responses` are now `screens.admit`,
  `screens.resolve` and `screens.validate_responses`, emitted from
  `corpus/screens/`. No `Riddler.Elements` name and no `elements.*` capability
  survives this release. `templates.render` is unchanged.
