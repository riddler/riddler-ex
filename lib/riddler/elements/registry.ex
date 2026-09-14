defmodule Riddler.Elements.Registry do
  @moduledoc """
  The node types this version of the runtime knows, by the name a document
  spells them with.

  A document's `type` is an open string: the schema does not enumerate the
  types, so a host may carry a document holding a type through a validator
  older than that type without having it rejected on the way. This registry
  is the other half of that rule. It does enumerate them, so a type it does
  not know is refused here, loudly, naming the type and the node - never a
  node quietly passed through as though the runtime had understood it.

  The v1 types are `heading`, `text`, `text_question`, `button` and
  `variant`.

      iex> Riddler.Elements.Registry.types()
      ["button", "heading", "text", "text_question", "variant"]

      iex> Riddler.Elements.Registry.fetch("heading")
      {:ok, Riddler.Elements.Type.Heading}

      iex> Riddler.Elements.Registry.fetch("carousel")
      :error
  """

  alias Riddler.Elements.Type

  @types %{
    "button" => Type.Button,
    "heading" => Type.Heading,
    "text" => Type.Text,
    "text_question" => Type.TextQuestion,
    "variant" => Type.Variant
  }

  @doc """
  The module implementing `type`, or `:error` when this version has no such
  type.
  """
  @spec fetch(term()) :: {:ok, module()} | :error
  def fetch(type) when is_binary(type), do: Map.fetch(@types, type)
  def fetch(_type), do: :error

  @doc """
  Every type name this version knows, sorted.
  """
  @spec types() :: [String.t()]
  def types, do: @types |> Map.keys() |> Enum.sort()
end
