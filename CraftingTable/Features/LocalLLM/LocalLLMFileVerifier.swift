import CryptoKit
import Foundation

enum LocalLLMFileVerifier {
    static func sha256HexDigest(for fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()

        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: 1024 * 1024)
            guard data.isEmpty == false else {
                return false
            }

            hasher.update(data: data)
            return true
        }) {}

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func verify(fileURL: URL, expectedSHA256: String) throws -> Bool {
        try sha256HexDigest(for: fileURL).caseInsensitiveCompare(expectedSHA256) == .orderedSame
    }
}
