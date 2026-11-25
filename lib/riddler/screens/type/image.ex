defmodule Riddler.Screens.Type.Image do
  @moduledoc """
  A picture, and what a visitor who cannot see it is told.

  `src` is required and is a URL or a path under `context`. A string that
  begins `context.` is a path, written as a `prefill` is and read from the
  context when the screen is resolved; every other string is a URL. Either
  way `src` is never a template. A URL is one of three forms, and nothing
  else: an `https://` URL naming a host, with no backslash in it; a
  host-relative URL beginning with a single `/`; or, written in the document
  itself, a base64 `data:` image of type `image/png`, `image/jpeg`,
  `image/gif` or `image/webp`, with no other parameter, at most 65,536 bytes
  in all. No form carries whitespace, a control character, `{{` or `{%`, and
  nothing is trimmed or rewritten. `data:image/svg+xml` is refused, because
  an SVG image can carry script. A literal the rule refuses is
  `document.invalid_url`; a path that is not a path under `context` is
  `document.invalid_context_path`.

  When the screen is resolved, a path's value is held to the same rule with
  no `data:` form. Where the path reaches nothing, a value that is not a
  string, or a string the rule refuses, the image is absent from the resolved
  screen and the path is reported in `missing_variables`; the value is
  reported nowhere.

  `alt` is required and is a template in the subset `Riddler.Template`
  admits. The empty string marks the image as decorative. `size` and `fit` are
  hints a renderer owns - `icon`, `avatar`, `small`, `medium`, `large` and
  `banner`, and `contain` and `cover`, are the names offered - and one this
  package does not offer is passed through; one that is not a string is
  `document.invalid_hint`.

      iex> node = %{type: "image", key: "branch_photo", src: "/images/riverside.png", alt: "The Riverside branch"}
      iex> Riddler.Screens.Type.Image.validate(node)
      []

      iex> node = %{type: "image", key: "branch_photo", src: "javascript:alert(1)", alt: ""}
      iex> [finding] = Riddler.Screens.Type.Image.validate(node)
      iex> {finding.code, finding.field}
      {"document.invalid_url", "src"}
  """

  @behaviour Riddler.Screens.Type

  alias Riddler.Finding
  alias Riddler.Screens.Url

  @hints [:size, :fit]

  @impl true
  def fields, do: %{required: [:src, :alt], optional: @hints}

  @impl true
  def validate(node) do
    Url.findings(node, :src, Url.data?("image")) ++
      Enum.flat_map(@hints, &hint_findings(node, &1))
  end

  # Which hint it is stays the renderer's; that it is a string is this
  # package's, because a renderer handed a number has no name to look up.
  defp hint_findings(node, hint) do
    case Map.fetch(node, hint) do
      {:ok, value} when is_binary(value) ->
        []

      {:ok, value} ->
        [
          %Finding{
            code: "document.invalid_hint",
            message:
              "#{hint} is a hint, the name a renderer looks up, a string, not #{inspect(value)}; which names there are is the renderer's",
            field: Atom.to_string(hint),
            element_key: Finding.element_key(node[:key])
          }
        ]

      :error ->
        []
    end
  end
end
