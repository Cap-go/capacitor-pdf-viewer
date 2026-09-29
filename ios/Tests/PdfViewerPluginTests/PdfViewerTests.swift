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

    func testGetPluginVersion() {
        let implementation = PdfViewer()
        XCTAssertEqual(implementation.getPluginVersion(), "native")
    }
}
