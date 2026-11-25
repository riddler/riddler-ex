defmodule Riddler.Screens.LinkTest do
  use ExUnit.Case, async: true

  alias Riddler.Journey
  alias Riddler.Screens
  alias Riddler.Screens.Document

  doctest Riddler.Screens.Type.Divider
  doctest Riddler.Screens.Type.Link

  @png "data:image/png;base64,iVBORw0KGgo="

  defp raw(elements) do
    %{
      "schema_version" => 2,
      "id" => "edoc_signup_screens",
      "screens" => [
        %{"key" => "account", "title" => "Create your account", "elements" => elements}
      ]
    }
  end

  defp document(elements), do: Document.admit(raw(elements))

  defp findings(elements) do
    case Document.validate(document(elements)) do
      {:ok, _document} -> []
      {:error, findings} -> Enum.map(findings, &{&1.code, &1.element_key, &1.field})
    end
  end

  defp terms(overrides \\ %{}) do
    Map.merge(
      %{
        "type" => "link",
        "key" => "billing_terms",
        "label" => "Read the billing terms",
        "href" => "https://acme.example/terms"
      },
      overrides
    )
  end

  defp next_button do
    %{"type" => "button", "key" => "account_next", "label" => "Next", "outcome" => "next"}
  end

  defp root(context), do: %{"context" => context, "responses" => %{}}

  defp resolved(elements, root) do
    {:ok, screen, diagnostics} = Screens.resolve_screen(document(elements), "account", root)
    {screen.elements, diagnostics}
  end

  describe "a divider" do
    # Sabotage: removed "divider" from the registry; the divider was
    # document.unknown_type and this test went red.
    test "is admitted with no field of its own, and a field it does not name is dropped" do
      element = %{"type" => "divider", "key" => "plan_rule", "label" => "ignored"}

      assert findings([element]) == []

      assert [%{type: "divider", key: "plan_rule"} = admitted] =
               hd(document([element]).screens).elements

      refute Map.has_key?(admitted, :label)
    end

    # Sabotage: same mutation as above; the divider was
    # document.unknown_type and this test went red.
    test "resolves to its type and key" do
      element = %{"type" => "divider", "key" => "plan_rule", "condition" => "true"}
      assert {:ok, _document} = Document.validate(document([element]))

      assert {[%{type: "divider", key: "plan_rule"} = divider], _diagnostics} =
               resolved([element], root(%{}))

      assert Map.keys(divider) |> Enum.sort() == [:key, :type]
    end
  end

  describe "a link at admit" do
    # Sabotage: removed "link" from the registry; the link was
    # document.unknown_type and this test went red.
    test "carrying label, href and style is admitted" do
      element = terms(%{"style" => "button"})

      assert findings([element]) == []

      assert [
               %{
                 type: "link",
                 label: "Read the billing terms",
                 href: "https://acme.example/terms",
                 style: "button"
               }
             ] =
               hd(document([element]).screens).elements
    end

    # Sabotage: dropped :href from the link's required fields; the link with
    # no href raised nothing and this test went red.
    test "without label or href is missing a field" do
      assert findings([Map.delete(terms(), "href")]) ==
               [{"document.missing_field", "billing_terms", "href"}]

      assert findings([Map.delete(terms(), "label")]) ==
               [{"document.missing_field", "billing_terms", "label"}]
    end

    # Sabotage: made the link's href share the image's rule (the link row of
    # the URL table admitted data:); every data URL here was admitted and this
    # test went red.
    test "a data URL in a link href is refused, of every media type the image rule admits" do
      for href <- [
            @png,
            "data:image/jpeg;base64,/9j/4AAQ",
            "data:image/gif;base64,R0lGODlh",
            "data:image/webp;base64,UklGRg==",
            "data:text/html;base64,PGI+PC9iPg=="
          ] do
        assert findings([terms(%{"href" => href})]) ==
                 [{"document.invalid_url", "billing_terms", "href"}],
               href
      end
    end

    # Sabotage: made the URL rule admit any scheme (the catch-all form clause
    # answered :ok); the javascript, http and mailto hrefs were admitted and
    # this test went red.
    test "any other scheme, another host and a template are refused" do
      for href <- [
            "javascript:alert(1)",
            "http://acme.example/terms",
            "mailto:billing@acme.example",
            "//acme.example/terms",
            "https://acme.example/terms?plan={{ context.plan }}",
            42
          ] do
        assert findings([terms(%{"href" => href})]) ==
                 [{"document.invalid_url", "billing_terms", "href"}],
               inspect(href)
      end

      assert findings([terms(%{"href" => "/billing/terms"})]) == []
    end

    # Sabotage: made the message carry the data clause for every field; the
    # href refusal offered a data: image and this test went red.
    test "a refusal names href and offers no data URL" do
      {:error, [finding]} =
        Document.validate(document([terms(%{"href" => "ftp://acme.example"})]))

      assert finding.message =~ "href"
      refute finding.message =~ "data:"
    end

    # Sabotage: read an href beginning context. as a literal; the path was
    # document.invalid_url and this test went red.
    test "an href beginning context. is a path, held to the path rule" do
      assert findings([terms(%{"href" => "context.tenant.terms_url"})]) == []

      assert findings([terms(%{"href" => "context.Tenant.terms"})]) ==
               [{"document.invalid_context_path", "billing_terms", "href"}]
    end

    # Sabotage: removed the style check from the link; the numeric style
    # raised nothing and this test went red.
    test "a style that is not a string is refused, and an unoffered name passes" do
      assert findings([terms(%{"style" => 1})]) ==
               [{"document.invalid_style", "billing_terms", "style"}]

      assert findings([terms(%{"style" => "pill"})]) == []
    end

    # Sabotage: added :outcome to the link's optional fields; the admitted
    # link carried the outcome and this test went red.
    test "an outcome, writes and validates on a link are dropped with no finding" do
      element =
        terms(%{
          "outcome" => "terms_read",
          "writes" => %{"responses.plan" => ["const", "business"]},
          "validates" => false
        })

      assert findings([element]) == []
      [admitted] = hd(document([element]).screens).elements
      refute Enum.any?([:outcome, :writes, :validates], &Map.has_key?(admitted, &1))
    end

    # Sabotage: removed "link" from the registry; the version 1 link was
    # document.unknown_type and this test went red.
    test "a link and a divider are admitted in a version 1 document" do
      document = %{
        "schema_version" => 1,
        "id" => "edoc_signup_screens",
        "screens" => [
          %{
            "key" => "account",
            "title" => "Create your account",
            "nodes" => [terms(), %{"type" => "divider", "key" => "plan_rule"}]
          }
        ]
      }

      assert {:ok, admitted} = Document.validate(Document.admit(document))
      assert [%{type: "link"}, %{type: "divider"}] = hd(admitted.screens).elements
    end
  end

  describe "a link at resolve" do
    # Sabotage: removed :label from the template fields; the label was carried
    # as its source and this test went red.
    test "its label is rendered and a literal href carried as written" do
      element = terms(%{"label" => "{{ context.tenant }} billing terms", "style" => "inline"})

      assert {[
                %{
                  type: "link",
                  label: "Acme billing terms",
                  href: "https://acme.example/terms",
                  style: "inline"
                }
              ], %{missing_variables: []}} = resolved([element], root(%{"tenant" => "Acme"}))
    end

    # Sabotage: made the URL rule resolve an image alone (the link left as
    # written); the link carried the path and this test went red.
    test "a path reaching an admitted URL carries the URL" do
      element = terms(%{"href" => "context.tenant.terms_url"})

      for url <- ["https://acme.example/terms", "/billing/terms"] do
        assert match?(
                 {[%{href: ^url}], %{missing_variables: []}},
                 resolved([element], root(%{"tenant" => %{"terms_url" => url}}))
               ),
               url
      end
    end

    # Sabotage: removed the check on a path's value in the URL rule's
    # resolution; every value was carried and this test went red.
    test "a path reaching a data, an http or no URL drops the link and reports the path" do
      element =
        terms(%{"href" => "context.tenant.terms_url", "label" => "{{ context.tenant.name }}"})

      for value <- [@png, "http://acme.example/terms", "javascript:alert(1)", nil, 7] do
        assert match?(
                 {[],
                  %{
                    missing_variables: [
                      %{key: "billing_terms", variable: "context.tenant.terms_url"}
                    ]
                  }},
                 resolved([element], root(%{"tenant" => %{"terms_url" => value}}))
               ),
               inspect(value)
      end
    end

    # Sabotage: made the link's href share the image's rule (the link row of
    # the URL table admitted data:); the literal data URL was carried and this
    # test went red.
    test "a literal the rule refuses, in a document no one validated, is not presented" do
      for href <- [@png, "http://acme.example/terms", "javascript:alert(1)"] do
        assert match?(
                 {[], %{missing_variables: []}},
                 resolved([terms(%{"href" => href})], root(%{}))
               ),
               href
      end
    end
  end

  describe "style on a text" do
    # Sabotage: removed :style from the text's optional fields; the caption
    # was dropped at admit and this test went red.
    test "caption is admitted and carried, and a text with none resolves with none" do
      caption = %{
        "type" => "text",
        "key" => "plan_note",
        "text" => "Billed monthly.",
        "style" => "caption"
      }

      body = %{"type" => "text", "key" => "plan_intro", "text" => "Nothing is charged today."}

      assert findings([caption, body]) == []

      assert {[%{key: "plan_note", style: "caption"}, %{key: "plan_intro"} = intro], _diagnostics} =
               resolved([caption, body], root(%{}))

      refute Map.has_key?(intro, :style)
    end

    # Sabotage: made the text's validate/1 answer []; the numeric style raised
    # nothing and this test went red.
    test "a style that is not a string is refused, and an unoffered name passes" do
      text = %{"type" => "text", "key" => "plan_note", "text" => "Billed monthly."}

      assert findings([Map.put(text, "style", ["caption"])]) ==
               [{"document.invalid_style", "plan_note", "style"}]

      assert findings([Map.put(text, "style", "lede")]) == []
    end
  end

  describe "presentation" do
    # Sabotage: added :outcome to the link's optional fields; the presented
    # link carried the outcome and this test went red.
    test "a link raises no outcome and is absent from moves" do
      elements = [
        terms(%{"outcome" => "terms_read"}),
        %{"type" => "divider", "key" => "plan_rule"},
        next_button()
      ]

      {:ok, answer} = Journey.present(document(elements), {:screen, "account"}, root(%{}))

      assert answer["moves"]["outcomes"] == ["next"]

      assert [
               %{"type" => "link", "key" => "billing_terms"} = link,
               %{"type" => "divider", "key" => "plan_rule"},
               %{"type" => "button"}
             ] = answer["screen"]["elements"]

      refute Map.has_key?(link, "outcome")
    end

    # Sabotage: dropped "href" from the link definition's required list in the
    # presented-answer schema; the link with no href validated and this test
    # went red.
    test "a presented link, divider and styled text validate against the presented-answer schema" do
      schema =
        "priv/schemas/presented-answer.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()

      elements = [
        terms(%{"style" => "inline"}),
        %{"type" => "divider", "key" => "plan_rule"},
        %{
          "type" => "text",
          "key" => "plan_note",
          "text" => "Billed monthly.",
          "style" => "caption"
        },
        next_button()
      ]

      {:ok, answer} = Journey.present(document(elements), {:screen, "account"}, root(%{}))
      [link, divider, text, button] = answer["screen"]["elements"]

      assert ExJsonSchema.Validator.valid?(schema, answer)

      for field <- ["href", "label", "key"] do
        broken =
          put_in(answer, ["screen", "elements"], [Map.delete(link, field), divider, text, button])

        refute ExJsonSchema.Validator.valid?(schema, broken), field
      end

      refute ExJsonSchema.Validator.valid?(
               schema,
               put_in(answer, ["screen", "elements"], [Map.delete(divider, "key")])
             )

      for broken <- [Map.put(link, "style", 1), Map.put(text, "style", 2)] do
        refute ExJsonSchema.Validator.valid?(
                 schema,
                 put_in(answer, ["screen", "elements"], [broken])
               ),
               broken["type"]
      end
    end
  end
end
