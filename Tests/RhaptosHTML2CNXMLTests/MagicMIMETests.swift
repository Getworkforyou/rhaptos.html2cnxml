import XCTest
@testable import RhaptosHTML2CNXML

final class MagicMIMETests: XCTestCase {

    func testPNGDetection() {
        // PNG signature
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let mimeType = MagicMIME.whatis(pngData)
        XCTAssertEqual(mimeType, "image/png")
    }

    func testJPEGDetection() {
        // JPEG signature
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let mimeType = MagicMIME.whatis(jpegData)
        XCTAssertEqual(mimeType, "image/jpeg")
    }

    func testGIFDetection() {
        // GIF89a signature
        let gifData = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])
        let mimeType = MagicMIME.whatis(gifData)
        XCTAssertEqual(mimeType, "image/gif")
    }

    func testUnknownData() {
        let unknownData = Data([0x00, 0x01, 0x02, 0x03])
        let mimeType = MagicMIME.whatis(unknownData)
        XCTAssertEqual(mimeType, "application/octet-stream")
    }

    func testExtensionForMIMEType() {
        XCTAssertEqual(MagicMIME.getExtension(for: "image/jpeg"), "jpg")
        XCTAssertEqual(MagicMIME.getExtension(for: "image/png"), "png")
        XCTAssertEqual(MagicMIME.getExtension(for: "image/gif"), "gif")
        XCTAssertNil(MagicMIME.getExtension(for: "unknown/type"))
    }
}
