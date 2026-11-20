import XCTest
@testable import PdfViewerPlugin

class PdfViewerTests: XCTestCase {
    func testInferSourceTypeUrl() {
        XCTAssertEqual(
            PdfViewer.inferSourceType(source: "https://example.com/a.pdf", sourceType: nil),
            "url"
        )
    }

    func testInferSourceTypeBase64DataUri() {
        XCTAssertEqual(
            PdfViewer.inferSourceType(source: "data:application/pdf;base64,AAA", sourceType: nil),
            "base64"
        )
    }

    func testInferSourceTypeExplicitWins() {
        XCTAssertEqual(
            PdfViewer.inferSourceType(source: "https://example.com/a.pdf", sourceType: "file"),
            "file"
        )
    }

    func testInferSourceTypePath() {
        XCTAssertEqual(
            PdfViewer.inferSourceType(source: "/tmp/doc.pdf", sourceType: nil),
            "file"
        )
    }

    func testPageIndexClamping() {
        XCTAssertEqual(PdfViewer.pageIndex(fromOneBased: 1, pageCount: 5), 0)
        XCTAssertEqual(PdfViewer.pageIndex(fromOneBased: 5, pageCount: 5), 4)
        XCTAssertEqual(PdfViewer.pageIndex(fromOneBased: 0, pageCount: 5), 0)
        XCTAssertEqual(PdfViewer.pageIndex(fromOneBased: 99, pageCount: 5), 4)
    }

    func testOneBasedPage() {
        XCTAssertEqual(PdfViewer.oneBasedPage(fromIndex: 0, pageCount: 3), 1)
        XCTAssertEqual(PdfViewer.oneBasedPage(fromIndex: 2, pageCount: 3), 3)
    }

    func testLayoutCssPositiveDimension() {
        XCTAssertNil(PdfLayoutCss.positiveDimension(nil))
        XCTAssertNil(PdfLayoutCss.positiveDimension(0))
        XCTAssertNil(PdfLayoutCss.positiveDimension(-10))
        XCTAssertEqual(PdfLayoutCss.positiveDimension(320), 320)
    }

    func testGetPluginVersion() {
        let implementation = PdfViewer()
        XCTAssertEqual(implementation.getPluginVersion(), "native")
    }

    func testColorFromHexRRGGBB() {
        let color = PdfViewer.color(fromHex: "#1a2b3c")
        XCTAssertNotNil(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssertEqual(red, 26 / 255, accuracy: 0.01)
        XCTAssertEqual(green, 43 / 255, accuracy: 0.01)
        XCTAssertEqual(blue, 60 / 255, accuracy: 0.01)
        XCTAssertEqual(alpha, 1, accuracy: 0.01)
    }

    func testColorFromHexInvalid() {
        XCTAssertNil(PdfViewer.color(fromHex: "nope"))
        XCTAssertNil(PdfViewer.color(fromHex: "#12345"))
    }
}
