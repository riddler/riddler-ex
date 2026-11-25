# Move a host from 0.7.0 to elements

This page shows how to move a host that runs riddler 0.7.0 to the version that
calls a screen's children elements. It uses patron registration: a host that
stores the library card application screens as JSON and presents them to
visitors.

Three keys were renamed, and two names that point at them moved with them
(listed below). One case that 0.7.0 admitted is now refused (see "What stays
working").

| Where | 0.7.0 | Now |
|---|---|---|
| a screen document, on a screen and on a `variant` | `nodes` | `elements` |
| the presented answer `Riddler.Journey.present/3` returns, on a screen | `"nodes"` | `"elements"` |
| a `Riddler.Finding`, and its data form | `node_key` | `element_key` |

The value of `element_key` is the one `node_key` carried, by the same rule.

## What stays working

A document that declares `schema_version` 1, or none, is still admitted,
validated and resolved, and still spells its children `nodes`, with one
exception: a version 1 document whose screen or `variant` also carries an
`elements` key was accepted by 0.7.0, which dropped the key, and is now
refused with `document.other_version_spelling`. Remove the key, or rewrite
the document at version 2. You can move
the code first and the stored documents later. The presented answer and the
findings use the new keys for a document of either version, so the change to
your clients does not wait on your documents.

This page promises no date and no version for the end of version 1 support.
The end follows the hosts' own rewrite of their documents to version 2.

## Change what reads the answers

1. Where you read `finding.node_key`, read `finding.element_key`.
2. Where a client reads `screen["nodes"]` from a presented answer, read
   `screen["elements"]`. Where it reads `finding["node_key"]` from a finding's
   data form, read `finding["element_key"]`.
3. Where you match on the `nodes` of an admitted `Riddler.Screens.Document` or
   of a resolved screen, match on `elements`.
4. If you validate against the JSON schemas in the package, take the new
   copies: the presented answer and finding schemas require the new keys, and
   the screen document schema types `elements` beside `nodes`. A `$ref` to
   `#/definitions/node` becomes `#/definitions/element`.
5. Where you name `Riddler.Screens.Type.node_t/0` in a typespec, name
   `Riddler.Screens.Type.element/0`.

## Rewrite the stored documents

A stored version 1 document is rewritten with the upgrade task, one file at a
time:

```
mix riddler.upgrade priv/screens/patron_registration.json
```

The task sets `schema_version` to `2` and renames the `nodes` of every screen
and every `variant` to `elements`, leaving every other byte of the file as it
was. A version 2 document is left as it is, so running the task twice is
running it once.

The task exits with status 1, writing nothing, when the path cannot be read,
the file is not JSON, `Riddler.Screens.Document.admit/1` answers `nil` for the
document, a version 1 document already carries an `elements` key on a screen
or an element, the document is at another version, or the edited text would
not decode to the document `Riddler.Screens.upgrade/1` answers. The message
names which. A document that was wrong before the rewrite is wrong in the same
way after it.

For documents in a database, call `Riddler.Screens.upgrade/1` on each decoded
document and store what it answers:

```elixir
{:ok, version_two} = Riddler.Screens.upgrade(decoded_document)
```

It answers `{:error, :not_a_document | :other_version_spelling | :unsupported_version}`
for the refusals above that apply to a decoded document. Nothing at admit
rewrites a document; only a call to the task or to this function does.

## Check it worked

Admit and validate a rewritten document, then present one of its screens and
read `"elements"` in the answer:

```elixir
document = Riddler.Screens.Document.admit(version_two)
{:ok, ^document} = Riddler.Screens.Document.validate(document)
```

A document that spells `nodes` at version 2, or `elements` at version 1, is
refused with `document.other_version_spelling`, which names the key.
