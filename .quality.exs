# Quality configuration for riddler.
#
#   mix quality                 - full gate: format, compile, credo, dialyzer,
#                                 deps audit, full test suite with coverage.
#                                 Run before every commit.
#
#   mix quality --profile loop  - inner loop while implementing: skips dialyzer
#                                 and coverage, runs only the tests covering
#                                 changed code. Use between edits.
#
# Agents: prefer `--format json --report -` when you want to route on results.
#
# Deliberately small. The custom stages statifier-ex carries - the gate guard,
# the ADR guard and judge, the regression ratchet - all exist to protect a
# conformance corpus and an accepted ADR set that package already had.
# Riddler's corpus arrives later in this package's life; adopting a stage here
# is a decision to record when there is something for it to protect, not a
# default to inherit.
#
# There is deliberately no .credo.exs either: credo's own defaults under
# --strict are the gate until this package has a reason to deviate from one.
#
[
  format: [
    check: true
  ],
  compile: [
    warnings_as_errors: true
  ],
  credo: [
    strict: true
  ],
  profiles: [
    loop: [
      stages: [:format, :compile, :credo, :test],
      test: [scope: :changed, coverage: false]
    ]
  ]
]
