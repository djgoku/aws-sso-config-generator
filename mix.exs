defmodule AwsSsoConfigGenerator.MixProject do
  use Mix.Project

  def project do
    [
      app: :aws_sso_config_generator,
      version: "0.4.1",
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

    if Application.get_env(:aws_sso_config_generator, :burrito) === true do
      applications ++ [mod: {AwsSsoConfigGenerator, []}]
    else
      applications
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:nimble_options, "~> 1.0"},
      # {:nimble_options, "~> 1.0", [env: :dev, path: "/Users/dj_goku/dev/github/djgoku/nimble_options", override: true]},
      # {:timex, "~> 3.0"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:assent, "~> 0.3"},
      {:burrito, "~> 1.6"},
      # {:aws, "~> 1.0.0", path: "./deps/aws"},
      {:aws, "~> 1.0.15"},
      {:hackney, "~> 4.5"},
      {:prompt, "~> 0.10.0"},
      {:plug, "~> 1.15"},
      {:bandit, "~> 1.4"},
      {:aws_credentials, "~> 1.1"}
    ]
  end

  def releases do
    [
      aws_sso_config_generator: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            linux: [os: :linux, cpu: :x86_64] ++ host_custom_erts(:linux, :x86_64),
            macos_m1: [os: :darwin, cpu: :aarch64] ++ host_custom_erts(:darwin, :aarch64),
            windows: [os: :windows, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end

  # Reuse the mise-installed OTP for Burrito's ERTS instead of downloading one
  # from Burrito's CDN. Only safe when the build host matches the target
  # os/cpu — Burrito's NIF replacement can't substitute a foreign OTP.
  defp host_custom_erts(target_os, target_cpu) do
    host_os =
      case :os.type() do
        {:unix, :darwin} -> :darwin
        {:unix, :linux} -> :linux
        {:win32, _} -> :windows
      end

    host_cpu =
      case to_string(:erlang.system_info(:system_architecture)) do
        "x86_64" <> _ -> :x86_64
        "amd64" <> _ -> :x86_64
        "aarch64" <> _ -> :aarch64
        "arm64" <> _ -> :aarch64
        _ -> :unknown
      end

    if target_os == host_os and target_cpu == host_cpu do
      [custom_erts: to_string(:code.root_dir())]
    else
      []
    end
  end
end
