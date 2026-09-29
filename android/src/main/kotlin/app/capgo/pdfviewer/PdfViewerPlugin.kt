package app.capgo.pdfviewer

import android.graphics.Color
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
        val mode = call.getString("mode") ?: "fullscreen"
        val elementId = call.getString("elementId")
        val password = call.getString("password")
        val page = call.getInt("page") ?: 1
        val scrollMode = call.getString("scrollMode") ?: "continuous"
        val headers = stringMap(call.getObject("headers"))

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
                        present(opened, mode, elementId, page, scrollMode, call)
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
        call: PluginCall,
    ) {
        dismiss(emitClose = false)
        document = opened
        pageCount = opened.getPageCount()
        currentPage = PdfViewerHelpers.oneBasedPage(
            PdfViewerHelpers.pageIndex(page, pageCount),
            pageCount,
        )

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
        }

        val container = FrameLayout(context)
        container.setBackgroundColor(Color.BLACK)
        container.addView(
            pdfView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        if (mode != "inline") {
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
                attachHost(container, rect)
                pdfView.bind(opened, scrollMode != "single", page)
                finishOpen(call)
            }
        } else {
            attachHost(container, null)
            pdfView.bind(opened, scrollMode != "single", page)
            finishOpen(call)
        }
    }

    private fun finishOpen(call: PluginCall) {
        val payload = JSObject()
            .put("pageCount", pageCount)
            .put("page", currentPage)
        notifyListeners("load", payload)
        call.resolve(payload)
    }

    private fun attachHost(container: FrameLayout, rect: IntArray?) {
        val parent = bridge.webView.parent as ViewGroup
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
        parent.addView(container, params)
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
        if (emitClose) {
            notifyListeners("close", JSObject())
        }
    }

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
