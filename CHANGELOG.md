# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries for unreleased work are not written here directly. Each issue drops a
fragment in [`changelog.d/`](changelog.d/README.md); the fragments are assembled
into a version section at release. See that README for the format and for when a
change warrants an entry at all.

## [0.3.0] 2026-09-19

The conformance release after 0.2.0, and the first tag a runtime written in
another language can vendor the conformance corpus from. The corpus capability
`screens.validate_responses` is `screens.validate_screen`, and
`mix riddler.corpus` no longer reads `RIDDLER_SPEC_PATH` or defaults to
`../riddler_spec`: it refuses to run without `--to`. The template subset
refuses `{% liquid %}` wherever the parser reads one; 0.2.0 admitted it in some
spellings after a `raw` or `comment` marker, a conformance gap: a template this
runtime admitted in a spelling a runtime implementing the subset need not
accept. `Riddler.Screens.Document.admit/1` answers `nil` for field values and a
`nodes` the published document schema already refused, and the
`document.invalid_condition` and `response.undecidable` findings carry a source
position in `position` where there is one.

### Added

- The conformance corpus states that a refused tag inside an `if` block is
  the one finding, and that the closing tag ending the block is not refused;
  this package already answered that way.
- The conformance corpus states that a `when` operand the root does not carry
  is reported in both render modes: lenient mode renders the branch that holds
  and names the operand, and strict mode returns it as an error; this package
  already answered that way.

### Changed

- **Breaking:** the conformance corpus capability `screens.validate_responses`
  is now `screens.validate_screen`, and its cases moved from
  `corpus/screens/validate_responses.json` to
  `corpus/screens/validate_screen.json`. The capability was named for a
  function this package removed; it now names the one it calls. Nothing else
  about the cases changed and every case answers what it answered before. A
  runtime held to this corpus should dispatch on the new string and read the
  renamed file: the old string is an unknown capability, not an alias.
- The `document.invalid_condition` finding carries the source position its own
  message names, in `position`, for a condition the parser refused and located.
  A condition that never reached the parser - one that is not a string - still
  carries none, and its sentence still names none. The code, field, node key
  and message are unchanged, so a host switching on any of them needs no edit;
  a host reading `position` to point an author at the condition no longer has
  to parse that sentence for the line and the column.
- The `response.undecidable` finding now says which of three things left the
  condition undecided - the root could not decide it, it is not valid
  predicator, or it is not a string - and carries the source position the
  compiler or the evaluator gave for it in `position` and in the message,
  where there is one. The code, field and node key are unchanged, so a host
  switching on the code needs no edit; a host asserting on the message text
  reads a new sentence.

### Removed

- `mix riddler.corpus` no longer reads the `RIDDLER_SPEC_PATH` environment
  variable. Pass the export directory as `--to PATH` instead.
- `mix riddler.corpus` no longer defaults to `../riddler_spec`, and it refuses
  to run without `--to`, `--check` included. Pass `--to PATH` naming the
  directory to export into, or the directory holding the copy to compare.

### Fixed

- The characters of an excluded tag written as a bracket subscript, as in
  `{{ responses["{% liquid %}"] }}`, render as text instead of being refused,
  matching what the same characters in an ordinary string literal already did.
- A tag or filter outside the template subset written inside an `elsif` body or
  a `case` branch body is refused, where it compiled before.
- A variable guarded by `default` inside an `elsif` body or a `case` branch
  body is missing in neither render mode, as it already was everywhere else.
- `Riddler.Screens.Document.admit/1` answers `nil` for a document whose `id`,
  `kind`, screen `key` or `title`, or node `key`, `type` or `condition` is
  there and is not a string, `null` included, or whose `schema_version` is
  there and is not an integer. The published document schema already refused
  every one of them; 0.2.0 admitted them. Write each of those fields as a
  string, and `schema_version` as an integer, or leave it out.
- `document.invalid_id` and `document.invalid_title` are no longer raised: the
  only values that raised them are not a document.
- A finding `Riddler.Screens.validate_screen/3` and `/4` raise carries a
  `node_key` that is a string or `nil`, as document validation's already did;
  a node keyed with anything else put that raw value on the finding before,
  which a host indexing findings by that field cannot look a node up by. Give
  every node a string `key`, which `Riddler.Screens.Document.validate/1`
  already asks for as `document.invalid_key`.
- `{% liquid %}`, which the template subset excludes as an alternate spelling
  for tags it already admits, is refused where a template printed the
  characters of a `raw` or `comment` block's markers around it - from a string
  literal or from a bracket subscript - and so hid it from the check.
- `Riddler.Screens.Document.admit/1` answers `nil` for a document carrying a
  `nodes` that is not a list of nodes on a node whose type reads none - every
  type but `variant`, and a type the package does not know. The published
  document schema already refused it; 0.2.0 admitted it and said nothing.
  Remove that `nodes`, or write it as a list of nodes, which is admitted and
  ignored.
- Response validation reports a screen's findings where a button carrying no
  key declared `validates` as `false` and the call named no pressed button; it
  answered `:ok` with every finding silenced before. Give every button in the
  document a `key`, which `Riddler.Screens.Document.validate/1` already asks
  for as `document.invalid_key`.
- `{% liquid %}`, which the template subset excludes as an alternate spelling
  for tags it already admits, is refused wherever the parser reads one. In
  0.2.0 a liquid tag holding only admitted tags compiled after a `raw` or
  `comment` marker written in a string that an `endif`, `else`, `endfor`,
  `comment` or `endcomment` tag discards, after a comment whose opener carried
  trailing text, or after a `raw` or `comment` block whose closer carried
  trailing text. That was a conformance gap: a template this runtime admitted
  in a spelling a runtime implementing the subset need not accept.
- The characters of a liquid tag inside a `raw` or `comment` block are text
  where the block's opener or closer carries trailing text, as they are
  everywhere else inside such a block; 0.2.0 refused the template.

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
