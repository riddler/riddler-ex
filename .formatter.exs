# Used by "mix format"
#
# No import_deps and no plugins: this package renders nothing, so there is no
# HEEx to format, and neither runtime dependency exports formatter locals whose
# parens need keeping off.
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
