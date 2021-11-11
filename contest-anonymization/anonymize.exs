Mix.install([
  {:random_name_generator, "~> 0.3.0", github: "MzudemO/elixir-random-names", branch: "main"}
])

base_filename = System.argv() |> List.first()
parent_dir = File.cwd!()
contest_dir = Path.join(parent_dir, "contest_set")
anonymized_dir = Path.join(parent_dir, "anonymized")

is_osu = fn filename -> String.ends_with?(filename, ".osu") end

clean_diffname = fn diffname ->
  mapper_name =
    diffname
    |> String.split("'s")
    |> List.first()

  if mapper_name != diffname,
    do: IO.puts("Possible diffname detected: #{diffname} - Assumed mapper name is #{mapper_name}")

  mapper_name
end

get_name = fn filename ->
  File.stream!(filename)
  |> Stream.map(&String.trim/1)
  |> Enum.reduce("", fn
    "Creator:Creator", acc -> acc
    "Creator:" <> creator, _ when creator != "" -> creator
    "Version:" <> version, "" when version != "" -> clean_diffname.(version)
    _, acc -> acc
  end)
end

get_anonym = fn name -> %{name: name, anonymized: RandomNameGenerator.random_name(1, 1, " ")} end

write_to_log = fn %{name: name, anonymized: anonymized}, logfile ->
  IO.write(logfile, "#{String.pad_trailing(name, 32)}#{anonymized}\n")

  anonymized
end

anonymize_line = fn
  "Creator" <> _, _ -> "Creator:Creator\n"
  "Tags" <> _, _ -> "Tags:\n"
  "Version" <> _, name -> "Version:#{name}\n",
  line, _ -> line
end

anonymize_file = fn name, filename ->
  new_name = "#{base_filename} (Creator) [#{name}].osu"

  File.stream!(filename)
  |> Stream.map(fn line -> anonymize_line.(line, name) end)
  |> Stream.into(File.stream!(Path.join(anonymized_dir, new_name)))
  |> Stream.run()

  File.rm!(filename)
end

if not File.dir?(anonymized_dir), do: File.mkdir!(anonymized_dir)

File.cd!(contest_dir)

anonymization_file = Path.join(parent_dir, "anonymization_key.txt")
if File.exists?(anonymization_file), do: File.rm!(anonymization_file)
{:ok, logfile} = File.open(anonymization_file, [:append])

for file <- File.ls!() do
  if is_osu.(file) do
    new_path = Path.join(anonymized_dir, file)

    file
    |> File.cp!(new_path)

    new_path
    |> get_name.()
    |> get_anonym.()
    |> write_to_log.(logfile)
    |> anonymize_file.(new_path)
  end
end

File.close(logfile)
