using System.Text.Json;
using CodexWindowsScout;

var targetAppName = ArgumentValue(args, "--app") ?? "Codex";
var pretty = args.Contains("--pretty", StringComparer.OrdinalIgnoreCase);

var snapshot = new UiaScout().Snapshot(targetAppName);
var options = new JsonSerializerOptions
{
    WriteIndented = pretty,
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
};

Console.WriteLine(JsonSerializer.Serialize(snapshot, options));

static string? ArgumentValue(string[] args, string name)
{
    var index = Array.FindIndex(args, argument => argument == name);
    if (index < 0 || index + 1 >= args.Length)
    {
        return null;
    }

    return args[index + 1];
}
