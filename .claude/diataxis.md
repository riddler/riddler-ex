---
# The docs manifest the documentation tools read. Generated from the family's manifest
# table: change a key there and regenerate. The two prose lines below may be sharpened.
product: riddler
family: riddler
audience: Elixir developers rendering content whose shape and visibility depend on the reader
tone: "plain, second person, no marketing"
terminology:
  use:
    - execution
    - chart
    - document
    - revision
  avoid:
    - "run (noun)"
    - workflow instance
example_world: patron-registration
docs_root: docs
quadrants:
  tutorials: docs/tutorials
  how_to: docs/guides
  reference: docs/reference
  explanation: docs/explanation
readme: README.md
reference_generator: ex_doc
publish: hexdocs
contributor_paths:
  - docs/adr
  - docs/plans
  - docs/spikes
  - docs/research
  - docs/design
  - docs/measurements
  - CLAUDE.md
executed_snippets:
  - test/readme_test.exs
readme_max_lines: 250
---

Dynamic content for a host: elements, safe templates and conditions, resolved against a context.
Examples are written in patron registration: a visitor becomes a library patron through a few screens.
