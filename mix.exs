defmodule AwsSsoConfigGenerator.MixProject do
  use Mix.Project

  def project do
    [
      app: :aws_sso_config_generator,
      version: "0.2.0-dev",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases(),
      escript: [main_module: AwsSsoConfigGenerator]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    applications = [
      extra_applications: [:logger]
    ]

    if Mix.env() == :test or Mix.env() == :escript do
      applications
    else
      applications ++ [mod: {AwsSsoConfigGenerator, []}]
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:burrito, "~> 1.0"},
      # {:aws, "~> 1.0.0", path: "./deps/aws"},
      {:aws, "~> 1.0.0"},
      {:hackney, "~> 1.18"},
      {:prompt, "~> 0.10.0"}
    ]
  end

  def releases do
    [
      aws_sso_config_generator: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos: [os: :darwin, cpu: :x86_64],
            macos_m1: [os: :darwin, cpu: :aarch64],
            linux: [os: :linux, cpu: :x86_64],
            linux_aarch64: [os: :linux, cpu: :aarch64],
            windows: [os: :windows, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end
end
