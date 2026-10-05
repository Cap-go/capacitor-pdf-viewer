package app.capgo.pdfviewer

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.view.View
import android.webkit.WebView

/**
 * Policy for Android `toBack` / underWebView compositing behind the Capacitor WebView.
 */
internal object PdfToBackCompositor {
    fun apply(webView: WebView, webViewParent: android.view.ViewGroup?) {
        if (webViewParent != null) {
            webViewParent.background = ColorDrawable(Color.TRANSPARENT)
            webViewParent.requestTransparentRegion(webView)
        }
        webView.background = ColorDrawable(Color.TRANSPARENT)
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null)
    }

    data class SavedState(
        val webViewBackground: Drawable?,
        val parentBackground: Drawable?,
        val layerType: Int,
    )

    fun capture(webView: WebView, webViewParent: android.view.ViewGroup?): SavedState {
        return SavedState(
            webViewBackground = webView.background,
            parentBackground = webViewParent?.background,
            layerType = webView.layerType,
        )
    }

    fun restore(webView: WebView, webViewParent: android.view.ViewGroup?, saved: SavedState?) {
        if (saved == null) return
        webView.background = saved.webViewBackground
        webView.setLayerType(saved.layerType, null)
        webViewParent?.background = saved.parentBackground
    }
}
