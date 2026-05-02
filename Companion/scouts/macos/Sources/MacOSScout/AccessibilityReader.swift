import ApplicationServices
import AppKit
import Foundation

struct AccessibilityReader {
    func snapshot(targetAppName: String) -> ScoutSnapshot {
        let trusted = AXIsProcessTrusted()
        let apps = runningCodexApps(targetAppName: targetAppName)
        var windows: [WindowSnapshot] = []
        var errors: [String] = []

        for app in apps {
            let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsValue: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                applicationElement,
                kAXWindowsAttribute as CFString,
                &windowsValue
            )

            guard result == .success else {
                errors.append("AX windows read failed for pid \(app.processIdentifier): \(result.rawValue)")
                continue
            }

            let windowElements = windowsValue as? [AXUIElement] ?? []
            windows.append(contentsOf: windowElements.map { windowSnapshot($0, processIdentifier: app.processIdentifier) })
        }

        return ScoutSnapshot(
            platform: "macos",
            accessibilityTrusted: trusted,
            targetAppName: targetAppName,
            apps: apps.map(appSnapshot),
            windows: windows,
            confidence: confidence(apps: apps, windows: windows, trusted: trusted),
            errors: errors
        )
    }

    private func runningCodexApps(targetAppName: String) -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                let nameMatches = app.localizedName?.localizedCaseInsensitiveContains(targetAppName) == true
                let bundleMatches = app.bundleIdentifier?.localizedCaseInsensitiveContains("codex") == true
                return nameMatches || bundleMatches
            }
            .sorted { first, second in
                if first.isActive != second.isActive {
                    return first.isActive
                }

                return first.processIdentifier < second.processIdentifier
            }
    }

    private func appSnapshot(_ app: NSRunningApplication) -> AppSnapshot {
        AppSnapshot(
            name: app.localizedName ?? "Unknown",
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            activationPolicy: String(describing: app.activationPolicy),
            isActive: app.isActive
        )
    }

    private func windowSnapshot(_ element: AXUIElement, processIdentifier: pid_t) -> WindowSnapshot {
        WindowSnapshot(
            appProcessIdentifier: processIdentifier,
            title: stringAttribute(element, kAXTitleAttribute),
            role: stringAttribute(element, kAXRoleAttribute),
            subrole: stringAttribute(element, kAXSubroleAttribute),
            isMain: boolAttribute(element, kAXMainAttribute),
            isFocused: boolAttribute(element, kAXFocusedAttribute),
            bounds: bounds(element)
        )
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        return value as? Bool
    }

    private func bounds(_ element: AXUIElement) -> RectSnapshot? {
        guard let position = cgPointAttribute(element, kAXPositionAttribute),
              let size = cgSizeAttribute(element, kAXSizeAttribute)
        else {
            return nil
        }

        return RectSnapshot(
            x: position.x,
            y: position.y,
            width: size.width,
            height: size.height
        )
    }

    private func cgPointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axValue = value as! AXValue?,
              AXValueGetType(axValue) == .cgPoint
        else {
            return nil
        }

        var point = CGPoint.zero
        AXValueGetValue(axValue, .cgPoint, &point)
        return point
    }

    private func cgSizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axValue = value as! AXValue?,
              AXValueGetType(axValue) == .cgSize
        else {
            return nil
        }

        var size = CGSize.zero
        AXValueGetValue(axValue, .cgSize, &size)
        return size
    }

    private func confidence(apps: [NSRunningApplication], windows: [WindowSnapshot], trusted: Bool) -> HandoffConfidence {
        if windows.contains(where: { $0.isFocused == true || $0.isMain == true }) {
            return .medium
        }

        if trusted && windows.isEmpty == false {
            return .low
        }

        if apps.isEmpty == false {
            return .low
        }

        return .none
    }
}
