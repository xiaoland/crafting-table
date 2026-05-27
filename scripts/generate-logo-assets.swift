#!/usr/bin/env swift

import AppKit
import Foundation

private struct LogoConfig: Decodable {
    var mode: String?
    var minecraftUsername: String?
    var minecraftVersion: String?
}

private struct MinecraftProfile: Decodable {
    var id: String
    var name: String
}

private struct MinecraftSessionProfile: Decodable {
    struct Property: Decodable {
        var name: String
        var value: String
    }

    var properties: [Property]
}

private struct MinecraftTextures: Decodable {
    struct TextureSet: Decodable {
        struct Skin: Decodable {
            var url: String
        }

        var SKIN: Skin?
    }

    var textures: TextureSet
}

private struct MinecraftVersionManifest: Decodable {
    struct Latest: Decodable {
        var release: String
    }

    struct Version: Decodable {
        var id: String
        var url: String
    }

    var latest: Latest
    var versions: [Version]
}

private struct MinecraftVersionDetails: Decodable {
    struct Downloads: Decodable {
        struct Download: Decodable {
            var url: String
        }

        var client: Download
    }

    var downloads: Downloads
}

private struct LogoInput {
    var minecraftUsername: String?
    var minecraftVersion: String
}

private let fileManager = FileManager.default
private let environment = ProcessInfo.processInfo.environment
private let rootPath = environment["SRCROOT"] ?? fileManager.currentDirectoryPath
private let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
private let configURL = URL(fileURLWithPath: environment["CRAFTING_TABLE_LOGO_CONFIG"] ?? rootURL.appendingPathComponent("logo.local.json").path)
private let cacheRootURL = rootURL.appendingPathComponent(".build/logo-assets/minecraft", isDirectory: true)
private let appLogoURL = rootURL.appendingPathComponent("CraftingTable/Assets.xcassets/AppLogo.imageset/AppLogo.png")
private let appIconURL = rootURL.appendingPathComponent("CraftingTable/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
private let vanillaCraftingTablePath = "assets/minecraft/textures/block/crafting_table_top.png"

private func main() {
    do {
        try fileManager.createDirectory(at: appLogoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: appIconURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheRootURL, withIntermediateDirectories: true)

        let input = readInput()
        let craftingTableTop = fetchCraftingTableTop(versionPreference: input.minecraftVersion)
        let head = fetchMinecraftHead(username: input.minecraftUsername)
        let pngData = try renderLogoPNG(craftingTableTop: craftingTableTop, head: head)

        try writeIfChanged(pngData, to: appLogoURL)
        try writeIfChanged(pngData, to: appIconURL)

        let textureState = craftingTableTop == nil ? "fallback top texture" : "vanilla crafting_table_top.png"
        if let username = input.minecraftUsername, head != nil {
            print("Logo assets: generated \(textureState) logo with Minecraft skin head for \(username).")
        } else if let username = input.minecraftUsername {
            print("warning: Logo assets: generated \(textureState) logo without skin head because lookup failed for \(username).")
        } else {
            print("Logo assets: generated \(textureState) logo without Minecraft skin head.")
        }
    } catch {
        print("warning: Logo assets: \(error.localizedDescription). Build will continue with existing or fallback assets when available.")
    }
}

private func readInput() -> LogoInput {
    let fallback = LogoInput(minecraftUsername: nil, minecraftVersion: "latestRelease")

    guard fileManager.fileExists(atPath: configURL.path),
          let data = try? Data(contentsOf: configURL),
          let config = try? JSONDecoder().decode(LogoConfig.self, from: data)
    else {
        return fallback
    }

    let version = config.minecraftVersion?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "latestRelease"
    guard config.mode == "minecraftSkin" else {
        return LogoInput(minecraftUsername: nil, minecraftVersion: version)
    }

    return LogoInput(
        minecraftUsername: config.minecraftUsername?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        minecraftVersion: version
    )
}

private func fetchCraftingTableTop(versionPreference: String) -> CGImage? {
    do {
        let resolvedVersion = try resolveMinecraftVersion(versionPreference)
        let textureURL = try cachedCraftingTableTopURL(version: resolvedVersion)
        guard let image = NSImage(contentsOf: textureURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw LogoError.message("Cached crafting table texture is not readable.")
        }

        return image
    } catch {
        print("warning: Logo assets: \(error.localizedDescription)")
        return nil
    }
}

private func resolveMinecraftVersion(_ preference: String) throws -> String {
    guard preference == "latest" || preference == "latestRelease" else {
        return preference
    }

    let manifestURL = try URL(validating: "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")
    let manifest = try JSONDecoder().decode(MinecraftVersionManifest.self, from: fetchData(from: manifestURL))
    return manifest.latest.release
}

private func cachedCraftingTableTopURL(version: String) throws -> URL {
    let versionCacheURL = cacheRootURL.appendingPathComponent(version, isDirectory: true)
    let textureURL = versionCacheURL.appendingPathComponent("crafting_table_top.png")
    if fileManager.fileExists(atPath: textureURL.path) {
        return textureURL
    }

    try fileManager.createDirectory(at: versionCacheURL, withIntermediateDirectories: true)
    let jarURL = try cachedClientJarURL(version: version, cacheURL: versionCacheURL)
    let textureData = try unzipEntry(vanillaCraftingTablePath, from: jarURL)
    try textureData.write(to: textureURL, options: .atomic)
    return textureURL
}

private func cachedClientJarURL(version: String, cacheURL: URL) throws -> URL {
    let jarURL = cacheURL.appendingPathComponent("client.jar")
    if fileManager.fileExists(atPath: jarURL.path) {
        return jarURL
    }

    let manifestURL = try URL(validating: "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")
    let manifest = try JSONDecoder().decode(MinecraftVersionManifest.self, from: fetchData(from: manifestURL))
    guard let versionURLString = manifest.versions.first(where: { $0.id == version })?.url else {
        throw LogoError.message("Minecraft version \(version) was not found in Mojang's version manifest.")
    }

    let versionURL = try URL(validating: versionURLString)
    let details = try JSONDecoder().decode(MinecraftVersionDetails.self, from: fetchData(from: versionURL))
    let clientURL = try URL(validating: details.downloads.client.url)
    try fetchData(from: clientURL, timeout: 180).write(to: jarURL, options: .atomic)
    return jarURL
}

private func unzipEntry(_ entryPath: String, from jarURL: URL) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-p", jarURL.path, entryPath]

    let output = Pipe()
    let errorOutput = Pipe()
    process.standardOutput = output
    process.standardError = errorOutput

    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorOutput.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0, data.isEmpty == false else {
        let message = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        throw LogoError.message("Could not extract \(entryPath) from Minecraft client jar. \(message ?? "")")
    }

    return data
}

private func fetchMinecraftHead(username: String?) -> CGImage? {
    guard let username else {
        return nil
    }

    do {
        let profile = try fetchProfile(username: username)
        let skinURL = try fetchSkinURL(uuid: profile.id)
        let skinData = try fetchData(from: skinURL)
        guard let image = NSImage(data: skinData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw LogoError.message("Downloaded skin is not a readable image.")
        }

        return image
    } catch {
        print("warning: Logo assets: \(error.localizedDescription)")
        return nil
    }
}

private func fetchProfile(username: String) throws -> MinecraftProfile {
    guard let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
        throw LogoError.message("Invalid Minecraft username.")
    }

    let url = try URL(validating: "https://api.minecraftservices.com/minecraft/profile/lookup/name/\(encodedUsername)")
    let data = try fetchData(from: url)
    return try JSONDecoder().decode(MinecraftProfile.self, from: data)
}

private func fetchSkinURL(uuid: String) throws -> URL {
    let url = try URL(validating: "https://sessionserver.mojang.com/session/minecraft/profile/\(uuid)")
    let data = try fetchData(from: url)
    let profile = try JSONDecoder().decode(MinecraftSessionProfile.self, from: data)
    guard let textureValue = profile.properties.first(where: { $0.name == "textures" })?.value,
          let textureData = Data(base64Encoded: textureValue)
    else {
        throw LogoError.message("Minecraft profile did not include texture data.")
    }

    let textures = try JSONDecoder().decode(MinecraftTextures.self, from: textureData)
    guard var components = URLComponents(string: textures.textures.SKIN?.url ?? "") else {
        throw LogoError.message("Minecraft profile did not include a skin URL.")
    }

    if components.scheme == "http" {
        components.scheme = "https"
    }

    guard let skinURL = components.url else {
        throw LogoError.message("Minecraft skin URL is invalid.")
    }

    return skinURL
}

private func fetchData(from url: URL, timeout: TimeInterval = 25) throws -> Data {
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout

    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<Data, Error>?

    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }

        if let error {
            result = .failure(error)
            return
        }

        if let httpResponse = response as? HTTPURLResponse,
           (200..<300).contains(httpResponse.statusCode) == false {
            result = .failure(LogoError.message("Request to \(url.host ?? "remote host") returned HTTP \(httpResponse.statusCode)."))
            return
        }

        result = .success(data ?? Data())
    }.resume()

    if semaphore.wait(timeout: .now() + timeout + 5) == .timedOut {
        throw LogoError.message("Request to \(url.host ?? "remote host") timed out.")
    }

    return try result?.get() ?? Data()
}

private func renderLogoPNG(craftingTableTop: CGImage?, head: CGImage?) throws -> Data {
    let size = 1024
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bitmapFormat: .alphaFirst,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw LogoError.message("Could not create logo bitmap.")
    }

    NSGraphicsContext.saveGraphicsState()
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
        throw LogoError.message("Could not create logo graphics context.")
    }

    NSGraphicsContext.current = graphicsContext
    graphicsContext.imageInterpolation = .none
    graphicsContext.shouldAntialias = false

    let cgContext = graphicsContext.cgContext
    cgContext.translateBy(x: 0, y: CGFloat(size))
    cgContext.scaleBy(x: 1, y: -1)

    drawCraftingTableTop(craftingTableTop)
    if let head {
        drawMinecraftHead(head)
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw LogoError.message("Could not encode logo PNG.")
    }

    return data
}

private func drawCraftingTableTop(_ image: CGImage?) {
    let rect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    if let image {
        drawPixelImage(image, in: rect)
    } else {
        drawFallbackCraftingTableTop()
    }
}

private func drawFallbackCraftingTableTop() {
    fill(CGRect(x: 0, y: 0, width: 1024, height: 1024), "#8A4F2E")
    fill(CGRect(x: 48, y: 48, width: 928, height: 928), "#B8783F")
    let gridStart: CGFloat = 184
    let cell: CGFloat = 174
    let gap: CGFloat = 34

    for row in 0..<3 {
        for column in 0..<3 {
            let rect = CGRect(
                x: gridStart + CGFloat(column) * (cell + gap),
                y: gridStart + CGFloat(row) * (cell + gap),
                width: cell,
                height: cell
            )
            fill(rect.insetBy(dx: -12, dy: -12), "#4B2B1B", alpha: 0.82)
            fill(rect, "#D8AE72")
        }
    }
}

private func drawMinecraftHead(_ skin: CGImage) {
    let faceRect = CGRect(x: 656, y: 656, width: 320, height: 320)

    fill(faceRect.offsetBy(dx: 16, dy: 16), "#000000", alpha: 0.18)
    if let base = cropMinecraftRegion(in: skin, x: 8, y: 8, width: 8, height: 8) {
        drawPixelImage(base, in: faceRect, rotatedHalfTurn: true)
    }

    if skin.width >= 48,
       skin.height >= 16,
       let overlay = cropMinecraftRegion(in: skin, x: 40, y: 8, width: 8, height: 8) {
        drawPixelImage(overlay, in: faceRect, rotatedHalfTurn: true)
    }
}

private func cropMinecraftRegion(in image: CGImage, x: Int, y: Int, width: Int, height: Int) -> CGImage? {
    image.cropping(to: CGRect(x: x, y: y, width: width, height: height))
}

private func drawPixelImage(_ image: CGImage, in rect: CGRect, rotatedHalfTurn: Bool = false) {
    let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    NSGraphicsContext.current?.imageInterpolation = .none
    guard rotatedHalfTurn, let context = NSGraphicsContext.current?.cgContext else {
        nsImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        return
    }

    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY)
    context.rotate(by: .pi)
    nsImage.draw(
        in: CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    context.restoreGState()
}

private func fill(_ rect: CGRect, _ hex: String, alpha: CGFloat = 1) {
    color(hex, alpha: alpha).setFill()
    NSBezierPath(rect: rect).fill()
}

private func color(_ hex: String, alpha: CGFloat) -> NSColor {
    let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard value.count == 6,
          let integer = Int(value, radix: 16)
    else {
        return NSColor.black.withAlphaComponent(alpha)
    }

    return NSColor(
        calibratedRed: CGFloat((integer >> 16) & 0xFF) / 255,
        green: CGFloat((integer >> 8) & 0xFF) / 255,
        blue: CGFloat(integer & 0xFF) / 255,
        alpha: alpha
    )
}

private func writeIfChanged(_ data: Data, to url: URL) throws {
    if let existingData = try? Data(contentsOf: url),
       existingData == data {
        return
    }

    try data.write(to: url, options: .atomic)
}

private enum LogoError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension URL {
    init(validating string: String) throws {
        guard let url = URL(string: string) else {
            throw LogoError.message("Invalid URL: \(string)")
        }

        self = url
    }
}

main()
