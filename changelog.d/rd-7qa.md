### Changed

- `Riddler.Template.compile/1` refuses a branch or closing keyword written where no block of its own is open as itself, beside every other refusal, and never refuses the closing tag of a block the author opened, so a template that refuses two constructs now gets both findings where it got one, and a host that matched on the old single finding should match on the list.
