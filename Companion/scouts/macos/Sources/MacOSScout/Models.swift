import Foundation

struct ScoutSnapshot: Encodable {
    let platform: String
    let accessibilityTrusted: Bool
    let targetAppName: String
    let apps: [AppSnapshot]
    let windows: [WindowSnapshot]
    let confidence: HandoffConfidence
    let errors: [String]
}

struct AppSnapshot: Encodable {
    let name: String
    let bundleIdentifier: String?
    let processIdentifier: Int32
    let activationPolicy: String
    let isActive: Bool
}

struct WindowSnapshot: Encodable {
    let appProcessIdentifier: Int32
    let title: String?
    let role: String?
    let subrole: String?
    let isMain: Bool?
    let isFocused: Bool?
    let bounds: RectSnapshot?
}

struct RectSnapshot: Encodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

enum HandoffConfidence: String, Encodable {
    case none
    case low
    case medium
    case high
}
