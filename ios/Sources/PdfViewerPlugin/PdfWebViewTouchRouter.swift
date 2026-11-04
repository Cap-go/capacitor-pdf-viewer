import UIKit
import WebKit

private final class PdfWebViewReloadNavigationDelegate: NSObject, WKNavigationDelegate {
    weak var forward: WKNavigationDelegate?
    var onReloadFinish: (() -> Void)?
    private var pendingReload = false

    private static let navigationActionPolicySelector: Selector = NSSelectorFromString(
        "webView:decidePolicyForNavigationAction:decisionHandler:"
    )

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        pendingReload = navigationAction.navigationType == .reload
        if let forward, forward.responds(to: Self.navigationActionPolicySelector) {
            forward.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if pendingReload {
            onReloadFinish?()
            pendingReload = false
        }
        forward?.webView?(webView, didFinish: navigation)
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (forward?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if forward?.responds(to: aSelector) == true {
            return forward
        }
        return super.forwardingTarget(for: aSelector)
    }
}

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
        // New single-finger gesture only; do not reset when a second finger joins (both .began).
        if active.count == 1, active.first?.phase == .began {
            gestureRoutesToPdf = nil
        }
    }

    private func shouldRouteToPdf(point: CGPoint, pointInWeb: CGPoint, event _: UIEvent?) -> Bool {
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
        return pdfTarget.hitTest(pointInPdf, with: event) ?? pdfTarget
    }
}

private final class PdfTouchOverlayScriptHandler: NSObject, WKScriptMessageHandler {
    weak var router: PdfWebViewTouchRouter?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        router?.handleOverlayMessage(message)
    }
}

final class PdfWebViewTouchRouter: NSObject {
    private static let interactiveSelector =
        "button, a, input, textarea, select, label, [data-capgo-pdf-interactive], .custom-toolbar, .custom-pdf-ui button"

    private weak var webView: WKWebView?
    private weak var pdfTarget: UIView?
    private var wrapperView: PdfWebViewTouchRouterView?
    private var overlayMessageHandler: PdfTouchOverlayScriptHandler?
    private var reloadNavigationDelegate: PdfWebViewReloadNavigationDelegate?
    private let messageHandlerName = "capgoPdfTouchOverlay"

    private var overlayProbeJs: String {
        """
        (function(){
          var sel = '\(Self.interactiveSelector)';
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
    }

    private var overlayObserverJs: String {
        """
        (function(){
          if (window.__capgoPdfTouchOverlay && window.__capgoPdfTouchOverlay.installed) return;
          window.__capgoPdfTouchOverlay = window.__capgoPdfTouchOverlay || {};
          var state = window.__capgoPdfTouchOverlay;
          state.installed = true;
          state.active = true;
          var sel = '\(Self.interactiveSelector)';
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
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.capgoPdfTouchOverlay) {
              window.webkit.messageHandlers.capgoPdfTouchOverlay.postMessage(json);
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
            state.mutationObserver = new MutationObserver(state.scheduleProbe);
            state.mutationObserver.observe(document.documentElement, {subtree:true, childList:true, attributes:true, attributeFilter:['class','style','hidden']});
            window.addEventListener('scroll', state.scheduleProbe, true);
            if (window.visualViewport) {
              window.visualViewport.addEventListener('resize', state.scheduleProbe);
              window.visualViewport.addEventListener('scroll', state.scheduleProbe);
            }
          } catch (e) {}
        })();
        """
    }

    private let overlayTeardownJs = """
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

        let handler = PdfTouchOverlayScriptHandler()
        handler.router = self
        overlayMessageHandler = handler
        webView.configuration.userContentController.add(handler, name: messageHandlerName)
        let reloadDelegate = PdfWebViewReloadNavigationDelegate()
        reloadDelegate.forward = webView.navigationDelegate
        reloadDelegate.onReloadFinish = { [weak self] in
            self?.refreshOverlayRegions()
        }
        reloadNavigationDelegate = reloadDelegate
        webView.navigationDelegate = reloadDelegate
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
        webView.evaluateJavaScript(overlayObserverJs, completionHandler: nil)
        webView.evaluateJavaScript(overlayProbeJs) { [weak wrapperView] result, _ in
            wrapperView?.overlayRects = Self.parseOverlayRects(from: result)
        }
    }

    fileprivate func handleOverlayMessage(_ message: WKScriptMessage) {
        guard message.name == messageHandlerName,
              let wrapperView
        else {
            return
        }
        wrapperView.overlayRects = Self.parseOverlayRects(from: message.body)
    }

    func uninstall() {
        if let webView {
            if let reloadNavigationDelegate {
                webView.navigationDelegate = reloadNavigationDelegate.forward
            }
            reloadNavigationDelegate = nil
            webView.evaluateJavaScript(overlayTeardownJs, completionHandler: nil)
            webView.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
        }
        overlayMessageHandler?.router = nil
        overlayMessageHandler = nil

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
        guard let json = value as? String,
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
