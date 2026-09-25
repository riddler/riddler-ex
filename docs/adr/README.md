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

**A dated Note is unheaded.** It opens with its date, and each note the entry
carries is led by a bold sentence naming what the note is about, with the bead
in parentheses at the end where one note among several needs distinguishing. No
Note in these records carries a `##` heading of its own, and none carries a
`Status:` line.

A Note recording work names its provenance in that opening too - the date and
the bead it was recorded for. New Notes use this form, which seven of the
ten dated Note entries written so far use:

```
Noted 2026-09-17, beads rd-2b2, rd-c6t, rd-aya and rd-cpx, and
one item carried out of the direction review of ADR-0002's amendment of the same
date. Five notes by addition, each read against `main` at `27faac3`. Nothing
above is changed; each paragraph below says what the text above means now.
```

**A flip Note opens with the date alone.** The two that record an Amendment's
Status moving to accepted (ADR-0001 and ADR-0002) name no campaign and no bead
anywhere in their blocks, and they need none: what they record is a Status line
moving in the record above them, and the Amendment they name is their
provenance.

```
Noted 2026-09-18. The three amendments above move from `proposed` to
`accepted`, each Status line flipped in place and nothing else in them
reworded.
```

ADR-0003 opens its one Note with the third accepted form, and that form is
accepted where it already stands:

```
Note, 2026-09-17, bead rd-1jj. The question the paragraph above
carries by addition - whether a variable that appears only as an `if` or
`unless` condition is a missing variable under strict mode - is decided here.
```

So of the ten dated Note entries: seven open `Noted <date>, bead
...`, two are flip Notes opening `Noted <date>.`, and one opens `Note, <date>,
...`. The entry that files a record and the entry that accepts it are the same
shape under other verbs, `Recorded ...` and `Accepted ...`.

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

The records state the operative test in their own words, under "Why an
amendment and not a note" (ADR-0002, three times) and "Why a note and not an
amendment" (ADR-0001). It is whether the entry changes an **answer the record
gave**. An entry is an Amendment where "the rule stated above answers a call
one way, and this entry answers the same call another"; it is a Note where, as
ADR-0001 puts it of itself, it "changes no answer the record gave".

Two things that look like the test are not it, and the records say so in the
entries that could have been sorted the other way:

- **Deciding an open question is not the test.** "Deciding an open question and
  changing what the record decides come apart, and it is the second that
  governs" (ADR-0002). A decided reading stays a Note when "its decided reading
  takes nothing away, and so changes nothing this record had decided".
- **Changing what the code does is not the test.** ADR-0001's Note on the
  emitter's provenance header is "recorded with the code half that makes it
  true, in one request", and stays a Note: "That a ruling was taken is not the
  test; if it were, every commit made under one would amend a record."
  ADR-0003's one Note settles a meaning the code half has still to be brought
  to, and calls that "the code half's work, not a change to what is decided
  here".

Two further marks are each sufficient for an Amendment without being necessary.
One is a new refusal - ADR-0002's uncompilable-pattern amendment "refuses
documents this version admitted", and ADR-0002 says of that test that it "is a
sufficient reason for an amendment rather than a necessary one". The other is
qualifying a rule an Amendment above states, "which the record names elsewhere
as the mark of an amendment rather than a note".

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
exemption to these records: a Note recording work opens by naming the date and
the bead it was recorded for, and an Amendment's provenance does the same,
because that id is the only trace of why the paragraph exists. The exemption
covers a bead id, never a campaign id or any other id from the maintainers'
private planning: where a ruling is the provenance, the line reads "ruled by
the operator, YYYY-MM-DD" or restates the reason, and a new Note opens
`Noted YYYY-MM-DD`. A flip Note
carries no id, having no work of its own to account for. The id belongs in the body, not in an
Amendment's heading, which names the decision the Amendment records - it is
what a reader scans and what another record cites.
