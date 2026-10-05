defmodule Riddler.READMETest do
  @moduledoc """
  The README's basic-usage example is a doctest, not prose.

  The front page is the first code a reader copies, so an example that stops
  being true has to fail the suite rather than sit there being wrong on
  hexdocs and hex.pm. `doctest_file/1` runs every `iex>` block in the file;
  the installation snippet carries no prompt and is not one. README.md is in
  `gate.also_gated_paths` for this reason.
  """

  use ExUnit.Case, async: true

  # Sabotage: changing an expected value in README.md's basic-usage example
  # (the rendered greeting "Welcome back, Ada.") turned this file red with
  # one failure naming the README line; reverted.
  doctest_file("README.md")
end
