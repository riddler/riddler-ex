defmodule Riddler.READMETest do
  @moduledoc """
  The README's worked examples are doctests, not prose.

  The front page is this package's reference - it answers one question per
  public seam - so an example that stops being true has to fail the suite
  rather than sit there being wrong on hexdocs. `doctest_file/1` runs every
  `iex>` block in the file; the installation snippet carries no prompt and is
  not one. README.md is in `gate.also_gated_paths` for this reason.
  """

  use ExUnit.Case, async: true

  # Sabotage: changing an expected value in README.md's resolution example (the
  # rendered greeting "Welcome back, Ada.") turned this file red with one
  # failure naming the README line; reverted.
  doctest_file("README.md")
end
