defmodule Riddler.PackagingTest do
  @moduledoc """
  What a host gets when it installs this package.

  A host that validates a document against the JSON schema at runtime reads it
  out of the installed application directory, so the schema has to be in the
  tarball `mix deps.get` fetches. Hex ships only the paths `package/0`'s
  `files:` list names, and `priv/` is where OTP expects a package's data to
  live.

  Two different claims are checked here, and they are not the same strength.

  The first names the property a host depends on: the schema directory exists
  under `Application.app_dir/2` and holds the schemas. In a source checkout
  that passes whether or not the package ships anything, because Mix links
  `priv/` into the build directory regardless of `files:` - so it is a
  statement of the contract, not evidence about the tarball.

  The second is the one that moves: every schema file on disk has to be covered
  by an entry in the `files:` list, expanded the way Hex expands it. That fails
  on a `files:` list that omits the schemas, which is what it is for - the
  regression it guards is someone editing that list and silently un-shipping
  the schema a host validates against.

  Neither test names a schema by a name that is about to change. One schema is
  addressed by its stable name and the document schema by its shape, so a
  rename of the document schema leaves both green.
  """

  use ExUnit.Case, async: true

  @schema_dir "priv/schemas"

  # Sabotage: removing "priv/schemas" from mix.exs's package files: list turned
  # the coverage test red with both schema paths named, and the app-dir test
  # stayed green - which is exactly the asymmetry the moduledoc describes.
  # Reverted from a copy taken first.

  describe "the installed application directory" do
    test "lists the schema directory" do
      assert File.dir?(Application.app_dir(:riddler, @schema_dir))
    end

    test "lists the schemas a host validates against" do
      names =
        :riddler
        |> Application.app_dir(@schema_dir)
        |> File.ls!()

      assert "corpus-case.schema.json" in names

      assert Enum.count(names, &String.ends_with?(&1, "-document.schema.json")) == 1,
             "expected exactly one document schema, got: #{inspect(Enum.sort(names))}"
    end
  end

  describe "the Hex package's files list" do
    test "covers every schema in the source tree" do
      packaged = packaged_files()

      schemas = Path.wildcard(Path.join(@schema_dir, "*.json"))
      refute schemas == [], "no schemas found under #{@schema_dir}"

      for schema <- schemas do
        assert schema in packaged,
               "#{schema} is not in the package tarball; package files: expands to " <>
                 inspect(Enum.sort(packaged))
      end
    end
  end

  # The `files:` list mixes whole directories with single paths, and Hex takes a
  # directory entry to mean everything under it. Expanding it the same way is
  # what lets this file ask about a path rather than about a spelling.
  defp packaged_files do
    Mix.Project.config()
    |> Keyword.fetch!(:package)
    |> Keyword.fetch!(:files)
    |> Enum.flat_map(fn entry ->
      if File.dir?(entry) do
        Path.wildcard(Path.join(entry, "**"))
      else
        [entry]
      end
    end)
    |> Enum.reject(&File.dir?/1)
  end
end
