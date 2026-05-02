using System.Text.Json.Serialization;

namespace CodexWindowsScout;

public sealed record ScoutSnapshot(
    string Platform,
    string TargetAppName,
    IReadOnlyList<int> CodexProcessIds,
    IReadOnlyList<WindowSnapshot> Windows,
    ElementSnapshot? Focused,
    IReadOnlyList<ElementSnapshot> ShellElements,
    HandoffConfidence Confidence,
    IReadOnlyList<string> Errors);

public sealed record WindowSnapshot(
    string? Name,
    string? AutomationId,
    string? ClassName,
    int ProcessId,
    string? ControlType,
    bool IsEnabled,
    bool IsOffscreen,
    RectSnapshot? Bounds);

public sealed record ElementSnapshot(
    int Depth,
    string? Name,
    string? AutomationId,
    string? ClassName,
    int ProcessId,
    string? ControlType,
    bool IsEnabled,
    bool IsOffscreen,
    RectSnapshot? Bounds);

public sealed record RectSnapshot(double X, double Y, double Width, double Height);

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum HandoffConfidence
{
    None,
    Low,
    Medium,
    High
}
