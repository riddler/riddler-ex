### Changed

- A template whose tag carries text after its name that the tag does not read (a string on an `endif`, a word on an `else`, `endunless`, `endfor`, `endcapture` or `endraw`, a note on a `comment` opener or an `endcomment`) is refused with `template.trailing_text_not_allowed` naming that tag, where it compiled before; delete the text, or move a note into the comment's body.
