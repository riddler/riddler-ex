defmodule Riddler.Screens.Type.Link do
  @moduledoc """
  A place a visitor may go from the screen, and the text that names it.

  `label` is required and is a template in the subset `Riddler.Template`
  admits: the text a visitor reads. `href` is required and is a URL or a path
  under `context`, told apart as an image's `src` is - a string that begins
  `context.` is a path, read from the context when the screen is resolved, and
  every other string is a URL - and it is never a template. A URL is an
  `https://` URL naming a host, with no backslash in it, or a host-relative URL
  beginning with a single `/`, and nothing else: a link never takes a `data:`
  URL, written or read. No form carries whitespace, a control character, `{{`
  or `{%`, and nothing is trimmed or rewritten. A literal the rule refuses is
  `document.invalid_url`, its `field` `"href"`; a path that is not a path
  under `context` is `document.invalid_context_path`.

  When the screen is resolved, a path's value is held to the same rule. Where
  the path reaches nothing, a value that is not a string, or a string the rule
  refuses, the link is absent from the resolved screen and the path is
  reported in `missing_variables`; the value is reported nowhere.

  `style` is a hint a renderer owns - `inline` and `button` are the names
  offered - and one this package does not offer is passed through; one that
  is not a string is `document.invalid_style`.

  A link raises no outcome. It carries no `outcome`, no `writes` and no
  `validates`: each is a field it does not name, dropped at admit with no
  finding. A link does not submit the screen and is never among the outcomes
  a presented screen lists; following one is the client's navigation, of
  which this package hears nothing.

      iex> node = %{type: "link", key: "borrowing_rules", label: "Read the borrowing rules", href: "https://library.example/borrowing-rules"}
      iex> Riddler.Screens.Type.Link.validate(node)
      []

      iex> node = %{type: "link", key: "borrowing_rules", label: "Rules", href: "data:image/png;base64,iVBORw0KGgo="}
      iex> [finding] = Riddler.Screens.Type.Link.validate(node)
      iex> {finding.code, finding.field}
      {"document.invalid_url", "href"}
  """

  @behaviour Riddler.Screens.Type

  alias Riddler.Finding
  alias Riddler.Screens.Url

  @impl true
  def fields, do: %{required: [:label, :href], optional: [:style]}

  @impl true
  def validate(node) do
    Url.findings(node, :href, Url.data?("link")) ++ style_findings(node)
  end

  # Which style it is stays the renderer's, as it does for a button's; that it
  # is a string is this package's, because a renderer handed a number has no
  # name to look up.
  defp style_findings(node) do
    case Map.fetch(node, :style) do
      {:ok, style} when is_binary(style) ->
        []

      {:ok, style} ->
        [
          %Finding{
            code: "document.invalid_style",
            message:
              "a style is the name a renderer looks up, a string, not #{inspect(style)}; which names there are is the renderer's",
            field: "style",
            element_key: Finding.element_key(node[:key])
          }
        ]

      :error ->
        []
    end
  end
end
