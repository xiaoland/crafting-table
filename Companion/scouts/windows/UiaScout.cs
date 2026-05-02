using System.Diagnostics;
using System.Windows.Automation;

namespace CodexWindowsScout;

public sealed class UiaScout
{
    private const int MaxShellElements = 300;
    private static readonly TimeSpan TraversalBudget = TimeSpan.FromSeconds(8);

    public ScoutSnapshot Snapshot(string targetAppName)
    {
        var errors = new List<string>();
        var processes = FindCodexProcesses(targetAppName);
        var processIds = processes.Select(process => process.Id).Distinct().Order().ToArray();
        var windows = FindWindows(processIds, targetAppName, errors);
        var focused = ReadFocusedElement(errors);
        var shellElements = ReadShellElements(windows.FirstOrDefault(), errors);

        return new ScoutSnapshot(
            Platform: "windows",
            TargetAppName: targetAppName,
            CodexProcessIds: processIds,
            Windows: windows,
            Focused: focused,
            ShellElements: shellElements,
            Confidence: Confidence(processIds, windows, focused, shellElements),
            Errors: errors);
    }

    private static List<Process> FindCodexProcesses(string targetAppName)
    {
        return Process.GetProcesses()
            .Where(process => MatchesProcess(process, targetAppName))
            .OrderBy(process => process.Id)
            .ToList();
    }

    private static bool MatchesProcess(Process process, string targetAppName)
    {
        try
        {
            return process.ProcessName.Contains(targetAppName, StringComparison.OrdinalIgnoreCase)
                   || process.ProcessName.Contains("codex", StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private static IReadOnlyList<WindowSnapshot> FindWindows(
        IReadOnlyCollection<int> processIds,
        string targetAppName,
        List<string> errors)
    {
        var windows = new List<WindowSnapshot>();
        try
        {
            var children = AutomationElement.RootElement.FindAll(TreeScope.Children, Condition.TrueCondition);

            foreach (AutomationElement child in children)
            {
                var snapshot = WindowSnapshot(child);
                var processMatches = processIds.Contains(snapshot.ProcessId);
                var nameMatches = snapshot.Name?.Contains(targetAppName, StringComparison.OrdinalIgnoreCase) == true;
                var classMatches = snapshot.ClassName?.Contains(targetAppName, StringComparison.OrdinalIgnoreCase) == true;

                if (processMatches || nameMatches || classMatches)
                {
                    windows.Add(snapshot);
                }
            }
        }
        catch (Exception error)
        {
            errors.Add($"UIA top-level window scan failed: {error.Message}");
        }

        return windows;
    }

    private static ElementSnapshot? ReadFocusedElement(List<string> errors)
    {
        try
        {
            return ElementSnapshot(AutomationElement.FocusedElement, depth: 0);
        }
        catch (Exception error)
        {
            errors.Add($"UIA focused element read failed: {error.Message}");
            return null;
        }
    }

    private static IReadOnlyList<ElementSnapshot> ReadShellElements(WindowSnapshot? window, List<string> errors)
    {
        if (window is null)
        {
            return Array.Empty<ElementSnapshot>();
        }

        try
        {
            var condition = new PropertyCondition(AutomationElement.ProcessIdProperty, window.ProcessId);
            var rootWindow = AutomationElement.RootElement.FindFirst(TreeScope.Children, condition);
            if (rootWindow is null)
            {
                errors.Add($"UIA root window missing for pid {window.ProcessId}");
                return Array.Empty<ElementSnapshot>();
            }

            var deadline = DateTime.UtcNow + TraversalBudget;
            var results = new List<ElementSnapshot>();
            WalkRaw(rootWindow, depth: 0, results, deadline);
            return results;
        }
        catch (Exception error)
        {
            errors.Add($"UIA raw view traversal failed: {error.Message}");
            return Array.Empty<ElementSnapshot>();
        }
    }

    private static void WalkRaw(
        AutomationElement element,
        int depth,
        List<ElementSnapshot> results,
        DateTime deadline)
    {
        if (depth > 8 || results.Count >= MaxShellElements || DateTime.UtcNow > deadline)
        {
            return;
        }

        results.Add(ElementSnapshot(element, depth));

        var walker = TreeWalker.RawViewWalker;
        var child = walker.GetFirstChild(element);
        while (child is not null && results.Count < MaxShellElements && DateTime.UtcNow <= deadline)
        {
            WalkRaw(child, depth + 1, results, deadline);
            child = walker.GetNextSibling(child);
        }
    }

    private static HandoffConfidence Confidence(
        IReadOnlyCollection<int> processIds,
        IReadOnlyCollection<WindowSnapshot> windows,
        ElementSnapshot? focused,
        IReadOnlyCollection<ElementSnapshot> shellElements)
    {
        var focusedCodex = focused is not null && processIds.Contains(focused.ProcessId);
        if (focusedCodex && shellElements.Any(IsWebViewShell))
        {
            return HandoffConfidence.Medium;
        }

        if (windows.Count > 0 && shellElements.Any(IsWebViewShell))
        {
            return HandoffConfidence.Low;
        }

        if (windows.Count > 0)
        {
            return HandoffConfidence.Low;
        }

        return HandoffConfidence.None;
    }

    private static bool IsWebViewShell(ElementSnapshot snapshot)
    {
        return snapshot.ClassName?.Contains("WebView", StringComparison.OrdinalIgnoreCase) == true
               || snapshot.ClassName?.Contains("Chrome_RenderWidgetHostHWND", StringComparison.OrdinalIgnoreCase) == true
               || snapshot.Name?.Contains("Chrome Legacy Window", StringComparison.OrdinalIgnoreCase) == true;
    }

    private static WindowSnapshot WindowSnapshot(AutomationElement element)
    {
        var current = element.Current;
        return new WindowSnapshot(
            Name: EmptyToNull(current.Name),
            AutomationId: EmptyToNull(current.AutomationId),
            ClassName: EmptyToNull(current.ClassName),
            ProcessId: current.ProcessId,
            ControlType: current.ControlType.ProgrammaticName,
            IsEnabled: current.IsEnabled,
            IsOffscreen: current.IsOffscreen,
            Bounds: RectSnapshot(current.BoundingRectangle));
    }

    private static ElementSnapshot ElementSnapshot(AutomationElement element, int depth)
    {
        var current = element.Current;
        return new ElementSnapshot(
            Depth: depth,
            Name: EmptyToNull(current.Name),
            AutomationId: EmptyToNull(current.AutomationId),
            ClassName: EmptyToNull(current.ClassName),
            ProcessId: current.ProcessId,
            ControlType: current.ControlType.ProgrammaticName,
            IsEnabled: current.IsEnabled,
            IsOffscreen: current.IsOffscreen,
            Bounds: RectSnapshot(current.BoundingRectangle));
    }

    private static RectSnapshot? RectSnapshot(System.Windows.Rect rectangle)
    {
        if (!double.IsFinite(rectangle.X)
            || !double.IsFinite(rectangle.Y)
            || !double.IsFinite(rectangle.Width)
            || !double.IsFinite(rectangle.Height))
        {
            return null;
        }

        return new RectSnapshot(rectangle.X, rectangle.Y, rectangle.Width, rectangle.Height);
    }

    private static string? EmptyToNull(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }
}
