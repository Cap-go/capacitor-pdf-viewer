package app.capgo.pdfviewer

import org.junit.Assert.assertFalse
import org.junit.Test

class PdfUnderWebViewTouchRouterTest {
    @Test
    fun overlayProbeJs_doesNotGateOnOverlayActiveState() {
        assertFalse(
            PdfUnderWebViewTouchRouter.overlayProbeScriptForTests.contains(
                "__capgoPdfTouchOverlay.active",
            ),
        )
    }
}
