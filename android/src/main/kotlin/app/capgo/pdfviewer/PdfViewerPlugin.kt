package app.capgo.pdfviewer

import android.graphics.Color
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import io.legere.pdfiumandroid.PdfDocument
import org.json.JSONObject

@CapacitorPlugin(name = "PdfViewer")
class PdfViewerPlugin : Plugin() {

    private lateinit var implementation: PdfViewer
    private var document: PdfDocument? = null
    private var host: FrameLayout? = null
    private var viewer: PdfViewerView? = null
    private var pageCount = 0
    private var currentPage = 1
    private var underWebView = false
    private var layoutCss = LayoutCss()
    private var webViewVisualState: PdfToBackCompositor.SavedState? = null

    override fun load() {
        implementation = PdfViewer(context)
    }

    @PluginMethod
    fun open(call: PluginCall) {
        val source = call.getString("source")
        if (source.isNullOrBlank()) {
            call.reject("source is required")
            return
        }

        val sourceType = PdfViewerHelpers.inferSourceType(source, call.getString("sourceType"))
        val toBack = call.getBoolean("toBack", false) == true
        val modeRaw = call.getString("mode") ?: "fullscreen"
        val mode = if (toBack || modeRaw == "underWebView") "underWebView" else modeRaw
        val elementId = call.getString("elementId")
        val password = call.getString("password")
        val page = call.getInt("page") ?: 1
        val scrollMode = call.getString("scrollMode") ?: "continuous"
        val headers = stringMap(call.getObject("headers"))
        val nativeUi = call.getBoolean("nativeUi", mode != "underWebView") == true
        layoutCss = readLayout(call.getObject("layout"))

        if (mode == "inline" && elementId.isNullOrBlank()) {
            val message = "elementId is required when mode is inline"
            notifyListeners("error", JSObject().put("message", message))
            call.reject(message)
            return
        }

        Thread {
            try {
                val opened = implementation.openDocument(source, sourceType, headers, password)
                bridge.activity.runOnUiThread {
                    try {
                        present(opened, mode, elementId, page, scrollMode, nativeUi, call)
                    } catch (error: Exception) {
                        opened.close()
                        val message = error.message ?: "Failed to present PDF"
                        notifyListeners("error", JSObject().put("message", message))
                        call.reject(message)
                    }
                }
            } catch (error: Exception) {
                val message = error.message ?: "Failed to open PDF"
                bridge.activity.runOnUiThread {
                    notifyListeners("error", JSObject().put("message", message))
                    call.reject(message)
                }
            }
        }.start()
    }

    @PluginMethod
    fun close(call: PluginCall) {
        bridge.activity.runOnUiThread {
            dismiss(emitClose = true)
            call.resolve()
        }
    }

    @PluginMethod
    fun goToPage(call: PluginCall) {
        val page = call.getInt("page") ?: 1
        val active = viewer
        if (active == null) {
            call.reject("No PDF is open")
            return
        }
        bridge.activity.runOnUiThread {
            active.goToPage(page)
            call.resolve()
        }
    }

    @PluginMethod
    fun nextPage(call: PluginCall) {
        val active = viewer ?: run {
            call.reject("No PDF is open")
            return
        }
        bridge.activity.runOnUiThread {
            active.nextPage()
            call.resolve()
        }
    }

    @PluginMethod
    fun previousPage(call: PluginCall) {
        val active = viewer ?: run {
            call.reject("No PDF is open")
            return
        }
        bridge.activity.runOnUiThread {
            active.previousPage()
            call.resolve()
        }
    }

    @PluginMethod
    fun setZoom(call: PluginCall) {
        val scale = call.getFloat("scale") ?: 1f
        val active = viewer
        if (active == null) {
            call.reject("No PDF is open")
            return
        }
        bridge.activity.runOnUiThread {
            active.setZoom(scale)
            call.resolve()
        }
    }

    @PluginMethod
    fun getPageCount(call: PluginCall) {
        if (document == null || viewer == null) {
            call.reject("No PDF is open")
            return
        }
        call.resolve(JSObject().put("pageCount", pageCount))
    }

    @PluginMethod
    fun getCurrentPage(call: PluginCall) {
        val active = viewer
        if (active == null) {
            call.reject("No PDF is open")
            return
        }
        call.resolve(JSObject().put("page", active.currentOneBasedPage()))
    }

    @PluginMethod
    fun hide(call: PluginCall) {
        val container = host
        if (container == null) {
            call.reject("No PDF is open")
            return
        }
        bridge.activity.runOnUiThread {
            container.visibility = View.INVISIBLE
            call.resolve()
        }
    }

    @PluginMethod
    fun show(call: PluginCall) {
        val container = host
        if (container == null) {
            call.reject("No PDF is open")
            return
        }
        bridge.activity.runOnUiThread {
            container.visibility = View.VISIBLE
            call.resolve()
        }
    }

    @PluginMethod
    fun updateLayout(call: PluginCall) {
        if (!underWebView) {
            call.reject("updateLayout is only supported in underWebView / toBack mode")
            return
        }
        layoutCss = readLayout(call)
        val container = host
        if (container == null) {
            call.reject("No PDF is open")
            return
        }
        bridge.activity.runOnUiThread {
            applyUnderWebViewLayout(container)
            call.resolve()
        }
    }

    @PluginMethod
    fun getPluginVersion(call: PluginCall) {
        val ret = JSObject().put("version", implementation.getPluginVersion())
        call.resolve(ret)
    }

    private fun present(
        opened: PdfDocument,
        mode: String,
        elementId: String?,
        page: Int,
        scrollMode: String,
        nativeUi: Boolean,
        call: PluginCall,
    ) {
        dismiss(emitClose = false)
        document = opened
        pageCount = opened.getPageCount()
        currentPage = PdfViewerHelpers.oneBasedPage(
            PdfViewerHelpers.pageIndex(page, pageCount),
            pageCount,
        )
        underWebView = mode == "underWebView"

        val pdfView = PdfViewerView(context)
        pdfView.listener = object : PdfViewerView.Listener {
            override fun onPageChanged(page: Int, pageCount: Int) {
                currentPage = page
                notifyListeners(
                    "pageChange",
                    JSObject().put("page", page).put("pageCount", pageCount),
                )
            }

            override fun onLinkTapped(url: String) {
                notifyListeners("linkTap", JSObject().put("url", url))
            }

            override fun onZoomChanged(scale: Float) {
                notifyListeners("zoomChange", JSObject().put("scale", scale.toDouble()))
            }
        }

        val container = FrameLayout(context)
        container.setBackgroundColor(if (underWebView) Color.TRANSPARENT else Color.BLACK)
        container.addView(
            pdfView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        if (mode == "fullscreen" && nativeUi) {
            val close = ImageButton(context)
            close.setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            close.setBackgroundColor(Color.TRANSPARENT)
            close.setOnClickListener { dismiss(emitClose = true) }
            val lp = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            lp.topMargin = (12 * resources.displayMetrics.density).toInt()
            lp.marginEnd = (12 * resources.displayMetrics.density).toInt()
            lp.gravity = android.view.Gravity.TOP or android.view.Gravity.END
            container.addView(close, lp)
        }

        viewer = pdfView
        host = container

        if (mode == "inline") {
            measureElement(elementId!!) { rect ->
                if (rect == null) {
                    opened.close()
                    document = null
                    val message = "Inline element not found"
                    notifyListeners("error", JSObject().put("message", message))
                    call.reject(message)
                    return@measureElement
                }
                attachHost(container, rect, behindWebView = false)
                pdfView.bind(opened, scrollMode != "single", page)
                finishOpen(call)
            }
        } else if (underWebView) {
            applyUnderWebViewVisualState()
            attachHost(container, null, behindWebView = true)
            pdfView.bind(opened, scrollMode != "single", page)
            finishOpen(call)
        } else {
            attachHost(container, null, behindWebView = false)
            pdfView.bind(opened, scrollMode != "single", page)
            finishOpen(call)
        }
    }

    private fun finishOpen(call: PluginCall) {
        val payload = JSObject()
            .put("pageCount", pageCount)
            .put("page", currentPage)
        notifyListeners("load", payload)
        notifyListeners(
            "zoomChange",
            JSObject().put("scale", (viewer?.currentZoom() ?: 1f).toDouble()),
        )
        call.resolve(payload)
    }

    private fun attachHost(container: FrameLayout, rect: IntArray?, behindWebView: Boolean) {
        val webView = bridge.webView
        val parent = webView.parent as ViewGroup
        val params = if (rect == null) {
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        } else {
            FrameLayout.LayoutParams(rect[2], rect[3]).apply {
                leftMargin = rect[0]
                topMargin = rect[1]
            }
        }
        if (behindWebView) {
            val index = parent.indexOfChild(webView)
            parent.addView(container, index, params)
            applyUnderWebViewLayout(container)
        } else {
            parent.addView(container, params)
        }
    }

    private fun applyUnderWebViewLayout(container: FrameLayout) {
        val density = resources.displayMetrics.density
        val lp = (container.layoutParams as? ViewGroup.MarginLayoutParams)
            ?: FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        lp.width = layoutCss.width?.let { (it * density).toInt() } ?: ViewGroup.LayoutParams.MATCH_PARENT
        lp.height = layoutCss.height?.let { (it * density).toInt() } ?: ViewGroup.LayoutParams.MATCH_PARENT
        lp.leftMargin = ((layoutCss.x ?: 0.0) * density).toInt()
        lp.topMargin = ((layoutCss.y ?: 0.0) * density).toInt()
        container.layoutParams = lp
    }

    private fun applyUnderWebViewVisualState() {
        val webView = bridge.webView
        val parent = webView.parent as? ViewGroup
        if (webViewVisualState == null) {
            webViewVisualState = PdfToBackCompositor.capture(webView, parent)
        }
        PdfToBackCompositor.apply(webView, parent)
    }

    private fun measureElement(elementId: String, completion: (IntArray?) -> Unit) {
        val webView = bridge.webView
        val escaped = elementId.replace("\\", "\\\\").replace("'", "\\'")
        val js = """
            (function(){
              var el = document.getElementById('$escaped');
              if (!el) return null;
              var r = el.getBoundingClientRect();
              return JSON.stringify({x:r.left,y:r.top,width:r.width,height:r.height});
            })();
        """.trimIndent()
        webView.evaluateJavascript(js) { raw ->
            if (raw == null || raw == "null") {
                completion(null)
                return@evaluateJavascript
            }
            try {
                val unquoted = raw.trim().removeSurrounding("\"")
                    .replace("\\\"", "\"")
                    .replace("\\\\", "\\")
                val json = JSONObject(unquoted)
                val density = resources.displayMetrics.density
                val left = (json.getDouble("x") * density).toInt() + webView.left
                val top = (json.getDouble("y") * density).toInt() + webView.top
                val width = (json.getDouble("width") * density).toInt()
                val height = (json.getDouble("height") * density).toInt()
                completion(intArrayOf(left, top, width, height))
            } catch (_: Exception) {
                completion(null)
            }
        }
    }

    private fun dismiss(emitClose: Boolean) {
        viewer?.release()
        viewer = null
        host?.let { view ->
            (view.parent as? ViewGroup)?.removeView(view)
        }
        host = null
        document?.close()
        document = null
        underWebView = false
        if (webViewVisualState != null) {
            val webView = bridge.webView
            PdfToBackCompositor.restore(webView, webView.parent as? ViewGroup, webViewVisualState)
            webViewVisualState = null
        }
        if (emitClose) {
            notifyListeners("close", JSObject())
        }
    }

    private fun readLayout(call: PluginCall): LayoutCss {
        call.getObject("layout")?.let { return readLayout(it) }
        return LayoutCss(
            x = optionalDouble(call, "x"),
            y = optionalDouble(call, "y"),
            width = optionalDouble(call, "width"),
            height = optionalDouble(call, "height"),
        )
    }

    private fun readLayout(obj: JSObject?): LayoutCss {
        if (obj == null) return LayoutCss()
        return LayoutCss(
            x = optionalDouble(obj, "x"),
            y = optionalDouble(obj, "y"),
            width = optionalDouble(obj, "width"),
            height = optionalDouble(obj, "height"),
        )
    }

    private fun optionalDouble(obj: JSObject, key: String): Double? {
        return if (obj.has(key)) obj.getDouble(key) else null
    }

    private fun optionalDouble(call: PluginCall, key: String): Double? {
        return if (call.has(key)) call.getDouble(key) else null
    }

    private data class LayoutCss(
        val x: Double? = null,
        val y: Double? = null,
        val width: Double? = null,
        val height: Double? = null,
    )

    private fun stringMap(obj: JSObject?): Map<String, String>? {
        if (obj == null) return null
        val result = mutableMapOf<String, String>()
        val keys = obj.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = obj.getString(key) ?: continue
            result[key] = value
        }
        return result.ifEmpty { null }
    }

    private val resources get() = context.resources
}
