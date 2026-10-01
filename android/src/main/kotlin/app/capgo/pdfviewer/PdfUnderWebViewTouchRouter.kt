package app.capgo.pdfviewer

import android.graphics.RectF
import android.view.MotionEvent
import android.view.View
import android.webkit.WebView
import org.json.JSONArray

/**
 * Routes touches outside interactive HTML regions to the native PDF view behind the WebView.
 */
internal class PdfUnderWebViewTouchRouter(
    private val webView: WebView,
    private val pdfView: PdfViewerView,
) {
    private var installed = false
    private var overlayRectsCss: List<RectF> = emptyList()

    private val overlayProbeJs = """
        (function(){
          var sel = 'button, a, input, textarea, select, label, [data-capgo-pdf-interactive], .custom-toolbar, .custom-pdf-ui button';
          var nodes = document.querySelectorAll(sel);
          var out = [];
          for (var i = 0; i < nodes.length; i++) {
            var el = nodes[i];
            if (el.closest && el.closest('[hidden]')) continue;
            var style = window.getComputedStyle(el);
            if (style.pointerEvents === 'none' || style.visibility === 'hidden' || style.display === 'none') continue;
            var r = el.getBoundingClientRect();
            if (r.width < 1 || r.height < 1) continue;
            out.push({l:r.left,t:r.top,r:r.right,b:r.bottom});
          }
          return JSON.stringify(out);
        })();
    """.trimIndent()

    private val touchListener = View.OnTouchListener { _, event ->
        val density = webView.resources.displayMetrics.density
        val cssX = event.x / density
        val cssY = event.y / density
        if (isInOverlay(cssX, cssY)) {
            return@OnTouchListener false
        }
        val forwarded = MotionEvent.obtain(event)
        forwarded.offsetLocation(
            (webView.left - pdfView.left).toFloat(),
            (webView.top - pdfView.top).toFloat(),
        )
        val handled = pdfView.dispatchTouchEvent(forwarded)
        forwarded.recycle()
        handled
    }

    fun install() {
        if (installed) return
        webView.setOnTouchListener(touchListener)
        installed = true
        refreshOverlayRegions()
    }

    fun refreshOverlayRegions() {
        webView.evaluateJavascript(overlayProbeJs) { raw ->
            overlayRectsCss = parseOverlayRects(raw)
        }
    }

    fun release() {
        if (!installed) return
        webView.setOnTouchListener(null)
        installed = false
        overlayRectsCss = emptyList()
    }

    private fun isInOverlay(cssX: Float, cssY: Float): Boolean {
        for (rect in overlayRectsCss) {
            if (rect.contains(cssX, cssY)) {
                return true
            }
        }
        return false
    }

    private fun parseOverlayRects(raw: String?): List<RectF> {
        if (raw.isNullOrBlank() || raw == "null") return emptyList()
        return try {
            val unquoted = raw.trim().removeSurrounding("\"").replace("\\\"", "\"")
            val array = JSONArray(unquoted)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.getJSONObject(index)
                    add(
                        RectF(
                            item.getDouble("l").toFloat(),
                            item.getDouble("t").toFloat(),
                            item.getDouble("r").toFloat(),
                            item.getDouble("b").toFloat(),
                        ),
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
