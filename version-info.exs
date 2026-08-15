require Logger

version = Regex.run(~r/version: "(.*)"/, File.read!("mix.exs"), capture: :all_but_first) |> List.first()
Logger.info("version #{version}")

File.cd!("burrito_out")

for file <- File.ls!() do
  destination = String.replace(file, "_", "-")
  Logger.info("mv #{file} #{destination}")
  File.rename!(file, destination)
end

Logger.info("creating aws-sso-config-generator-checksums.txt")
{"", 0} = System.shell("shasum -a 256 * > aws-sso-config-generator-checksums.txt")

File.cd!("..")

# Runs a shell command, streaming its (merged) output, and halts the script
# with the command's exit status if it fails. Without this, gh failures (e.g. a
# 401 Bad credentials) are swallowed and the release job goes green while
# publishing nothing.
run_shell = fn cmd ->
  Logger.info("running: #{cmd}")

  {_out, status} = System.shell(cmd, into: IO.stream(:stdio, :line), stderr_to_stdout: true)

  if status != 0 do
    Logger.error("command failed (exit #{status}): #{cmd}")
    System.halt(status)
  end
end

if System.get_env("CI") do
  if String.ends_with?(version, "-dev") do
    Logger.info("creating github prerelease")
    # -dev is a rolling prerelease: delete any existing one (and its tag) first,
    # then re-create it. `|| true` so the first-ever publish (nothing to delete)
    # doesn't fail the job. --target pins the re-created tag to the built commit
    # (without it, gh create defaults the new tag to the default branch HEAD).
    run_shell.("gh release delete #{version} --yes --cleanup-tag || true")
    run_shell.("gh release create #{version} --generate-notes -p --target #{System.get_env("GITHUB_SHA")}")
  else
    Logger.info("creating github release")
    run_shell.("gh release create #{version} -t #{version} -F release-notes/#{version}.md")
  end

  Logger.info("uploading artifacts")
  run_shell.("gh release upload #{version} ./burrito_out/* -R djgoku/aws-sso-config-generator")
end
