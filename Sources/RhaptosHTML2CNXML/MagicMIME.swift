import Foundation

/// MIME type detection for binary data
public struct MagicMIME {

    /// Signature patterns for common image formats
    private static let signatures: [(signature: [UInt8], mimeType: String)] = [
        // PNG signature
        ([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], "image/png"),

        // JPEG signatures
        ([0xFF, 0xD8, 0xFF, 0xE0], "image/jpeg"),
        ([0xFF, 0xD8, 0xFF, 0xE1], "image/jpeg"),
        ([0xFF, 0xD8, 0xFF, 0xE2], "image/jpeg"),
        ([0xFF, 0xD8, 0xFF, 0xE3], "image/jpeg"),
        ([0xFF, 0xD8, 0xFF, 0xE8], "image/jpeg"),

        // GIF signatures
        ([0x47, 0x49, 0x46, 0x38, 0x37, 0x61], "image/gif"), // GIF87a
        ([0x47, 0x49, 0x46, 0x38, 0x39, 0x61], "image/gif"), // GIF89a

        // PDF
        ([0x25, 0x50, 0x44, 0x46], "application/pdf"),

        // SVG (starts with '<' or '<?xml')
        ([0x3C, 0x3F, 0x78, 0x6D, 0x6C], "image/svg+xml"),
        ([0x3C, 0x73, 0x76, 0x67], "image/svg+xml"),
    ]

    /// Determines the MIME type of binary data by examining magic numbers
    /// - Parameter data: The binary data to analyze
    /// - Returns: The MIME type string, or "application/octet-stream" if unknown
    public static func whatis(_ data: Data) -> String {
        guard !data.isEmpty else {
            return "application/octet-stream"
        }

        let bytes = [UInt8](data.prefix(16))

        for (signature, mimeType) in signatures {
            if bytes.starts(with: signature) {
                return mimeType
            }
        }

        // Check for text content
        if isTextData(data) {
            return "text/plain"
        }

        return "application/octet-stream"
    }

    /// Determines the MIME type of a file by reading its contents
    /// - Parameter filename: Path to the file
    /// - Returns: The MIME type string, or nil if file cannot be read
    public static func file(_ filename: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filename)) else {
            return nil
        }
        return whatis(data)
    }

    /// Checks if data appears to be text
    private static func isTextData(_ data: Data) -> Bool {
        let sample = data.prefix(512)
        let bytes = [UInt8](sample)

        // Check for common text characters
        let textCharCount = bytes.filter { byte in
            // Printable ASCII, newlines, tabs
            (byte >= 0x20 && byte <= 0x7E) || byte == 0x09 || byte == 0x0A || byte == 0x0D
        }.count

        // If more than 95% are text characters, consider it text
        return Double(textCharCount) / Double(bytes.count) > 0.95
    }

    /// Gets the file extension for a MIME type
    /// - Parameter mimeType: The MIME type string
    /// - Returns: The file extension (without dot) or nil if unknown
    public static func getExtension(for mimeType: String) -> String? {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "image/svg+xml": return "svg"
        case "application/pdf": return "pdf"
        case "text/plain": return "txt"
        case "text/html": return "html"
        default: return nil
        }
    }
}
