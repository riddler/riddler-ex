# ADR-0004: A release workflow publishes to Hex on the push of a version tag, and only from a green, matching commit on the default branch

Status: proposed. It is accepted once a version of this package has been
published through the workflow it records; this record does not flip its own
status.

The move to publishing on the tag push was ruled by the operator,
2026-10-04. The shape of the workflow - it runs the gate itself, reads the
default branch from the push event, reads the version from `mix.exs` at the
tagged commit, copies its toolchain from `ci.yml`, and has no manual
trigger - was decided by the conductor under a standing consent, 2026-10-03.
The docs decision, the failed-publish rule and the check against versions
Hex already shows were decided by the conductor under a standing consent,
2026-10-04.

## Context

**What a release is here today.** A release prep - the version bump in
`mix.exs`, the README install pin and the promotion of the `changelog.d/`
fragments - lands through the ordinary commit, push and request rows of
`CLAUDE.md`'s authority table, and once it is merged the session that owns
the release tags the merged commit and pushes the tag (`CLAUDE.md`, the
release-prep row and the "Release preps" paragraph; `.claude/wurk/release.md`,
"What a release here still is not"). Until this record, one step stayed
outside that flow: `mix hex.publish`, run by hand from a maintainer's
checkout with a maintainer's Hex credentials.

**What the hand step costs.** A hand publish is the one release step nothing
checks. Whether the commit published is the commit that was tagged, whether
it is on the default branch, whether `@version` names the tag, and whether
the full gate is green at that commit are each a fact the person publishing
has to establish in their own checkout, every time. It is also the step that
waits on a person after every other step has finished.

**What must not move.** A published Hex version stands (decision 6), so
whatever publishes has to refuse anything it cannot prove is the reviewed,
gated, tagged commit. No agent holds a Hex key, and nothing in this
repository may carry one. The tag matters beyond Hex here too: a runtime in
another language vendors the conformance corpus from a tag of this
repository (`CLAUDE.md`, "What this project is"), so a tag is never moved to
make a publish work.

## Decision

1. **The trigger.** `.github/workflows/release.yml` runs on `push` of a tag
   matching `v*.*.*` and on nothing else: no branch push, no pull request,
   no `workflow_dispatch`. The tag push is the one the release-prep row of
   `CLAUDE.md` already allows. One run per tag (`concurrency` keyed by the
   tag), and a run in progress is never cancelled. The workflow token is
   read-only (`permissions: contents: read`).

2. **Three conditions, checked at the tagged commit.** The workflow
   publishes only when all three hold, and each one that fails stops the
   run with nothing published. The first two are checked before anything
   is built:
   - the tagged commit is on the default branch: the branch is read from the
     push event (`github.event.repository.default_branch`), never written as
     a literal, fetched under that name, and asked with
     `git merge-base --is-ancestor` (the step "Check the tagged commit is on
     the default branch");
   - the tag without its leading `v` equals `@version` in `mix.exs` at the
     tagged commit (the step "Check the tag names the version in mix.exs");
   - the full quality gate is green at the tagged commit: the `gate.full`
     command read from `.claude/wurk.json` (today `mix quality`), run on the
     toolchain `ci.yml` provisions, its steps copied from `ci.yml` rather
     than shared (the step "Full quality gate"). A red gate publishes
     nothing.

   Before the toolchain is installed, the workflow also asks Hex whether it
   already shows the version (the step "Check Hex does not already show this
   version"): a version Hex shows is reported and never published again, and
   an answer other than "not found" stops the run.

3. **The registry and the key.** The registry is Hex (hex.pm), package
   `riddler`. The workflow publishes with `mix hex.publish --yes`,
   authenticated by the `HEX_API_KEY` secret - an organisation secret the
   maintainers set up outside this repository and scope to it - which only
   the step "Publish to Hex" reads, through its own `env:`. No other step
   sees it, and no file in this repository carries a key, a token or a
   secret value. The run ends by printing the address of the published
   version on hex.pm and on HexDocs.

4. **The docs publish with the package.** `mix hex.publish` builds and
   publishes the docs with the package by default, and the workflow keeps
   that default, so HexDocs shows every version's documentation, these
   records among its extras, as it does today. The docs that publish are
   the docs the gate's Docs stage has just built warning-free at the same
   commit (`.quality.exs`, the `docs` stage).

5. **A failed publish.** The workflow never retries. A run that stops at a
   check or at the gate publishes nothing, and the tag stands as the record
   of what was attempted: the fix lands on the default branch and the next
   version is tagged; a tag is never moved or pushed again. A run whose
   publish step failed on a registry or network error is re-run once, by
   hand, from the run's page in the repository's Actions tab, on the same
   commit and tag (a re-run repeats every check and the gate before it
   reaches the publish); a run that stopped at a check or at the gate is
   never re-run, and a second failure of the publish step goes to the
   maintainers. A re-run after a publish that
   did land is answered by the check against versions Hex already shows,
   not by a second publish. A publish that lands the package but fails on
   the docs leaves the version on hex.pm without docs; a re-run then stops
   at that same check, and the missing docs go to the maintainers. An agent
   or a session never runs `mix hex.publish` in any form to work round a
   failed workflow; what the maintainers do with a failure handed to them
   is theirs to decide, outside this workflow.

6. **A published version stands.** On hex.pm a version can be replaced or
   reverted only within one hour of its publication; after that it can only
   be retired, which marks it and leaves it installable. Neither is a step
   of this workflow, and neither is an agent's.

## Consequences

- `CLAUDE.md`'s release-prep row, its relay paragraph and its "Release
  preps" paragraph, and `.claude/wurk/release.md`'s closing paragraph, say
  the same thing in the maintainers' words: an agent or a session never
  runs the publish; the release workflow publishes on the tag push; a
  failed workflow is re-run from its Actions page, never worked round by a
  local publish.
- Every release runs the full gate one more time, on the runner, at the
  tagged commit. That is the cost of a publish that does not depend on a
  separate CI result for the same commit being found and trusted.
- The toolchain, the cache and the gate steps are copies of `ci.yml`'s. A
  change to how `ci.yml` provisions the toolchain or runs the gate is made
  in both files in the same change.
- GitHub creates no push event when more than three tags are pushed at
  once, so a release tag is pushed on its own.
- Nothing in `lib/` changes and no package behaviour changes: this record
  decides how a version reaches Hex, not what any version contains. It
  carries no typespecs or worked example for that reason.
- This record is accepted under the family's standard once a version has
  been published through the workflow, with that run as the evidence.
