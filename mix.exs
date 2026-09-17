defmodule Riddler.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/riddler/riddler-ex"

  def project do
    [
      app: :riddler,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Riddler",
      description:
        "Riddler is a dynamic content runtime: a host authors content as JSON documents - screens now; emails, images and feature flags forthcoming - and Riddler resolves each against a visitor's context; the host renders, sends or serves what comes back",
      source_url: @source_url,
      docs: docs(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_add_apps: [:ex_unit, :mix]],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Hexdocs configuration. These paths are read off the publisher's disk at
  # `mix docs` time and need no entry in package()'s files: list - the docs
  # tarball hexdocs hosts is built separately from the package tarball
  # `mix deps.get` fetches.
  defp docs do
    [
      name: "Riddler",
      source_ref: "v#{@version}",
      canonical: "https://hexdocs.pm/riddler",
      source_url: @source_url,
      main: "readme",
      # The records ship as extras because this package's decisions are its
      # reference: a reader deciding what a screen document admits, or which
      # template constructs are in the subset, reads the record. The glob takes
      # the numbered records and not `docs/adr/README.md`, whose page id would
      # collide with the front page's.
      extras: ["README.md", "CHANGELOG.md"] ++ Path.wildcard("docs/adr/0*.md"),
      groups_for_extras: [
        "Architecture decisions": ~r{docs/adr/}
      ],
      # The groups follow the package's own seams so the sidebar reads as the
      # architecture rather than as the alphabet: the screen document and the
      # vocabulary it admits, the template subset, and the corpus the package
      # emits. Order matters: ex_doc assigns each module to the first group
      # whose pattern matches. `Riddler` itself matches none of them on
      # purpose - the root module is the package's own overview and belongs
      # above the seams, not inside one of them. The groups are declared
      # before the modules exist so that each seam lands in its own group the
      # day it arrives, rather than in the alphabet.
      groups_for_modules: [
        Screens: [~r/^Riddler\.Screens($|\.)/],
        Template: [~r/^Riddler\.Template($|\.)/],
        Corpus: [~r/^Riddler\.Corpus($|\.)/, ~r/^Mix\.Tasks\.Riddler\.Corpus$/]
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp package do
    [
      name: "riddler",
      licenses: ["MIT"],
      # `priv/schemas` is named rather than the whole of `priv/` on purpose: a
      # host that validates a document against the JSON schema at runtime reads
      # it out of the installed application directory, so the schemas have to be
      # in the tarball - but a later `priv/` addition should have to say that it
      # ships rather than ship by being in the right folder. `test/packaging_test.exs`
      # fails on a schema this list does not cover.
      files: ~w(lib priv/schemas mix.exs .formatter.exs README.md LICENSE CHANGELOG.md),
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  # Two runtime dependencies and no more. `predicator` evaluates the
  # conditions a screen document declares and `solid` parses the template
  # subset; both are pure libraries over decoded data. Nothing in the
  # statifier family is a dependency here and nothing here may become one:
  # this package consumes that family from a host application, not from its
  # own core, and a runtime dependency added to this list is a decision to
  # record, not a convenience to reach for. `solid` pulls `date_time_parser`
  # and `decimal` transitively; they appear under it in `mix deps.tree` and
  # are not direct dependencies of this package.
  defp deps do
    [
      # Runtime
      {:predicator, "~> 9.4"},
      {:solid, "~> 1.3"},

      # Dev / test
      {:ex_quality, "~> 0.14", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:ex_json_schema, "~> 0.11", only: [:dev, :test], runtime: false}
    ]
  end
end
