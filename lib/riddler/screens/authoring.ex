defmodule Riddler.Screens.Authoring do
  @moduledoc false

  # The authoring schema and the element instructions, both built from the
  # type registry: what `mix riddler.authoring` writes into `priv/authoring/`,
  # and what the suite compares the committed files against.
  #
  # The screen document schema in `priv/schemas/` is the transport contract:
  # `type` is an open string there, so a document carrying a type a validator
  # is older than still travels. The authoring schema is the other use - a
  # schema an authoring tool validates against while a document is being
  # written. It enumerates the types the registry knows and, for each, the
  # fields the type's `fields/0` names, the fields every element shares and
  # nothing else, so a field this version does not read is refused rather than
  # dropped. A document that `Riddler.Screens.Document.validate/1` accepts,
  # and that carries no field admission drops, validates against it. The
  # value rules a schema cannot state - a condition that parses, a template in
  # the subset, a key used once - stay findings `validate/1` raises.
  #
  # The key and check-code patterns are the runtime's own regex sources, each
  # ending in `$`. A validator with PCRE semantics, as this suite uses, reads
  # them as `validate/1` does; an ECMA-262 validator also refuses a key or a
  # code ending in a line break, which `validate/1` admits. An authored
  # option's `value` takes the key pattern too, and there the difference runs
  # the other way: `validate/1` reads a value anchored with `\A` and `\z` and
  # refuses one ending in a line break, which a PCRE validator admits against
  # this schema.
  #
  # The instructions are a short plain text per type: the sentence below, kept
  # here beside the registry rather than in the written file, and the type's
  # fields as the registry names them. Nothing here calls anything outside this
  # package; both files are text an author or a tool reads.
  #
  # No part of the package's surface.

  alias Riddler.Corpus
  alias Riddler.Screens.Checks
  alias Riddler.Screens.Document
  alias Riddler.Screens.Registry
  alias Riddler.Screens.Type.SecretQuestion

  @schema_path "priv/authoring/screen-authoring.schema.json"
  @instructions_path "priv/authoring/screen-elements.md"

  # One sentence per type, in plain words. A type the registry gains without
  # a sentence here stops the task and turns the suite red, so the written
  # instructions never leave a type out.
  @sentences %{
    "boolean_question" =>
      "A question a visitor answers yes or no, shown as a lone checkbox or toggle.",
    "button" => "A control a visitor presses; its outcome names what the press raises.",
    "choice_question" =>
      "A question a visitor answers by picking one or many of its options, written as answer_options or read from context with answer_options_from, one of the two.",
    "divider" => "A rule between the elements before it and the elements after it.",
    "heading" => "A section title: a level from 1 to 6 and the text of the heading.",
    "image" => "A picture, and the alt text a visitor who cannot see it is told.",
    "link" => "A place a visitor may go from the screen, and the label that names it.",
    "secret_question" =>
      "A question whose response is a secret the visitor types, such as a PIN; it never carries a default or a prefill.",
    "text" => "A block of authored prose.",
    "text_question" =>
      "A question a visitor answers with a line of text, optionally held to a format.",
    "variant" =>
      "A container that shows the first of its candidates whose condition holds, and nothing else."
  }

  # The fields every element may carry whatever its type: `type` and `key`,
  # which every element carries, and the condition and the accessible label
  # and description. `checks` is a question's alone.
  @shared_required [:type, :key]
  @shared_optional [:condition, :accessible_label, :accessible_description]

  # A field a type names only to refuse it: a secret question's initial
  # values are admitted so that `validate/1` can name them, and a document it
  # accepts never carries one.
  @refused_fields %{"secret_question" => SecretQuestion.initial_values()}

  # A required field a type also accepts in another form: a choice question
  # carries `answer_options` or `answer_options_from`, exactly one, as
  # `validate/1` holds it.
  @alternatives %{"choice_question" => %{answer_options: :answer_options_from}}

  # The key a version spells a container's candidates under, and a screen's
  # elements. The registry names the field `elements`; a version 1 document
  # spells it `nodes`.
  @spellings %{1 => "nodes", 2 => "elements"}

  @doc false
  @spec paths() :: [String.t()]
  def paths, do: [@schema_path, @instructions_path]

  @doc false
  @spec files() :: [{String.t(), String.t()}]
  def files,
    do: [{@schema_path, Corpus.canonical(schema())}, {@instructions_path, instructions()}]

  @doc false
  @spec sentences() :: %{String.t() => String.t()}
  def sentences, do: @sentences

  @doc """
  The files under `root` that differ from what `files/0` writes, as
  `{relative path, :missing | :differs}`. An empty list is no drift.
  """
  @spec drift(String.t()) :: [{String.t(), :missing | :differs}]
  def drift(root) do
    for {relative, contents} <- files(),
        reason = compare(Path.join(root, relative), contents),
        do: {relative, reason}
  end

  defp compare(path, contents) do
    case File.read(path) do
      {:ok, ^contents} -> nil
      {:ok, _other} -> :differs
      {:error, _reason} -> :missing
    end
  end

  @doc false
  @spec write(String.t()) :: [String.t()]
  def write(root) do
    for {relative, contents} <- files() do
      path = Path.join(root, relative)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, contents)
      relative
    end
  end

  # -- the fields a type takes -------------------------------------------------

  @doc false
  @spec fields(String.t()) :: %{required: [atom()], optional: [atom()]}
  def fields(type) do
    {:ok, module} = Registry.fetch(type)
    %{required: required, optional: optional} = module.fields()
    refused = Map.get(@refused_fields, type, [])
    checks = if type in Checks.question_types(), do: [:checks], else: []

    %{
      required: Enum.uniq(@shared_required ++ required),
      optional: Enum.uniq(@shared_optional ++ checks ++ (optional -- refused)) -- required
    }
  end

  defp sentence!(type) do
    case Map.fetch(@sentences, type) do
      {:ok, sentence} ->
        sentence

      :error ->
        raise ArgumentError,
              "the element type #{inspect(type)} has no instruction sentence; add one to #{inspect(__MODULE__)}"
    end
  end

  # -- the schema --------------------------------------------------------------

  @doc false
  @spec schema() :: map()
  def schema do
    types = Registry.types()
    Enum.each(types, &sentence!/1)

    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => "Screen document for authoring",
      "description" =>
        "Generated by mix riddler.authoring from the element type registry; never edited by hand. " <>
          "The schema an authoring tool validates a screen document against while it is written: the element types are enumerated, " <>
          "each type takes exactly the fields the registry names for it and the fields every element shares, and a field this version does not read is refused. " <>
          "The transport schema, screen-document.schema.json, stays the contract for carrying a document, with type an open string. " <>
          "A document the runtime accepts with no finding, and carrying no field it drops, validates here; what a schema cannot state - a condition that parses, a template in the subset, a key used once in the document - stays a finding the runtime raises. " <>
          "A version 2 document spells a screen's and a variant's children elements, and a version 1 document, or one declaring no version, spells them nodes.",
      "type" => "object",
      "required" => ["screens"],
      "additionalProperties" => false,
      "properties" => %{
        "id" => %{"type" => "string", "description" => "The name of the document."},
        "kind" => %{
          "enum" => ["screens"],
          "description" => "The content kind; absent means screens."
        },
        "metadata" => %{
          "type" => "object",
          "description" => "An open map a host keeps beside the vocabulary."
        },
        "schema_version" => %{
          "enum" => Map.keys(@spellings),
          "description" => "1 or 2, and absent means 1."
        },
        "screens" => %{"type" => "array"}
      },
      "allOf" => [
        %{
          "if" => %{
            "required" => ["schema_version"],
            "properties" => %{"schema_version" => %{"const" => 2}}
          },
          "then" => %{"properties" => %{"screens" => %{"items" => ref("screen_version_2")}}},
          "else" => %{"properties" => %{"screens" => %{"items" => ref("screen_version_1")}}}
        }
      ],
      "definitions" =>
        Enum.reduce(@spellings, %{"check" => check()}, fn {version, _children}, acc ->
          acc
          |> Map.put("screen_version_#{version}", screen(version))
          |> Map.put("element_version_#{version}", element(version, types))
        end)
    }
  end

  defp ref(name), do: %{"$ref" => "#/definitions/#{name}"}

  defp key, do: %{"type" => "string", "pattern" => Document.key_pattern()}

  defp screen(version) do
    children = Map.fetch!(@spellings, version)

    %{
      "description" =>
        "A screen of a version #{version} document: its key, its title, and its elements under #{children}.",
      "type" => "object",
      "required" => ["key", children],
      "additionalProperties" => false,
      "properties" => %{
        "key" => key(),
        "title" => %{"type" => "string"},
        children => %{"type" => "array", "items" => ref("element_version_#{version}")}
      }
    }
  end

  defp element(version, types) do
    %{
      "description" =>
        "An element of a version #{version} document: one of the enumerated types, with the fields that type takes.",
      "type" => "object",
      "required" => ["type"],
      "properties" => %{"type" => %{"enum" => types}},
      "allOf" =>
        Enum.map(types, fn type ->
          %{
            "if" => %{"required" => ["type"], "properties" => %{"type" => %{"const" => type}}},
            "then" => typed(type, version)
          }
        end)
    }
  end

  defp typed(type, version) do
    %{required: required, optional: optional} = fields(type)
    alternatives = Map.get(@alternatives, type, %{})
    spell = fn field -> spelling(field, version) end
    always = required -- Map.keys(alternatives)

    base = %{
      "description" => sentence!(type),
      "required" => Enum.map(always, spell),
      "additionalProperties" => false,
      "properties" =>
        Map.new(required ++ optional, fn field ->
          {spell.(field), property(field, type, version)}
        end)
    }

    case Enum.to_list(alternatives) do
      [] ->
        base

      pairs ->
        Map.put(
          base,
          "allOf",
          for {field, other} <- pairs do
            %{
              "oneOf" => [
                %{"required" => [spell.(field)]},
                %{"required" => [spell.(other)]}
              ]
            }
          end
        )
    end
  end

  defp spelling(:elements, version), do: Map.fetch!(@spellings, version)
  defp spelling(field, _version), do: Atom.to_string(field)

  defp property(:type, type, _version), do: %{"const" => type}
  defp property(:key, _type, _version), do: key()
  defp property(:condition, _type, _version), do: %{"type" => "string"}
  defp property(:checks, _type, _version), do: %{"type" => "array", "items" => ref("check")}

  defp property(:elements, _type, version),
    do: %{"type" => "array", "items" => ref("element_version_#{version}")}

  defp property(:answer_options, _type, _version) do
    %{
      "type" => "array",
      "items" => %{
        "type" => "object",
        "required" => ["value", "label"],
        "additionalProperties" => false,
        "properties" => %{
          "value" => key(),
          "label" => %{"type" => "string"},
          "description" => %{}
        }
      }
    }
  end

  defp property(_field, _type, _version), do: %{}

  defp check do
    %{
      "description" =>
        "A question's check: a condition its response has to satisfy, the author's code and the message shown when it does not.",
      "type" => "object",
      "required" => Enum.map(Checks.fields(), &Atom.to_string/1),
      "additionalProperties" => false,
      "properties" => %{
        "condition" => %{"type" => "string"},
        "code" => %{"type" => "string", "pattern" => Checks.code_pattern()},
        "message" => %{"type" => "string", "minLength" => 1}
      }
    }
  end

  # -- the instructions --------------------------------------------------------

  @doc false
  @spec instructions() :: String.t()
  def instructions do
    types = Registry.types()

    sections =
      Enum.map(types, fn type ->
        %{required: required, optional: optional} = fields(type)

        """
        ## #{type}

        #{sentence!(type)}

        Required: #{list(required -- @shared_required, type)}.
        Optional: #{list(optional -- [:checks | @shared_optional], type)}.
        """
      end)

    """
    # Screen elements

    Generated by `mix riddler.authoring` from the element type registry; never
    edited by hand. One short text per element type a screen document may
    carry, for an author or an authoring tool. The authoring schema beside
    this file, `screen-authoring.schema.json`, states the same fields as a
    JSON Schema.

    Every element carries `type`, one of the types below, and `key`, a lower
    case letter followed by lower case letters, digits and underscores, used
    once in the whole document. Every element may carry `condition`,
    `accessible_label` and `accessible_description`, and a question may carry
    `checks`. The fields below are each type's own. A version 2 document
    spells a variant's candidates `elements`; a version 1 document spells
    them `nodes`.

    """ <> Enum.join(sections, "\n")
  end

  defp list(fields, type) do
    alternatives = Map.get(@alternatives, type, %{})
    others = Map.values(alternatives)

    fields
    |> Enum.reject(&(&1 in others))
    |> Enum.map(fn field ->
      case Map.fetch(alternatives, field) do
        {:ok, other} -> "`#{field}` or `#{other}`"
        :error -> "`#{field}`"
      end
    end)
    |> case do
      [] -> "none"
      names -> Enum.join(names, ", ")
    end
  end
end
