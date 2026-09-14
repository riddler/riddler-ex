# Release extension

Additional required steps for `/wurk:release` in this repo. The skill reads
this file before step 1 of its `kind: "hex"` recipe and treats what is here as
required steps placed where this file says. Extensions add; they never
override, and nothing below rewrites a step the skill already performs.

Read this together with `.claude/wurk.json`'s `release` block. Between them
they name every file a release commit here touches, and no others.

The reference for every shape below is **the most recent release-prep commit
on `main`**, resolved when you read this rather than named here. Find it with:

```bash
git log --oneline --no-patch -L '/@version/,+1:mix.exs'
```

The first line is the last commit that moved `@version`, and the last commit
that moved `@version` is the last release prep by definition. Until the first
prep lands that command resolves to the scaffold commit instead, and there is
no reference to read; the first-release section below is what applies then.

Where this file and the reference commit disagree, the commit is the evidence
and this file is the defect.

**This file names no SHA for that reference, on purpose, and it carries no
version string anywhere except in the historical claims below.** A hard-coded
reference stops being the most recent the moment the next release lands.
Nothing here needs editing at a release, and a release commit does not touch
this file - the table at the end lists every file it does touch, and this is
not one of them.

## Why the recipe names no changelog

`kind: "hex"`'s changelog step renames a `## [Unreleased]` heading in one file
to `## [X.Y.Z] - YYYY-MM-DD`. This repo has no such heading and never will:
`changelog.mode` is `fragments`, and `CHANGELOG.md` says so in its own header -
unreleased work lives one file per issue in `changelog.d/`, and the fragments
are assembled into a version section at release. Pointing `release.changelog`
at `CHANGELOG.md` would make the skill's precondition read for an unreleased
section that is not there, and its edit rename a heading that does not exist.

So `release.changelog` is deliberately absent, and a recipe that does not name
a changelog names no changelog edit. The promotion this repo actually performs
is the step below - a required step, not an optional one. A release commit
without it is not a release commit.

The unreleased-work check the skill makes before anything else reads
`changelog.d/` here: if the directory holds no fragment other than its own
`README.md`, there is nothing to release, and the run stops exactly as it
would on an empty unreleased section.

## What a first release does instead

The kit's `kind: "hex"` recipe cannot cut a *first* release in this repo, and
that is not a defect in either of them. Its step 0 refuses on two independent
grounds:

- the requested version must be **strictly greater** than the one in
  `release.version_file`, and it stops on equal;
- it reads the changelog's unreleased section and stops when that section is
  missing. Under `fragments` there is never one to read, and the fragment
  directory this repo substitutes is not what step 0 looks at.

This package is scaffolded at `0.0.1`, which is not the version it first
publishes, so the first ground does not apply here and the version step has a
value to move off. The second ground does apply and always will. So the first
release goes through the checked-in At-release path - the "At release" section
of [`changelog.d/README.md`](../../changelog.d/README.md), performed by hand
and reviewed as a diff - with the version bump and the README pin done the
same way, not through `/wurk:release`. Every release after the first is an
ordinary `/wurk:release` run with the promotion step below.

## The required step: promote the changelog fragments

Placed where the skill's changelog step would have been.

1. Read every `changelog.d/*.md` fragment except `README.md`. Each is a Keep a
   Changelog section heading followed by its bullets.
2. Insert a new `## [X.Y.Z] YYYY-MM-DD` section into `CHANGELOG.md` directly
   above the previous version's section, or directly under the file's header
   paragraphs when there is no previous section. The heading form is the
   bracketed version and the date, with no separator between them.

   **The date is the operator's local date, not UTC.** A prep run late in the
   local evening is cut under a UTC date that is already tomorrow; writing
   that UTC date puts a section in the file dated a day the release was not
   cut on, and a reader comparing it against the tag or the commit date sees a
   discrepancy that is not real. Take the date from `date +%F` on the machine
   cutting the prep and write that.
3. Under the heading, write a short lead paragraph saying what the release is,
   then the fragments' bullets grouped by heading and ordered `Added`,
   `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.

   Within one heading, when more than one fragment contributed bullets to it,
   the fragments go in **fragment-name order** - `changelog.d/rd-56a.md`
   before `changelog.d/rd-8v1.md` - and each fragment's own bullets keep the
   order they have in their file. That is an arbitrary but stable rule, and
   stable is the point: it is not a judgement about which change matters most,
   so no release worker has to make one. `changelog.d/README.md` states the
   same rule from the other side.

   **Carry every bullet over byte for byte.** The lead paragraph is the only
   prose written at release time; reordering, consolidating or rewording a
   fragment's bullet is an editorial pass a human does separately, before the
   release.
4. Delete the promoted fragment files in the same commit. `README.md` stays.

This file's changelog has no link-reference block at the end, and a release
here adds no `[X.Y.Z]:` line because there is no block for it to go in. Adding
one is a change to the file's shape, not a release step.

Whether the release is major, minor or patch is not decided here - the version
is explicit input to the skill. The fragments' headings are evidence for that
judgement, not a rule that computes it.

## The README install pin: write the `.0` form

`release.readme_pin` is `true`. `README.md` carries a
`{:riddler, "~> X.Y.0"}` pin in its `def deps` snippet, and a release moves
it. It is a step here rather than a note, because the form the pin takes is
this repo's own and not the skill's default: the skill's own pin step writes
the major/minor form with the patch component dropped, and that is **not**
what this README should end up with.

The pin is written to the exact minor that the release cuts, patch component
`0` included - `~> 0.5.0` for a 0.5.0 release, not `~> 0.5`. That is the form
the pre-1.0 banner at the top of the same README recommends to consumers, and
a snippet that shows a looser pin than the banner asks for contradicts the
banner a couple of dozen lines above it. So a prep that finds the skill has
written `~> X.Y` finishes the job by hand and restores the `.0`.

The pin's current value is not written down here, for the same reason no
current version is. Read it and check it against the version file instead:

```bash
grep 'riddler, "~>' README.md   # the pin
grep '@version "' mix.exs       # the version it should track
```

They should agree on major and minor, and the pin's patch component should be
`0`. If they ever do not agree, the pin edit repairs the drift in one move
rather than stepping one release at a time: it goes straight to the current
major/minor with a `.0` patch, and that is the recipe working, not a mistake
to correct back.

## No second version carrier

Nothing in `lib/` carries the version. `mix.exs` is the only place it is
written, and a release moves it in exactly one place. If a second carrier is
ever added, it gets a step in this file on the same day.

## The corpus is not a release artifact

`mix riddler.corpus` emits the conformance corpus into `riddler_spec`. That
emission is its own change with its own request in that repo; it is not a
release step here, and a release commit does not run it.

## The files a release commit touches

Exactly these, and a release commit that touches anything else is wrong:

| File | Moved by |
|---|---|
| `mix.exs` | the recipe's `version_file` |
| `README.md` | the recipe's `readme_pin` |
| `CHANGELOG.md` | the promotion step |
| `changelog.d/*.md` (deleted) | the promotion step |

## What a release here still is not

The skill does not tag, push, open a request or publish, and this extension
does not either. In this repo those are the operator's, in every campaign and
outside every campaign - `CLAUDE.md`'s authority table says so, and the one
exception it names is a release-prep request: the version bump and the
changelog promotion above, no tag, under a campaign consent clause that names
it.
