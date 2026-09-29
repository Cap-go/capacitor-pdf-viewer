package app.capgo.pdfviewer

import com.getcapacitor.Logger

class PdfViewer {

    fun echo(value: String): String {
        Logger.info("Echo", value)

        return value
    }

    fun getPluginVersion(): String {
        return "native"
    }
}
