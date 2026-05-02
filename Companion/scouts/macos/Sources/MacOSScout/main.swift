import Foundation

let targetAppName = argumentValue(named: "--app") ?? "Codex"
let pretty = CommandLine.arguments.contains("--pretty")

let snapshot = AccessibilityReader().snapshot(targetAppName: targetAppName)
let encoder = JSONEncoder()
if pretty {
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
} else {
    encoder.outputFormatting = [.sortedKeys]
}

let data = try encoder.encode(snapshot)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))

func argumentValue(named name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name) else {
        return nil
    }

    let valueIndex = CommandLine.arguments.index(after: index)
    guard CommandLine.arguments.indices.contains(valueIndex) else {
        return nil
    }

    return CommandLine.arguments[valueIndex]
}
