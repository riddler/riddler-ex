defmodule Riddler.FindingTest do
  use ExUnit.Case, async: true

  doctest Riddler.Finding

  alias Riddler.Finding

  describe "position/2" do
    # Mutation: return %{line: line, column: column} unguarded - a parser that
    # reported an error with no place for it then puts a half-span on the
    # finding, which is outside the field's own typespec.
    test "a line and a column that are both there are a span" do
      assert Finding.position(2, 7) == %{line: 2, column: 7}
    end

    # Mutation: as above. Each of these is a value the parser's error metadata
    # can hand back where a loc would have given a number.
    test "anything short of a whole span is nil" do
      assert Finding.position(nil, nil) == nil
      assert Finding.position(1, nil) == nil
      assert Finding.position(nil, 1) == nil
      assert Finding.position(0, 1) == nil
      assert Finding.position(1, 0) == nil
      assert Finding.position("1", "1") == nil
    end
  end
end
