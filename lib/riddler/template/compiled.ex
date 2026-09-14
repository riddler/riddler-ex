defmodule Riddler.Template.Compiled do
  @moduledoc """
  A template that has been accepted by `Riddler.Template.compile/1`.

  Holding one of these is the proof that every construct in the source is
  inside the template subset: nothing outside it survives compilation, so a
  render can never be the first place a refusal is discovered.

  The struct is opaque in practice - a host keeps it and hands it back to
  `Riddler.Template.render/3` - but its fields are readable so that a host
  that caches compiled templates can key them on the source it compiled.
  """

  @typedoc """
  `:source` is the template text as it was compiled. `:parsed` is the parse
  tree the underlying Liquid parser produced. `:defaulted` is the set of
  source positions whose value is guarded by a `default` filter, which is what
  lets a render tell an optional field that was answered by its default from a
  value that is genuinely missing.
  """
  @type t :: %__MODULE__{
          source: String.t(),
          parsed: Solid.Template.t(),
          defaulted: MapSet.t({pos_integer, pos_integer})
        }

  @enforce_keys [:source, :parsed, :defaulted]
  defstruct [:source, :parsed, :defaulted]
end
