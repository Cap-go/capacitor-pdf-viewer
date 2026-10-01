import UIKit
import WebKit

final class PdfWebViewTouchRouterView: UIView {
    weak var webView: WKWebView?
    weak var pdfTarget: UIView?
    var overlayRects: [CGRect] = []

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let webView else { return nil }
        let pointInWeb = convert(point, to: webView)
        if let webHit = webView.hitTest(pointInWeb, with: event),
           webHit !== webView,
           webHit !== webView.scrollView
        {
            return webHit
        }
        if overlayRects.contains(where: { $0.contains(pointInWeb) }) {
            return webView.hitTest(pointInWeb, with: event)
        }
        guard let pdfTarget else { return nil }
        let pointInPdf = convert(point, to: pdfTarget)
        return pdfTarget.hitTest(pointInPdf, with: event)
    }
}

final class PdfWebViewTouchRouter {
    private weak var webView: WKWebView?
    private weak var pdfTarget: UIView?
    private var wrapperView: PdfWebViewTouchRouterView?

    private let overlayProbeJs = """
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
    """

    func install(webView: WKWebView, pdfTarget: UIView) {
        guard wrapperView == nil, let superview = webView.superview else { return }
        self.webView = webView
        self.pdfTarget = pdfTarget
        let index = superview.subviews.firstIndex(of: webView) ?? superview.subviews.count
        let wrapper = PdfWebViewTouchRouterView(frame: webView.frame)
        wrapper.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wrapper.webView = webView
        wrapper.pdfTarget = pdfTarget
        webView.removeFromSuperview()
        superview.insertSubview(wrapper, at: index)
        webView.frame = wrapper.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wrapper.addSubview(webView)
        wrapperView = wrapper
        refreshOverlayRegions()
    }

    func refreshOverlayRegions() {
        guard let webView, let wrapperView else { return }
        webView.evaluateJavaScript(overlayProbeJs) { result, _ in
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]]
            else {
                wrapperView.overlayRects = []
                return
            }
            wrapperView.overlayRects = array.compactMap { item in
                guard let left = item["l"],
                      let top = item["t"],
                      let right = item["r"],
                      let bottom = item["b"]
                else {
                    return nil
                }
                return CGRect(x: left, y: top, width: right - left, height: bottom - top)
            }
        }
    }

    func uninstall() {
        guard let wrapperView, let webView, let superview = wrapperView.superview else {
            self.wrapperView = nil
            self.webView = nil
            self.pdfTarget = nil
            return
        }
        let frame = wrapperView.frame
        let index = superview.subviews.firstIndex(of: wrapperView) ?? superview.subviews.count
        webView.removeFromSuperview()
        wrapperView.removeFromSuperview()
        superview.insertSubview(webView, at: index)
        webView.frame = frame
        self.wrapperView = nil
        self.webView = nil
        self.pdfTarget = nil
    }
}
