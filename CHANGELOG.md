# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries for unreleased work are not written here directly. Each issue drops a
fragment in [`changelog.d/`](changelog.d/README.md); the fragments are assembled
into a version section at release. See that README for the format and for when a
change warrants an entry at all.

## [0.2.0] 2026-09-18

The residue wave after the first release. `Riddler.Screens.validate_responses/3`
and `/4` give way to `Riddler.Screens.validate_screen/3` and `/4`, which validate
against the same root the host resolved the screen with, and
`Riddler.Screens.resolve_screen/3` answers its diagnostics alongside the screen.
A condition the root cannot decide is a finding rather than a silent pass, and a
button that declares it validates nothing is unaffected. A `pattern` the format
cannot compile is refused against the document before a visitor arrives, the
document schema is emitted as `schemas/screen-document.schema.json` and the
schemas ship in the package, and the emitted corpus header names no version, so
an emitted corpus is byte-identical across releases. A finding carries the
position in the source it refused, and a template the parser refuses without
saying where answers a finding rather than raising.

### Added

- A finding carries `:position`, the `%{line: line, column: column}` in the
  source it refused, so an editor can point at a refused template construct
  without parsing the message. A template refusal sets it, and a
  `document.invalid_template` finding carries the position of the template
  refusal it wraps; every other finding leaves it `nil`. The message goes on
  naming the position in its own words wherever there is one.
- `Riddler.Screens.validate_screen/3` and `/4` validate against the root the
  host resolved with, so a required question a `context` condition showed the
  visitor is one the visitor can fail, where the removed pair resolved against
  an empty `context` and let the blank through.
- The JSON schemas ship in the package, so a host that validates a document
  against one at runtime can read it from
  `Application.app_dir(:riddler, "priv/schemas")` instead of vendoring a copy.

### Changed

- **Breaking:** `Riddler.Screens.resolve_screen/3` answers
  `{:ok, screen, diagnostics}` where it answered `{:ok, screen}`; match on the
  three-element tuple and read `missing_variables` and `undecidable_conditions`
  from `diagnostics`, which is the shape `resolve/2` already carries on a
  resolved document, narrowed to the one screen. A caller that only wants the
  screen matches `{:ok, screen, _diagnostics}`. `{:error, :no_such_screen}` is
  unchanged, and so is every other function in the module.
- **Breaking:** `Riddler.Screens.validate_screen/3` and `/4` answer
  `{:error, [%Riddler.Finding{code: "response.undecidable"}]}` where they
  answered `:ok` for a screen carrying a condition the root could not decide;
  the finding names the node in `node_key` and `"condition"` in `field`. A
  button declaring `validates` as `false` is unaffected and still answers `:ok`
  without running a check. Carry in the root every `context` and
  `responses` key the document's conditions read, giving a key the visitor has
  not answered yet its blank value rather than leaving it out, or change the
  condition to one that decides against a root without it.
- A question that asks for the `pattern` format and declares a `pattern` that
  format cannot compile is now a finding against the document,
  `document.invalid_pattern` from `Riddler.Screens.Document.validate/1`,
  raised before a visitor arrives. Response validation no longer reports it:
  the defect is in the document, and nothing a visitor could type would
  satisfy such a pattern. This is breaking for a host that matched the old
  `response.format` finding with the field `pattern` on submission for such a
  question - read `document.invalid_pattern` from document validation instead,
  and correct the expression in that question. A `pattern` on a question that
  asks for another format, or for none, is unchanged: it is a field nothing
  consults, and it carries no finding at either layer whatever it says. A
  question naming the `pattern` format and declaring no pattern at all is
  unchanged too and still answers `response.format` with the field `pattern`,
  under new wording that names the missing pattern rather than calling it
  unusable.
- The document schema is emitted as `schemas/screen-document.schema.json`;
  point a consumer that reads the schema by its old path at the new one.
- The `generated_by` header `mix riddler.corpus` writes into each emitted case
  file names the source file and no version, so an emitted corpus is
  byte-identical across releases; re-emit once to pick up the new header, and
  point anything that parsed a version out of that string at the request that
  carried the emit instead.
- `Riddler.Screens.Document.validate/1` reports the envelope and boolean
  shapes the screen document record states, each only where the document
  carries the field: `document.invalid_schema_version` for a `schema_version`
  other than 1, `document.invalid_id` for an `id` that is not a string,
  `document.invalid_title` for a screen `title` that is not a string,
  `document.invalid_required` for a question's `required` that is not a
  boolean, and `document.invalid_validates` and `document.invalid_style` for a
  button's `validates` that is not a boolean and `style` that is not a string.
  A document that carried one of these off-shape validated clean before and
  now carries a finding; correct the field in the document, or omit it, since
  an absent field is unchanged and still raises nothing.

### Removed

- **Breaking:** `Riddler.Screens.validate_responses/3` and `/4` are gone; call
  `Riddler.Screens.validate_screen/3` or `/4` with the same root you resolved
  the screen with, moving the responses map you used to pass into that root
  under `"responses"`.

### Fixed

- A variable used only in the condition of an `unless` is no longer reported
  as missing, in either render mode, which is what an `if` condition already
  did.
- `Riddler.Template.compile/1` and `Riddler.Screens.Document.validate/1` answer
  findings rather than raising for a template the parser refuses without saying
  where, such as `{% render %}` or `{% assign e %}`; the finding carries the
  `template.parse_error` code, no position, and a message that names no place.
- `Riddler.Screens.Document.validate/1` tells an author that a node or screen
  key is not a string instead of telling them there is no key: a key of the
  wrong form keeps `document.invalid_key` and now carries a message naming the
  key that was written, distinct from the message for a key that is absent. A
  host matching on the message rather than on the code sees the new wording.
- A finding's `node_key` is always a string or `nil`, as `Riddler.Finding`'s
  typespec has always said. A node whose key was not a string used to put that
  key on every other finding about the node; those findings now carry `nil`,
  the same as a node that declares no key at all, and the key is named in the
  message. A host indexing findings by `node_key` no longer has to expect a
  value it cannot look a node up by.
- A template that prints the characters of a `{% liquid %}` opener from a
  string literal compiles and renders them, instead of being refused as though
  it held the tag.

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
