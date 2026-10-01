import Foundation
import Capacitor
import PDFKit
import UIKit
import WebKit

struct PdfLayoutCss {
    var x: CGFloat?
    var y: CGFloat?
    var width: CGFloat?
    var height: CGFloat?
}

struct PdfOpenRequest {
    let document: PDFDocument
    let mode: String
    let elementId: String?
    let page: Int
    let scrollMode: String
    let nativeUi: Bool
    let layout: PdfLayoutCss
}

final class PdfViewerSession: NSObject, PDFViewDelegate {
    private weak var plugin: CAPPlugin?
    private weak var webView: WKWebView?
    private weak var hostController: UIViewController?

    private var pdfView: PDFView?
    private var containerView: UIView?
    private var fullscreenController: UIViewController?
    private var pageObserver: NSObjectProtocol?
    private var scaleObserver: NSObjectProtocol?
    private var baseScale: CGFloat = 1.0
    private var isInline = false
    private var isUnderWebView = false
    private var layout = PdfLayoutCss()
  private var webViewBackgroundColor: UIColor?
  private var webViewScrollBackgroundColor: UIColor?
  private var webViewSuperviewBackgroundColor: UIColor?
  private var webViewWasOpaque = true
  private var isHiddenLayer = false
  private var touchRouter: PdfWebViewTouchRouter?

    init(plugin: CAPPlugin, webView: WKWebView?, hostController: UIViewController?) {
        self.plugin = plugin
        self.webView = webView
        self.hostController = hostController
    }

    func present(request: PdfOpenRequest, call: CAPPluginCall) {
        dismiss(emitClose: false)

        let view = PDFView()
        view.autoScales = true
        view.displayDirection = .vertical
        view.displayMode = request.scrollMode == "single" ? .singlePage : .singlePageContinuous
        view.usePageViewController(request.scrollMode == "single", withViewOptions: nil)
        view.document = request.document
        view.delegate = self
        view.backgroundColor = request.mode == "underWebView" ? .clear : .systemBackground

        let index = PdfViewer.pageIndex(fromOneBased: request.page, pageCount: request.document.pageCount)
        if let target = request.document.page(at: index) {
            view.go(to: target)
        }

        pdfView = view
        isInline = request.mode == "inline"
        isUnderWebView = request.mode == "underWebView"
        layout = request.layout
        observePageChanges(view)
        observeZoomChanges(view)

        if request.mode == "inline" {
            guard let elementId = request.elementId else {
                call.reject(PdfViewerError.missingElementId.localizedDescription)
                return
            }
            measureElement(elementId) { [weak self] rect in
                guard let self else { return }
                guard let rect else {
                    let message = PdfViewerError.elementNotFound.localizedDescription
                    self.plugin?.notifyListeners("error", data: ["message": message])
                    call.reject(message)
                    return
                }
                self.attachInline(view: view, rect: rect)
                self.finishOpen(call: call, document: request.document, pdfView: view)
            }
        } else if isUnderWebView {
            attachUnderWebView(view: view)
            finishOpen(call: call, document: request.document, pdfView: view)
        } else {
            attachFullscreen(view: view, showNativeUi: request.nativeUi)
            finishOpen(call: call, document: request.document, pdfView: view)
        }
    }

    func goToPage(_ pageNumber: Int, call: CAPPluginCall) {
        guard let pdfView, let document = pdfView.document else {
            call.reject("No PDF is open")
            return
        }
        let index = PdfViewer.pageIndex(fromOneBased: pageNumber, pageCount: document.pageCount)
        guard let page = document.page(at: index) else {
            call.reject("Invalid page")
            return
        }
        pdfView.go(to: page)
        call.resolve()
    }

    func nextPage(call: CAPPluginCall) {
        guard let pdfView else {
            call.reject("No PDF is open")
            return
        }
        if pdfView.canGoToNextPage {
            pdfView.goToNextPage(nil)
        }
        call.resolve()
    }

    func previousPage(call: CAPPluginCall) {
        guard let pdfView else {
            call.reject("No PDF is open")
            return
        }
        if pdfView.canGoToPreviousPage {
            pdfView.goToPreviousPage(nil)
        }
        call.resolve()
    }

    func setZoom(_ scale: CGFloat, call: CAPPluginCall) {
        guard let pdfView else {
            call.reject("No PDF is open")
            return
        }
        pdfView.autoScales = false
        let applied = max(0.1, baseScale * scale)
        pdfView.scaleFactor = applied
        emitZoom(relativeScale: applied / max(baseScale, 0.01))
        call.resolve()
    }

    func getPageCount(call: CAPPluginCall) {
        guard let document = pdfView?.document else {
            call.reject("No PDF is open")
            return
        }
        call.resolve(["pageCount": document.pageCount])
    }

    func getCurrentPage(call: CAPPluginCall) {
        guard let pdfView, let document = pdfView.document else {
            call.reject("No PDF is open")
            return
        }
        let page: Int
        if let currentPage = pdfView.currentPage {
            page = PdfViewer.oneBasedPage(
                fromIndex: document.index(for: currentPage),
                pageCount: document.pageCount
            )
        } else {
            page = 1
        }
        call.resolve(["page": page])
    }

    func hide(call: CAPPluginCall) {
        guard containerView != nil else {
            call.reject("No PDF is open")
            return
        }
        guard isUnderWebView || isInline else {
            call.reject("hide is only supported in underWebView or inline mode")
            return
        }
        isHiddenLayer = true
        containerView?.isHidden = true
        touchRouter?.setRoutingEnabled(false)
        call.resolve()
    }

    func show(call: CAPPluginCall) {
        guard containerView != nil else {
            call.reject("No PDF is open")
            return
        }
        guard isUnderWebView || isInline else {
            call.reject("show is only supported in underWebView or inline mode")
            return
        }
        isHiddenLayer = false
        containerView?.isHidden = false
        touchRouter?.setRoutingEnabled(true)
        touchRouter?.refreshOverlayRegions()
        call.resolve()
    }

    func updateLayout(_ layout: PdfLayoutCss, call: CAPPluginCall) {
        guard isUnderWebView, let containerView else {
            call.reject("updateLayout is only supported in underWebView / toBack mode")
            return
        }
        self.layout = layout
        applyUnderWebViewFrame(to: containerView)
        touchRouter?.refreshOverlayRegions()
        call.resolve()
    }

    func dismiss(emitClose: Bool) {
        if let pageObserver {
            NotificationCenter.default.removeObserver(pageObserver)
            self.pageObserver = nil
        }
        if let scaleObserver {
            NotificationCenter.default.removeObserver(scaleObserver)
            self.scaleObserver = nil
        }
        pdfView?.delegate = nil
        pdfView?.document = nil
        pdfView?.removeFromSuperview()
        pdfView = nil

        if let fullscreenController {
            fullscreenController.dismiss(animated: true)
            self.fullscreenController = nil
        }
        if isUnderWebView {
            touchRouter?.uninstall()
            touchRouter = nil
            restoreWebViewVisualState()
        }
        if isInline || isUnderWebView {
            containerView?.removeFromSuperview()
        }
        containerView = nil
        isInline = false
        isUnderWebView = false
        isHiddenLayer = false

        if emitClose {
            plugin?.notifyListeners("close", data: [:])
        }
    }

    func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
        plugin?.notifyListeners("linkTap", data: ["url": url.absoluteString])
    }

    private func finishOpen(call: CAPPluginCall, document: PDFDocument, pdfView: PDFView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.baseScale = max(pdfView.scaleFactorForSizeToFit, 0.01)
            let current: Int
            if let currentPage = pdfView.currentPage {
                current = PdfViewer.oneBasedPage(
                    fromIndex: document.index(for: currentPage),
                    pageCount: document.pageCount
                )
            } else {
                current = 1
            }
            let payload: [String: Any] = [
                "pageCount": document.pageCount,
                "page": current
            ]
            self.plugin?.notifyListeners("load", data: payload)
            self.emitZoom(relativeScale: pdfView.scaleFactor / max(self.baseScale, 0.01))
            call.resolve(payload)
        }
    }

    private func attachFullscreen(view: PDFView, showNativeUi: Bool) {
        guard let hostController else { return }
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(view)

        var topAnchor = controller.view.safeAreaLayoutGuide.topAnchor
        if showNativeUi {
            let closeButton = UIButton(type: .system)
            closeButton.setTitle("Close", for: .normal)
            closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            controller.view.addSubview(closeButton)
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor, constant: 8),
                closeButton.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -16),
            ])
            topAnchor = closeButton.bottomAnchor
        }

        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor, constant: showNativeUi ? 8 : 0),
            view.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor),
        ])

        controller.modalPresentationStyle = .fullScreen
        hostController.present(controller, animated: true)
        fullscreenController = controller
        containerView = controller.view
    }

    private func attachInline(view: PDFView, rect: CGRect) {
        guard let webView else { return }
        let container = UIView(frame: rect)
        container.clipsToBounds = true
        view.frame = container.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(view)
        webView.superview?.addSubview(container)
        containerView = container
    }

    private func attachUnderWebView(view: PDFView) {
        guard let webView else { return }
        let container = UIView(frame: .zero)
        container.clipsToBounds = true
        container.backgroundColor = .clear
        view.frame = container.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(view)
        if let superview = webView.superview {
            superview.insertSubview(container, belowSubview: webView)
        } else {
            webView.addSubview(container)
            webView.sendSubviewToBack(container)
        }
        containerView = container
        applyUnderWebViewFrame(to: container)
        makeWebViewTransparent()
        let router = PdfWebViewTouchRouter()
        router.install(webView: webView, pdfTarget: container)
        touchRouter = router
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.touchRouter?.refreshOverlayRegions()
        }
        container.isHidden = isHiddenLayer
    }

    private func applyUnderWebViewFrame(to container: UIView) {
        guard let webView else { return }
        let bounds = webView.bounds
        let x = layout.x ?? 0
        let y = layout.y ?? 0
        let width = layout.width ?? bounds.width
        let height = layout.height ?? bounds.height
        let rect = CGRect(x: x, y: y, width: width, height: height)
        if container.superview === webView {
            container.frame = rect
        } else {
            container.frame = webView.convert(rect, to: webView.superview)
        }
    }

    private func makeWebViewTransparent() {
        guard let webView else { return }
        if webViewBackgroundColor == nil {
            webViewWasOpaque = webView.isOpaque
            webViewBackgroundColor = webView.backgroundColor
            webViewScrollBackgroundColor = webView.scrollView.backgroundColor
            webViewSuperviewBackgroundColor = webView.superview?.backgroundColor
        }
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.superview?.backgroundColor = .clear
    }

    private func restoreWebViewVisualState() {
        guard let webView else { return }
        webView.isOpaque = webViewWasOpaque
        if let saved = webViewBackgroundColor {
            webView.backgroundColor = saved
        } else {
            webView.backgroundColor = .white
        }
        if let savedScroll = webViewScrollBackgroundColor {
            webView.scrollView.backgroundColor = savedScroll
        }
        if let savedSuper = webViewSuperviewBackgroundColor {
            webView.superview?.backgroundColor = savedSuper
        }
        webViewBackgroundColor = nil
        webViewScrollBackgroundColor = nil
        webViewSuperviewBackgroundColor = nil
        webViewWasOpaque = true
    }

    private func measureElement(_ elementId: String, completion: @escaping (CGRect?) -> Void) {
        guard let webView else {
            completion(nil)
            return
        }
        let escaped = elementId
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let script = """
        (function(){
          var el = document.getElementById('\(escaped)');
          if (!el) return null;
          var r = el.getBoundingClientRect();
          return {x:r.left,y:r.top,width:r.width,height:r.height};
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            guard let dict = result as? [String: Any],
                  let originX = Self.cssNumber(dict["x"]),
                  let originY = Self.cssNumber(dict["y"]),
                  let width = Self.cssNumber(dict["width"]),
                  let height = Self.cssNumber(dict["height"])
            else {
                completion(nil)
                return
            }
            let cssRect = CGRect(x: originX, y: originY, width: width, height: height)
            let converted = webView.convert(cssRect, to: webView.superview)
            completion(converted)
        }
    }

    private static func cssNumber(_ value: Any?) -> CGFloat? {
        if let number = value as? CGFloat {
            return number
        }
        if let number = value as? Double {
            return CGFloat(number)
        }
        if let number = value as? NSNumber {
            return CGFloat(truncating: number)
        }
        return nil
    }

    private func observePageChanges(_ pdfView: PDFView) {
        if let pageObserver {
            NotificationCenter.default.removeObserver(pageObserver)
        }
        pageObserver = NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: pdfView,
            queue: .main
        ) { [weak self] _ in
            guard let self,
                  let document = pdfView.document,
                  let currentPage = pdfView.currentPage else { return }
            let page = PdfViewer.oneBasedPage(
                fromIndex: document.index(for: currentPage),
                pageCount: document.pageCount
            )
            self.plugin?.notifyListeners("pageChange", data: [
                "page": page,
                "pageCount": document.pageCount
            ])
        }
    }

    private func observeZoomChanges(_ pdfView: PDFView) {
        if let scaleObserver {
            NotificationCenter.default.removeObserver(scaleObserver)
        }
        scaleObserver = NotificationCenter.default.addObserver(
            forName: .PDFViewScaleChanged,
            object: pdfView,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let relative = pdfView.scaleFactor / max(self.baseScale, 0.01)
            self.emitZoom(relativeScale: relative)
        }
    }

    private func emitZoom(relativeScale: CGFloat) {
        plugin?.notifyListeners("zoomChange", data: [
            "scale": Double(relativeScale)
        ])
    }

    @objc private func closeTapped() {
        dismiss(emitClose: true)
    }
}
