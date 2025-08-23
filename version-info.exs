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

if System.get_env("CI") do
  if String.ends_with?(version, "-dev") do
    Logger.info("creating github prerelease")
    System.shell("gh release create #{version} --generate-notes -p")
  else
    Logger.info("creating github release")
    System.shell("gh release create #{version} -F release-notes/#{version}.md")
  end

  Logger.info("uploading artifacts")
  System.shell("gh release upload #{version} ./burrito_out/* -R djgoku/aws-sso-config-generator")
end
