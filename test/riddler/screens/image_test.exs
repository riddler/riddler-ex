defmodule Riddler.Screens.ImageTest do
  use ExUnit.Case, async: true

  alias Riddler.Journey
  alias Riddler.Screens
  alias Riddler.Screens.Document
  alias Riddler.Screens.Url

  doctest Riddler.Screens.Type.Image

  @png "data:image/png;base64,iVBORw0KGgo="

  defp document(elements) do
    Document.admit(%{
      "schema_version" => 2,
      "id" => "edoc_signup_screens",
      "screens" => [
        %{"key" => "account", "title" => "Create your account", "elements" => elements}
      ]
    })
  end

  defp findings(elements) do
    case Document.validate(document(elements)) do
      {:ok, _document} -> []
      {:error, findings} -> Enum.map(findings, &{&1.code, &1.element_key, &1.field})
    end
  end

  defp logo(overrides \\ %{}) do
    Map.merge(
      %{"type" => "image", "key" => "tenant_logo", "src" => "/images/acme.png", "alt" => ""},
      overrides
    )
  end

  defp root(context), do: %{"context" => context, "responses" => %{}}

  defp resolved(elements, root) do
    {:ok, screen, diagnostics} = Screens.resolve_screen(document(elements), "account", root)
    {screen.elements, diagnostics}
  end

  # A data: image of exactly `bytes` bytes, its prefix included, whose
  # image data decodes.
  defp png_of(bytes) do
    prefix = "data:image/png;base64,"
    prefix <> String.duplicate("A", bytes - byte_size(prefix))
  end

  @refused [
    {"javascript", "javascript:alert(1)"},
    {"http", "http://cdn.example/acme.png"},
    {"svg data", "data:image/svg+xml;base64,PHN2Zz48L3N2Zz4="},
    {"over-bound data", "data:image/png;base64," <> String.duplicate("A", 65_516)}
  ]

  describe "admission" do
    # Sabotage: removed "image" from the registry; the image was
    # document.unknown_type and this test went red.
    test "an image carrying src and alt is admitted with its hints" do
      element = logo(%{"size" => "banner", "fit" => "contain"})

      assert findings([element]) == []

      assert [%{type: "image", src: "/images/acme.png", alt: "", size: "banner", fit: "contain"}] =
               hd(document([element]).screens).elements
    end

    # Sabotage: dropped :alt from the image's required fields; the image with
    # no alt raised nothing and this test went red.
    test "an image without src or alt is missing a field" do
      assert findings([Map.delete(logo(), "src")]) ==
               [{"document.missing_field", "tenant_logo", "src"}]

      assert findings([Map.delete(logo(), "alt")]) ==
               [{"document.missing_field", "tenant_logo", "alt"}]
    end

    # Sabotage: made the URL rule admit any scheme (the catch-all form clause
    # answered :ok); the javascript and http URLs were admitted and this test
    # went red. Again with any data: media type admitted (the SVG went
    # through), and with the bound check removed (the over-bound image went
    # through).
    test "a javascript, an http, an SVG data and an over-bound data URL are each refused at admit" do
      for {what, src} <- @refused do
        assert findings([logo(%{"src" => src})]) ==
                 [{"document.invalid_url", "tenant_logo", "src"}],
               what
      end
    end

    # Sabotage: made a data: URL of any of the four types answer :data_encoding;
    # the admitted images were refused and this test went red.
    test "an https, a host-relative and each of the four data images is admitted" do
      for src <- [
            "https://cdn.example/acme.png",
            "/images/acme.png",
            "/",
            @png,
            "data:image/jpeg;base64,/9j/4AAQ",
            "data:image/gif;base64,R0lGODlh",
            "data:image/webp;base64,UklGRg==",
            png_of(65_534)
          ] do
        assert findings([logo(%{"src" => src})]) == [], String.slice(src, 0, 40)
      end
    end

    # Sabotage: removed the second-character check of a host-relative URL;
    # //cdn.example was admitted and this test went red. Again with the
    # backslash check on an https URL removed.
    test "each other part of the rule refuses" do
      for src <- [
            "//cdn.example/acme.png",
            "/\\cdn.example/acme.png",
            "https://cdn.example\\@acme.example/acme.png",
            "HTTPS://cdn.example/acme.png",
            "https://",
            "https:///acme.png",
            "https://cdn.example/acme logo.png",
            "https://cdn.example/acme.png\n",
            "https://cdn.example/{{ context.tenant }}.png",
            "/images/{% if x %}.png",
            "mailto:billing@acme.example",
            "",
            "data:image/png;charset=utf-8;base64,iVBORw0KGgo=",
            "data:image/png,iVBORw0KGgo=",
            "data:image/PNG;base64,iVBORw0KGgo=",
            "data:image/png;base64,",
            "data:image/png;base64,iVBO*w0K",
            png_of(65_537)
          ] do
        assert findings([logo(%{"src" => src})]) ==
                 [{"document.invalid_url", "tenant_logo", "src"}],
               inspect(String.slice(src, 0, 40))
      end

      assert findings([logo(%{"src" => 42})]) ==
               [{"document.invalid_url", "tenant_logo", "src"}]
    end

    # Sabotage: made the message quote the value; this test went red.
    test "a refusal never quotes a data URL's image data" do
      {:error, [finding]} =
        Document.validate(
          document([logo(%{"src" => "data:image/svg+xml;base64,PHN2Zz48L3N2Zz4="})])
        )

      refute finding.message =~ "PHN2Zz"
    end

    # Sabotage: read a src beginning context. as a literal; the path was
    # document.invalid_url and this test went red.
    test "a src beginning context. is a path, held to the path rule" do
      assert findings([logo(%{"src" => "context.tenant.logo_url"})]) == []

      assert findings([logo(%{"src" => "context.Tenant.logo"})]) ==
               [{"document.invalid_context_path", "tenant_logo", "src"}]

      assert findings([logo(%{"src" => "context."})]) ==
               [{"document.invalid_context_path", "tenant_logo", "src"}]
    end

    # Sabotage: removed :alt from the template fields; the alt holding a tag
    # outside the subset raised nothing and this test went red.
    test "alt is a template in the subset" do
      assert findings([logo(%{"alt" => "{% include 'footer' %}"})]) ==
               [{"document.invalid_template", "tenant_logo", "include"}]

      assert [{"document.invalid_template", "tenant_logo", "alt"}] =
               findings([logo(%{"alt" => 7})])
    end

    # Sabotage: made a size that is not a string pass; this test went red.
    test "a size or fit that is not a string is an invalid hint, and an unoffered name passes" do
      assert findings([logo(%{"size" => 3, "fit" => ["cover"]})]) == [
               {"document.invalid_hint", "tenant_logo", "size"},
               {"document.invalid_hint", "tenant_logo", "fit"}
             ]

      assert findings([logo(%{"size" => "poster", "fit" => "fill"})]) == []
    end

    # Sabotage: dropped :alt from the template fields; the secret reference
    # in the alt raised nothing and this test went red.
    test "an alt naming a secret question's response is refused" do
      secret = %{"type" => "secret_question", "key" => "card_pin", "label" => "PIN"}

      assert findings([secret, logo(%{"alt" => "{{ responses.card_pin }}"})]) ==
               [{"document.secret_reference", "tenant_logo", "alt"}]
    end
  end

  describe "resolution" do
    # Sabotage: removed :alt from the template fields; the alt was carried as
    # its source and this test went red.
    test "a literal src is carried as written and alt is rendered" do
      element = logo(%{"src" => @png, "alt" => "The {{ context.tenant }} logo", "size" => "icon"})

      assert {[
                %{
                  type: "image",
                  key: "tenant_logo",
                  src: @png,
                  alt: "The Acme logo",
                  size: "icon"
                }
              ], %{missing_variables: []}} = resolved([element], root(%{"tenant" => "Acme"}))
    end

    # Sabotage: left the path in place of its value; the image carried the
    # path and this test went red.
    test "a path reaching an admitted URL carries the URL" do
      element = logo(%{"src" => "context.tenant.logo_url"})

      for url <- ["https://cdn.example/acme.png", "/images/acme.png"] do
        assert {[%{src: ^url}], %{missing_variables: []}} =
                 resolved([element], root(%{"tenant" => %{"logo_url" => url}}))
      end
    end

    # Sabotage: made the URL rule admit any scheme (the catch-all form clause
    # answered :ok); the javascript and http values were carried and this
    # test went red. Again with the path's value checked with data: admitted
    # (the data images were carried), and with the check on the path's value
    # removed.
    test "a path reaching a javascript, an http or any data URL drops the image and reports the path" do
      element = logo(%{"src" => "context.tenant.logo_url", "alt" => "{{ context.tenant.name }}"})

      for value <- Enum.map(@refused, &elem(&1, 1)) ++ [@png, nil, 42, %{"url" => "/x"}] do
        root = root(%{"tenant" => %{"logo_url" => value}})

        assert match?(
                 {[],
                  %{
                    missing_variables: [
                      %{key: "tenant_logo", variable: "context.tenant.logo_url"}
                    ]
                  }},
                 resolved([element], root)
               ),
               inspect(value)
      end

      assert {[],
              %{missing_variables: [%{key: "tenant_logo", variable: "context.tenant.logo_url"}]}} =
               resolved([element], root(%{}))
    end

    # Sabotage: dropped a literal the rule refuses only when it was a path;
    # the javascript literal was carried and this test went red.
    test "a literal the rule refuses, in a document no one validated, is not presented" do
      for {what, src} <- @refused do
        assert match?(
                 {[], %{missing_variables: []}},
                 resolved([logo(%{"src" => src})], root(%{}))
               ),
               what
      end
    end

    # Sabotage: chose the next candidate when the winner was dropped; the
    # fallback text was shown and this test went red.
    test "a dropped winner leaves its variant resolving to nothing" do
      variant = %{
        "type" => "variant",
        "key" => "logo_choice",
        "elements" => [
          logo(%{"src" => "context.tenant.logo_url"}),
          %{"type" => "text", "key" => "logo_fallback", "text" => "Acme"}
        ]
      }

      assert {[], %{missing_variables: [%{key: "tenant_logo"}]}} =
               resolved(
                 [variant],
                 root(%{"tenant" => %{"logo_url" => "http://cdn.example/a.png"}})
               )
    end

    # Sabotage: read the path of a hidden image; it was reported and this
    # test went red.
    test "a hidden image's path is never read" do
      element = logo(%{"src" => "context.tenant.logo_url", "condition" => "false"})
      assert {[], %{missing_variables: []}} = resolved([element], root(%{}))
    end
  end

  describe "the shared rule" do
    # Sabotage: answered :ok for a data: URL whatever data? said; the link
    # form admitted it and this test went red.
    test "a field that takes no data URL refuses one" do
      assert Url.check(@png, true) == :ok
      assert Url.check(@png, false) == {:error, :data_refused}
      assert Url.check("https://cdn.example/a.png", false) == :ok
      assert Url.bound() == 65_536
    end

    test "every refusal has a message naming the field" do
      for reason <- [
            :not_a_string,
            :whitespace,
            :template,
            :scheme,
            :no_host,
            :backslash,
            :other_host,
            :data_refused,
            :data_media_type,
            :data_encoding,
            :data_bound
          ] do
        assert Url.message(reason, "href") =~ "href"
      end
    end
  end

  describe "presentation" do
    # Sabotage: dropped "src" from the image definition's required list in
    # the presented-answer schema; the image with no src validated and this
    # test went red.
    test "a presented image validates against the presented-answer schema" do
      schema =
        "priv/schemas/presented-answer.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()

      document = %{
        "schema_version" => 2,
        "screens" => [
          %{
            "key" => "account",
            "title" => "Create your account",
            "elements" => [
              logo(%{"size" => "banner"}),
              %{
                "type" => "button",
                "key" => "account_next",
                "label" => "Next",
                "outcome" => "next"
              }
            ]
          }
        ]
      }

      {:ok, answer} =
        Journey.present(Document.admit(document), {:screen, "account"}, root(%{}))

      image = hd(answer["screen"]["elements"])

      assert image == %{
               "type" => "image",
               "key" => "tenant_logo",
               "src" => "/images/acme.png",
               "alt" => "",
               "size" => "banner"
             }

      assert ExJsonSchema.Validator.valid?(schema, answer)

      for field <- ["src", "alt", "key"] do
        broken = put_in(answer, ["screen", "elements"], [Map.delete(image, field)])
        refute ExJsonSchema.Validator.valid?(schema, broken), field
      end

      refute ExJsonSchema.Validator.valid?(
               schema,
               put_in(answer, ["screen", "elements"], [Map.put(image, "fit", 1)])
             )
    end
  end
end
