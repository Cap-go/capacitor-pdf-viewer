import UIKit
import WebKit

final class PdfWebViewTouchRouterView: UIView {
    weak var webView: WKWebView?
    weak var pdfTarget: UIView?
    var overlayRects: [CGRect] = []
    var isRoutingEnabled = true
    /// Locked for the current touch sequence (first finger down through all fingers up).
    fileprivate var gestureRoutesToPdf: Bool?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let webView else { return nil }
        let pointInWeb = convert(point, to: webView)

        if !isRoutingEnabled {
            gestureRoutesToPdf = nil
            return webView.hitTest(pointInWeb, with: event)
        }

        syncGestureLock(with: event)

        if let locked = gestureRoutesToPdf {
            return hitTestWithRoute(locked, point: point, pointInWeb: pointInWeb, event: event)
        }

        let routesToPdf = shouldRouteToPdf(point: point, pointInWeb: pointInWeb, event: event)
        gestureRoutesToPdf = routesToPdf
        return hitTestWithRoute(routesToPdf, point: point, pointInWeb: pointInWeb, event: event)
    }

    private func syncGestureLock(with event: UIEvent?) {
        guard let touches = event?.allTouches else { return }
        let active = touches.filter { $0.phase != .ended && $0.phase != .cancelled }
        if active.isEmpty {
            gestureRoutesToPdf = nil
            return
        }
        if active.allSatisfy({ $0.phase == .began }) {
            gestureRoutesToPdf = nil
        }
    }

    private func shouldRouteToPdf(point: CGPoint, pointInWeb: CGPoint, event: UIEvent?) -> Bool {
        guard let webView else { return false }

        if let webHit = webView.hitTest(pointInWeb, with: event),
           webHit !== webView,
           webHit !== webView.scrollView
        {
            return false
        }

        if overlayRects.contains(where: { $0.contains(pointInWeb) }) {
            return false
        }

        guard let pdfTarget else { return false }
        let pointInPdf = convert(point, to: pdfTarget)
        return pdfTarget.bounds.contains(pointInPdf)
    }

    private func hitTestWithRoute(
        _ routesToPdf: Bool,
        point: CGPoint,
        pointInWeb: CGPoint,
        event: UIEvent?
    ) -> UIView? {
        guard let webView else { return nil }
        if !routesToPdf {
            return webView.hitTest(pointInWeb, with: event)
        }
        guard let pdfTarget else { return webView.hitTest(pointInWeb, with: event) }
        let pointInPdf = convert(point, to: pdfTarget)
        guard pdfTarget.bounds.contains(pointInPdf) else {
            return webView.hitTest(pointInWeb, with: event)
        }
        return pdfTarget.hitTest(pointInPdf, with: event)
    }
}

final class PdfWebViewTouchRouter: NSObject, WKScriptMessageHandler {
    private weak var webView: WKWebView?
    private weak var pdfTarget: UIView?
    private var wrapperView: PdfWebViewTouchRouterView?
    private let messageHandlerName = "capgoPdfTouchOverlay"

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

    private let overlayObserverJs = """
    (function(){
      if (window.__capgoPdfTouchObserverInstalled) return;
      window.__capgoPdfTouchObserverInstalled = true;
      var probe = function() {
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
        var json = JSON.stringify(out);
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.capgoPdfTouchOverlay) {
          window.webkit.messageHandlers.capgoPdfTouchOverlay.postMessage(json);
        }
      };
      probe();
      try {
        new ResizeObserver(probe).observe(document.documentElement);
        new MutationObserver(probe).observe(document.documentElement, {subtree:true, childList:true, attributes:true, attributeFilter:['class','style','hidden']});
      } catch (e) {}
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

        webView.configuration.userContentController.add(self, name: messageHandlerName)
        refreshOverlayRegions()
        webView.evaluateJavaScript(overlayObserverJs, completionHandler: nil)
    }

    func setRoutingEnabled(_ enabled: Bool) {
        wrapperView?.isRoutingEnabled = enabled
        if !enabled {
            wrapperView?.gestureRoutesToPdf = nil
        }
    }

    func refreshOverlayRegions() {
        guard let webView, let wrapperView else { return }
        webView.evaluateJavaScript(overlayProbeJs) { [weak wrapperView] result, _ in
            wrapperView?.overlayRects = Self.parseOverlayRects(from: result)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == messageHandlerName,
              let wrapperView
        else {
            return
        }
        wrapperView.overlayRects = Self.parseOverlayRects(from: message.body)
    }

    func uninstall() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
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

    private static func parseOverlayRects(from value: Any?) -> [CGRect] {
        let json: String?
        if let string = value as? String {
            json = string
        } else if let data = try? JSONSerialization.data(withJSONObject: value),
                  let encoded = String(data: data, encoding: .utf8)
        {
            json = encoded
        } else {
            json = nil
        }
        guard let json,
              let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]]
        else {
            return []
        }
        return array.compactMap { item in
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
