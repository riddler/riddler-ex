defmodule Riddler.Screens.Url do
  @moduledoc false

  # The one URL rule every URL a document carries passes: an image's `src`
  # and a link's `href`, each written as a literal or reached through a path
  # under `context`.
  # Admission checks a literal and the shape of a path; resolution checks the
  # value a path reaches. Both read this module, so the two cannot disagree
  # about what a URL is.
  #
  # Three forms are admitted, and nothing else:
  #
  #   * an `https:` URL: it begins `https://`, as written in lower case, its
  #     host as `URI.parse/1` reads it is a non-empty string, and it carries no
  #     backslash anywhere;
  #   * a host-relative URL: it begins with `/`, and its second character,
  #     where it has one, is neither `/` nor a backslash, each of which names
  #     another host to a browser;
  #   * a `data:` image, where the field takes one: it begins with exactly one
  #     of the four prefixes below, as written in lower case and with no other
  #     parameter, what follows the prefix is non-empty and `Base.decode64/1` decodes it,
  #     and the whole string, its prefix included, is at most 65,536 bytes.
  #
  # Of every form: no whitespace and no ASCII control character anywhere in it,
  # and no `{{` and no `{%`, which mark a template where none is read. Nothing
  # is trimmed, folded or rewritten: a URL is admitted as written or refused.
  # `data:image/svg+xml` is refused whatever its encoding, because an SVG image
  # can carry script.
  #
  # A field's value is a path, not a URL, when it begins `context.`: no URL the
  # rule admits begins so, and no path begins `https:`, `data:` or `/`. A path
  # is written as a `prefill` is and held to the same rule
  # (`Riddler.Screens.Value.context_path/1`). The value it reaches is held to
  # the rule with no `data:` form, whatever the field: a `data:` image is
  # admitted only where an author wrote it.
  #
  # No part of the package's surface.

  alias Riddler.Finding
  alias Riddler.Screens.Value

  @https "https://"
  @path_prefix "context."
  @data_prefixes [
    "data:image/png;base64,",
    "data:image/jpeg;base64,",
    "data:image/gif;base64,",
    "data:image/webp;base64,"
  ]
  @data_bound 65_536

  # The fields each type carries a URL in, and whether a literal there may be a
  # `data:` image. The one table resolution reads.
  @url_fields %{"image" => {:src, true}, "link" => {:href, false}}

  # Any whitespace, Unicode's included, and the ASCII control characters
  # U+0000 to U+001F and U+007F.
  @unwritable ~r/[\s\x{0000}-\x{001F}\x{007F}]/u

  @typedoc "Which part of the rule a value fails."
  @type reason ::
          :not_a_string
          | :whitespace
          | :template
          | :scheme
          | :no_host
          | :backslash
          | :other_host
          | :data_refused
          | :data_media_type
          | :data_encoding
          | :data_bound

  @doc false
  @spec bound() :: pos_integer()
  def bound, do: @data_bound

  # Whether a literal URL in the field `type` carries may be a `data:` image,
  # read from the one table, so admission and resolution cannot disagree.
  @doc false
  @spec data?(String.t()) :: boolean()
  def data?(type) do
    {_field, data?} = Map.fetch!(@url_fields, type)
    data?
  end

  # -- the rule ----------------------------------------------------------------

  @doc false
  @spec check(term(), boolean()) :: :ok | {:error, reason()}
  def check(value, data?) when is_binary(value) do
    cond do
      not String.valid?(value) or Regex.match?(@unwritable, value) -> {:error, :whitespace}
      String.contains?(value, ["{{", "{%"]) -> {:error, :template}
      true -> form(value, data?)
    end
  end

  def check(_not_a_string, _data?), do: {:error, :not_a_string}

  defp form(@https <> _rest = value, _data?) do
    cond do
      String.contains?(value, "\\") -> {:error, :backslash}
      host?(value) -> :ok
      true -> {:error, :no_host}
    end
  end

  defp form("/" <> rest, _data?) do
    case rest do
      "/" <> _other_host -> {:error, :other_host}
      "\\" <> _other_host -> {:error, :other_host}
      _same_host -> :ok
    end
  end

  defp form("data:" <> _rest, false), do: {:error, :data_refused}
  defp form("data:" <> _rest = value, true), do: data(value)
  defp form(_other_scheme, _data?), do: {:error, :scheme}

  defp host?(value) do
    case URI.parse(value) do
      %URI{host: host} when is_binary(host) and host != "" -> true
      _no_host -> false
    end
  end

  defp data(value) do
    case Enum.find(@data_prefixes, &String.starts_with?(value, &1)) do
      nil ->
        {:error, :data_media_type}

      prefix ->
        encoded = binary_part(value, byte_size(prefix), byte_size(value) - byte_size(prefix))

        cond do
          byte_size(value) > @data_bound -> {:error, :data_bound}
          encoded == "" or Base.decode64(encoded) == :error -> {:error, :data_encoding}
          true -> :ok
        end
    end
  end

  # What a refusal says: which part of the rule the value fails, naming the
  # field. It never quotes the value, so a `data:` URL's image data is never
  # repeated.
  @doc false
  @spec message(reason(), String.t()) :: String.t()
  def message(:not_a_string, field), do: "#{field} is a URL, a string"

  def message(:whitespace, field),
    do: "#{field} is a URL, and a URL carries no whitespace and no control character"

  def message(:template, field),
    do: "#{field} is a URL and never a template, and it carries {{ or {%"

  def message(:scheme, field),
    do:
      "#{field} is an https:// URL or a host-relative one beginning with a single /#{data_clause(field)}, and this one is neither"

  def message(:no_host, field), do: "#{field} is an https:// URL that names no host"

  def message(:backslash, field),
    do: "#{field} is an https:// URL, and a backslash in one names another place to a browser"

  def message(:other_host, field),
    do:
      "#{field} is a host-relative URL, and one beginning with // or with a / and a backslash names another host"

  def message(:data_refused, field), do: "#{field} takes no data: URL here"

  def message(:data_media_type, field),
    do:
      "#{field} is a data: URL, and the ones admitted are base64 images of type image/png, image/jpeg, image/gif and image/webp, with no other parameter"

  def message(:data_encoding, field),
    do: "#{field} is a data: URL whose image data is not base64 that decodes"

  def message(:data_bound, field),
    do: "#{field} is a data: URL longer than #{@data_bound} bytes"

  defp data_clause("src"), do: ", or a data: image"
  defp data_clause(_field), do: ""

  # -- admission ---------------------------------------------------------------

  @doc false
  @spec path?(term()) :: boolean()
  def path?(value), do: is_binary(value) and String.starts_with?(value, @path_prefix)

  # The findings about the URL `field` carries on an admitted element, where it
  # carries one: a path that is not a path under `context`, or a literal the
  # rule refuses. An absent field is the document's `document.missing_field`.
  @doc false
  @spec findings(map(), atom(), boolean()) :: [Finding.t()]
  def findings(node, field, data?) do
    name = Atom.to_string(field)

    case Map.fetch(node, field) do
      :error -> []
      {:ok, value} -> value_findings(value, name, data?, Finding.element_key(node[:key]))
    end
  end

  defp value_findings(value, name, data?, key) do
    if path?(value) do
      path_findings(value, name, key)
    else
      case check(value, data?) do
        :ok ->
          []

        {:error, reason} ->
          [
            %Finding{
              code: "document.invalid_url",
              message: message(reason, name),
              field: name,
              element_key: key
            }
          ]
      end
    end
  end

  defp path_findings(path, name, key) do
    case Value.context_path(path) do
      {:ok, _segments} ->
        []

      :error ->
        [
          %Finding{
            code: "document.invalid_context_path",
            message:
              "#{name} #{inspect(path)} begins context. and is not a path under context: dotted segments starting at context, at least one more after it, each a lower-case letter followed by lower-case letters, digits and underscores",
            field: name,
            element_key: key
          }
        ]
    end
  end

  # -- resolution --------------------------------------------------------------

  # The element with its URL in place, or `{:drop, variables}`: the element is
  # absent from the resolved screen and the variables are its report. A path is
  # read from the context; where it reaches a string the rule admits, with no
  # `data:` form, the element carries that string, and where it reaches
  # nothing, a value that is not a string, or a string the rule refuses, the
  # element is dropped and the path as written is its report. The value is
  # reported nowhere. A literal the rule refuses is in a document no one
  # validated: the element is dropped with no report, since the document
  # refuses it at admit and no path names it. An element of a type that
  # carries no URL, or that carries none in its field, is left as it is.
  @doc false
  @spec resolve(map(), term()) :: {:ok, map()} | {:drop, [String.t()]}
  def resolve(%{type: type} = node, context) when is_map_key(@url_fields, type) do
    {field, data?} = Map.fetch!(@url_fields, type)

    case Map.fetch(node, field) do
      :error -> {:ok, node}
      {:ok, value} -> resolve_value(node, field, value, data?, context)
    end
  end

  def resolve(node, _context), do: {:ok, node}

  defp resolve_value(node, field, value, data?, context) do
    if path?(value) do
      with {:ok, segments} <- Value.context_path(value),
           {:ok, found} <- Value.walk(context, segments),
           :ok <- check(found, false) do
        {:ok, Map.put(node, field, found)}
      else
        _refused -> {:drop, [value]}
      end
    else
      case check(value, data?) do
        :ok -> {:ok, node}
        {:error, _reason} -> {:drop, []}
      end
    end
  end
end
