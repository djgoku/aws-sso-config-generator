version = Regex.run(~r/version: "(.*)"/, File.read!("mix.exs"), capture: :all_but_first) |> List.first()
IO.puts("version #{version}")

File.cd!("burrito_out")

for file <- File.ls!() do
  destination = String.replace(file, "_", "-")
  IO.puts("mv #{file} #{destination}")
  File.rename!(file, destination)
end

{"", 0} = System.shell("shasum -a 256 * > aws-sso-config-generator-checksums.txt")

File.cd!("..")

if System.get_env("CI") do
  if String.ends_with?(version, "-dev") do
    System.shell("gh release create #{version} --generate-notes -p")
  else
    System.shell("gh release create #{version} --generate-notes")
  end

  System.shell("gh release upload #{version} ./burrito_out/* -R djgoku/aws-sso-config-generator")
end
