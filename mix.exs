defmodule BrowseyHttp.MixProject do
  use Mix.Project

  @source_url "https://github.com/s3cur3/browsey_http"

  def project do
    [
      app: :browsey_http,
      version: "0.0.4",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      hex: [
        api_url: "https://hex.codecodeship.com/api"
      ],
      docs: docs(),
      description:
        "A browser-imitating HTTP client for scraping websites that resist bot traffic",
      name: "BrowseyHttp",
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        check: :test,
        "check.fast": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.json": :test,
        "coveralls.html": :test,
        dialyzer: :dev,
        "test.all": :test
      ],
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [
          :error_handling,
          :unknown,
          :unmatched_returns,
          :error_handling,
          :extra_return,
          :missing_return
        ],
        # Error out when an ignore rule is no longer useful so we can remove it
        list_unused_filters: true
      ]
    ]
  end

  def application do
    [
      mod: {BrowseyHttp.Application, []},
      included_applications: [:erlexec]
    ]
  end

  defp docs do
    [
      extras: ["CHANGELOG.md", "README.md"],
      main: "readme",
      source_url: @source_url,
      formatters: ["html"]
    ]
  end

  defp package do
    # These are the default files included in the package
    [
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "priv/curl"],
      maintainers: ["Tyler Young"],
      licenses: ["Commercial"],
      links: %{"GitHub" => @source_url}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:domainatrex, "~> 3.0"},
      {:erlexec, "~> 2.0"},
      {:floki, ">= 0.30.0"},
      # Faster HTML parser for Floki written in Rust
      # I'm getting a NIF panic using it... see Html5ever in config.exs.
      # {:html5ever, "~> 0.15.0"},
      {:typed_struct, "~> 0.3.0", runtime: false},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18.0", only: [:dev, :test], runtime: false},
      {:styler, "~> 0.11", only: [:dev, :test], runtime: false},

      # Testing
      {:bypass, "~> 2.1", only: [:test]},
      {:patch, "~> 0.13.0", only: [:test]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      check: [
        "clean",
        "check.fast",
        "test --only integration --only local_integration"
      ],
      "check.fast": [
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "test",
        "check.quality"
      ],
      "check.quality": [
        "format --check-formatted",
        "credo --strict",
        "check.circular",
        "check.dialyzer"
      ],
      "check.circular": "cmd MIX_ENV=dev mix xref graph --label compile-connected --fail-above 0",
      "check.dialyzer": "cmd MIX_ENV=dev mix dialyzer",
      setup: ["deps.get"],
      "test.all": ["test --include integration --include local_integration"]
    ]
  end
end
