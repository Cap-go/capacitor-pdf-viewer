package app.capgo.pdfviewer

import android.annotation.SuppressLint
import android.graphics.RectF
import android.view.MotionEvent
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebView
import org.json.JSONArray

/**
 * Routes touches outside interactive HTML regions to the native PDF view behind the WebView.
 */
internal class PdfUnderWebViewTouchRouter(
    private val webView: WebView,
    private val pdfView: PdfViewerView,
) {
    private enum class TouchRoute {
        UNDECIDED,
        WEB,
        PDF,
    }

    companion object {
        private const val INTERACTIVE_SELECTOR =
            "button, a, input, textarea, select, label, [data-capgo-pdf-interactive], .custom-toolbar, .custom-pdf-ui button"
    }

    private var installed = false
    private var routingEnabled = true
    private var activeRoute = TouchRoute.UNDECIDED
    private var overlayRectsCss: List<RectF> = emptyList()

    private val overlayProbeJs = """
        (function(){
          if (!window.__capgoPdfTouchOverlay || !window.__capgoPdfTouchOverlay.active) return '[]';
          var sel = '$INTERACTIVE_SELECTOR';
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

    private val overlayObserverJs = """
        (function(){
          if (window.__capgoPdfTouchOverlay && window.__capgoPdfTouchOverlay.installed) return;
          window.__capgoPdfTouchOverlay = window.__capgoPdfTouchOverlay || {};
          var state = window.__capgoPdfTouchOverlay;
          state.installed = true;
          state.active = true;
          var sel = '$INTERACTIVE_SELECTOR';
          var probe = function() {
            if (!state.active) return;
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
            var json = JSON.stringify(out);
            if (state.lastJson === json) return;
            state.lastJson = json;
            if (window.CapgoPdfTouchOverlay && window.CapgoPdfTouchOverlay.update) {
              window.CapgoPdfTouchOverlay.update(json);
            }
          };
          state.probe = probe;
          state.rafPending = false;
          state.scheduleProbe = function() {
            if (state.rafPending) return;
            state.rafPending = true;
            requestAnimationFrame(function() {
              state.rafPending = false;
              if (!state.active) return;
              probe();
            });
          };
          probe();
          try {
            state.resizeObserver = new ResizeObserver(state.scheduleProbe);
            state.resizeObserver.observe(document.documentElement);
            state.mutationObserver = new MutationObserver(probe);
            state.mutationObserver.observe(document.documentElement, {subtree:true, childList:true, attributes:true, attributeFilter:['class','style','hidden']});
            window.addEventListener('scroll', state.scheduleProbe, true);
            if (window.visualViewport) {
              window.visualViewport.addEventListener('resize', state.scheduleProbe);
              window.visualViewport.addEventListener('scroll', state.scheduleProbe);
            }
          } catch (e) {}
        })();
    """.trimIndent()

    private val overlayTeardownJs = """
        (function(){
          var state = window.__capgoPdfTouchOverlay;
          if (!state) return;
          state.active = false;
          try {
            if (state.resizeObserver) state.resizeObserver.disconnect();
            if (state.mutationObserver) state.mutationObserver.disconnect();
            if (state.scheduleProbe) {
              window.removeEventListener('scroll', state.scheduleProbe, true);
              if (window.visualViewport) {
                window.visualViewport.removeEventListener('resize', state.scheduleProbe);
                window.visualViewport.removeEventListener('scroll', state.scheduleProbe);
              }
            }
          } catch (e) {}
          delete window.__capgoPdfTouchOverlay;
        })();
    """.trimIndent()

    private val touchListener = View.OnTouchListener { _, event ->
        if (!routingEnabled) {
            return@OnTouchListener false
        }

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                refreshOverlayRegions()
                activeRoute = routeForPrimaryPointer(event)
            }
            MotionEvent.ACTION_POINTER_DOWN -> {
                // Keep the route chosen on ACTION_DOWN for the whole gesture.
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                activeRoute = TouchRoute.UNDECIDED
            }
        }

        when (activeRoute) {
            TouchRoute.WEB, TouchRoute.UNDECIDED -> return@OnTouchListener false
            TouchRoute.PDF -> {
                val transformed = transformToPdfView(event) ?: return@OnTouchListener false
                val handled = pdfView.dispatchTouchEvent(transformed)
                transformed.recycle()
                return@OnTouchListener handled
            }
        }
    }

    @SuppressLint("JavascriptInterface")
    fun install() {
        if (installed) return
        webView.addJavascriptInterface(OverlayBridge(), "CapgoPdfTouchOverlay")
        webView.setOnTouchListener(touchListener)
        installed = true
        refreshOverlayRegions()
        webView.evaluateJavascript(overlayObserverJs, null)
    }

    fun setRoutingEnabled(enabled: Boolean) {
        routingEnabled = enabled
        if (!enabled) {
            activeRoute = TouchRoute.UNDECIDED
        }
    }

    fun refreshOverlayRegions() {
        webView.evaluateJavascript(overlayProbeJs) { raw ->
            overlayRectsCss = parseOverlayRects(raw)
        }
    }

    fun release() {
        if (!installed) return
        webView.evaluateJavascript(overlayTeardownJs, null)
        webView.setOnTouchListener(null)
        webView.removeJavascriptInterface("CapgoPdfTouchOverlay")
        installed = false
        routingEnabled = true
        activeRoute = TouchRoute.UNDECIDED
        overlayRectsCss = emptyList()
    }

    private inner class OverlayBridge {
        @JavascriptInterface
        fun update(json: String) {
            webView.post {
                if (!installed) return@post
                overlayRectsCss = parseOverlayRects(json)
            }
        }
    }

    private fun routeForPrimaryPointer(event: MotionEvent): TouchRoute {
        val (cssX, cssY) = eventCssPoint(event)
        if (isInOverlay(cssX, cssY)) {
            return TouchRoute.WEB
        }
        return if (isMappedInsidePdfView(event)) {
            TouchRoute.PDF
        } else {
            TouchRoute.WEB
        }
    }

    private fun eventCssPoint(event: MotionEvent): Pair<Float, Float> {
        val density = webView.resources.displayMetrics.density
        val scale = webView.scale.coerceAtLeast(0.01f)
        return event.x / (density * scale) to event.y / (density * scale)
    }

    private fun isMappedInsidePdfView(event: MotionEvent): Boolean {
        val webLoc = IntArray(2)
        val pdfLoc = IntArray(2)
        webView.getLocationOnScreen(webLoc)
        pdfView.getLocationOnScreen(pdfLoc)
        val pdfX = event.x + (webLoc[0] - pdfLoc[0])
        val pdfY = event.y + (webLoc[1] - pdfLoc[1])
        return pdfX >= 0 && pdfY >= 0 && pdfX <= pdfView.width && pdfY <= pdfView.height
    }

    private fun transformToPdfView(event: MotionEvent): MotionEvent? {
        if (!isMappedInsidePdfView(event)) {
            return null
        }
        val webLoc = IntArray(2)
        val pdfLoc = IntArray(2)
        webView.getLocationOnScreen(webLoc)
        pdfView.getLocationOnScreen(pdfLoc)
        val dx = (webLoc[0] - pdfLoc[0]).toFloat()
        val dy = (webLoc[1] - pdfLoc[1]).toFloat()
        val copy = MotionEvent.obtain(event)
        copy.offsetLocation(dx, dy)
        return copy
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
