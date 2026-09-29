package app.capgo.pdfviewer

import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin

@CapacitorPlugin(name = "PdfViewer")
class PdfViewerPlugin : Plugin() {

    private val implementation = PdfViewer()

    @PluginMethod
    fun echo(call: PluginCall) {
        val value = call.getString("value") ?: ""

        val ret = JSObject().apply {
            put("value", implementation.echo(value))
        }
        call.resolve(ret)
    }

    @PluginMethod
    fun getPluginVersion(call: PluginCall) {
        val ret = JSObject().apply {
            put("version", implementation.getPluginVersion())
        }
        call.resolve(ret)
    }
}
