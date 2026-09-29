import XCTest
@testable import PdfViewerPlugin

class PdfViewerTests: XCTestCase {
    func testEcho() {
        let implementation = PdfViewer()
        let value = "Hello, World!"
        let result = implementation.echo(value)

        XCTAssertEqual(value, result)
    }

    func testGetPluginVersion() {
        let implementation = PdfViewer()
        let result = implementation.getPluginVersion()

        XCTAssertEqual("native", result)
    }
}
