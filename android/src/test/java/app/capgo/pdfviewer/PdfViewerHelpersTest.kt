package app.capgo.pdfviewer

import org.junit.Assert.assertEquals
import org.junit.Test

class PdfViewerHelpersTest {
    @Test
    fun inferSourceType_url() {
        assertEquals("url", PdfViewerHelpers.inferSourceType("https://example.com/a.pdf", null))
    }

    @Test
    fun inferSourceType_base64DataUri() {
        assertEquals(
            "base64",
            PdfViewerHelpers.inferSourceType("data:application/pdf;base64,AAA", null),
        )
    }

    @Test
    fun inferSourceType_explicitWins() {
        assertEquals("file", PdfViewerHelpers.inferSourceType("https://example.com/a.pdf", "file"))
    }

    @Test
    fun inferSourceType_path() {
        assertEquals("file", PdfViewerHelpers.inferSourceType("/tmp/doc.pdf", null))
    }

    @Test
    fun pageIndex_clamping() {
        assertEquals(0, PdfViewerHelpers.pageIndex(1, 5))
        assertEquals(4, PdfViewerHelpers.pageIndex(5, 5))
        assertEquals(0, PdfViewerHelpers.pageIndex(0, 5))
        assertEquals(4, PdfViewerHelpers.pageIndex(99, 5))
    }

    @Test
    fun oneBasedPage() {
        assertEquals(1, PdfViewerHelpers.oneBasedPage(0, 3))
        assertEquals(3, PdfViewerHelpers.oneBasedPage(2, 3))
    }
}
