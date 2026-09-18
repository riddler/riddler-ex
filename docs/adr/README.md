# Architecture Decision Records

| # | Decision | Status |
|---|---|---|
| [0001](0001-riddler-one-package.md) | Riddler is one package: a dynamic content runtime that consumes the statifier family, and the content document is its contract | accepted |
| [0002](0002-element-document.md) | The screen document v1 | accepted |
| [0003](0003-template-subset.md) | The template subset | accepted |

New ADRs: next number, same three-section format (Context, Decision,
Consequences), plus the typespecs and worked-example sections this family's
records carry. Pick the number against a freshly fetched remote.

This repository inherits the family's ADR practice rather than restating it,
so there is no local "record architecture decisions" record. A bare
`ADR-NNNN` cites this repository's own records; a cross-repo citation carries
the owning repo's beads prefix - `rd-ADR-0001` is how another repo cites this
repository's ADR-0001, `sd-ADR-0001` is statifier_datamodel's ADR-0001, and
`sb-ADR-0006` is statifier_blocks' ADR-0006. Records in sibling repos that are
still being drafted are cited by bead id until their number is assigned.

## How a record grows

A record is accepted once and then grows by addition. Two shapes do that, and
both append at the end of the file as it stands when they are written, after a
`---` rule, with nothing above them reworded. A later Amendment appends below
an earlier Note, so a Note is at the foot of the file when it lands rather than
forever.

**A dated Note is unheaded.** It opens with its date and its provenance - the
campaign and the bead it was recorded for - and each note the entry carries is
led by a bold sentence naming what the note is about, with the bead in
parentheses at the end where one note among several needs distinguishing. No
Note in these records carries a `##` heading of its own, and none carries a
`Status:` line. Two openings are accepted. New Notes use the first, which nine
of the ten dated Note entries written so far use:

```
Noted 2026-09-17, campaign RF051, beads rd-2b2, rd-c6t, rd-aya and rd-cpx, and
one item carried out of the direction review of ADR-0002's amendment of the same
date. Five notes by addition, each read against `main` at `27faac3`. Nothing
above is changed; each paragraph below says what the text above means now.
```

ADR-0003 opens its one Note the other way, and that form is accepted where it
already stands:

```
Note, 2026-09-17, campaign RF051, bead rd-1jj. The question the paragraph above
carries by addition - whether a variable that appears only as an `if` or
`unless` condition is a missing variable under strict mode - is decided here.
```

The entry that files a record and the entry that accepts it are the same shape
under other verbs, `Recorded ...` and `Accepted ...`.

**An Amendment is an H2.** It is a
`## Amendment, YYYY-MM-DD: <the decision it records>` heading with a `Status:`
line beneath it and a `### What the record now decides` section inside it; four
of the five landed so far also carry a `### What is unchanged`. An Amendment
lands at `proposed`, and a separate request flips that Status line in place and
appends a dated Note at the foot saying which Amendment moved and how its cites
were re-verified. Five have landed: one on ADR-0001 and four on ADR-0002.

```
## Amendment, 2026-09-18: a placeless parse refusal is a finding with a nil position

Status: accepted (2026-09-18)
```

## Note or Amendment

Every Status line in these records sits on the record's own header or under a
`## Amendment`, because an amendment changes what the record decides and a note
does not: a note records where something already decided renders, or what a
sentence already accepted was about.

Deciding an open question is not by itself an amendment. The records state the
finer test in their own words, under "Why an amendment and not a note"
(ADR-0002) and "Why a note and not an amendment" (ADR-0001). A decided reading
stays a Note when, as ADR-0002 puts it, "its decided reading takes nothing
away, and so changes nothing this record had decided" - a recorded no, or a
status quo written down where a reader will meet it. It is an Amendment when it
"refuses documents this version admitted", when it changes what the code does,
or when it qualifies a rule the record states.

## Which passage governs

Where two passages of one record disagree, this is how a reader settles it. It
decides nothing; it says which sentence already decided.

- **The Decision section governs** over Consequences, Typespecs, worked
  examples and notes within the same record. ADR-0002 already settles one such
  disagreement on these terms - "The Decision is what governs where the three
  differ" - and both records that carry typespecs say why: they are "a contract
  for the code half rather than a second source of truth" (ADR-0002), and a
  typespec written into ADR-0003 would be "a second source of truth for
  something the compiler already checks".
- **A later dated Amendment governs** over earlier text exactly where it says
  it does, and only once its `Status:` line reads accepted. What it changes is
  under `### What the record now decides`; outside that, the earlier text
  stands.
- **A Note never changes what a record decides.** Where a Note and the decided
  text disagree, the decided text governs and the Note is the defect to fix.

## Process artifacts in these records

The rule that keeps process artifacts out of shipped prose (`CLAUDE.md`)
exempts dated correction and note blocks, and this convention extends that
exemption to these records: a Note's opening and an Amendment's provenance name
the campaign and the bead they were recorded for, because that id is the only
trace of why the paragraph exists. The id belongs in the body, not in an
Amendment's heading, which names the decision the Amendment records - it is
what a reader scans and what another record cites.
