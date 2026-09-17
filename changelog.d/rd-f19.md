### Fixed

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
