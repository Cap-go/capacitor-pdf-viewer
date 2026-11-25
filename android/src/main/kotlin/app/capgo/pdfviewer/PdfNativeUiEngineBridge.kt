package app.capgo.pdfviewer

import android.util.Log
import android.view.View
import android.view.Window
import android.webkit.WebView
import com.getcapacitor.JSObject
import io.github.webview_native_ui.engine.NativeUIProjection

internal class PdfNativeUiEngineBridge(
    private val pluginId: String,
) {
    private var projection: NativeUIProjection? = null
    private var channelInstalled = false

    val isActive: Boolean
        get() = projection != null

    private fun ensureChannel(webView: WebView) {
        if (channelInstalled) {
            return
        }
        runCatching { NativeUIProjection.install(webView) }.onFailure {
            Log.e(TAG, "Native UI channel install failed", it)
        }
        channelInstalled = true
    }

    fun attach(
        window: Window,
        webView: WebView,
        elementId: String,
        viewProvider: () -> View?,
    ): Boolean {
        detach()
        ensureChannel(webView)
        val selector = projectionSelectorForElementId(elementId)
        projection =
            runCatching {
                NativeUIProjection(
                    window = window,
                    webView = webView,
                    plugin = pluginId,
                    projectionSelector = selector,
                    receiveListeners =
                        NativeUIProjection.ReceiveListeners(
                            update = listOf("pageChange", "zoomChange", "load"),
                            projection =
                                NativeUIProjection.ReceiveListeners.Projection(
                                    native = listOf("shown"),
                                    web = listOf("transitionStarted"),
                                    none = listOf("hidden"),
                                ),
                        ),
                    view = viewProvider,
                )
            }.onFailure {
                Log.e(TAG, "Native UI projection unavailable", it)
            }.getOrNull()
        return projection != null
    }

    fun detach() {
        projection?.close()
        projection = null
    }

    fun receive(eventName: String, data: JSObject?) {
        projection?.receive(eventName, data ?: JSObject())
    }

    private fun projectionSelectorForElementId(elementId: String): String {
        val escaped =
            elementId
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
        return "[id=\"$escaped\"]"
    }

    companion object {
        private const val TAG = "PdfNativeUiEngine"
    }
}