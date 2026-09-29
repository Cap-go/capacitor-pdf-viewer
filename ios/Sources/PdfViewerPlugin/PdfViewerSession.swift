import Foundation
import Capacitor
import PDFKit
import UIKit
import WebKit

struct PdfOpenRequest {
    let document: PDFDocument
    let mode: String
    let elementId: String?
    let page: Int
    let scrollMode: String
}

final class PdfViewerSession: NSObject, PDFViewDelegate {
    private weak var plugin: CAPPlugin?
    private weak var webView: WKWebView?
    private weak var hostController: UIViewController?

    private var pdfView: PDFView?
    private var containerView: UIView?
    private var fullscreenController: UIViewController?
    private var pageObserver: NSObjectProtocol?
    private var baseScale: CGFloat = 1.0
    private var isInline = false

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
        view.backgroundColor = .systemBackground

        let index = PdfViewer.pageIndex(fromOneBased: request.page, pageCount: request.document.pageCount)
        if let target = request.document.page(at: index) {
            view.go(to: target)
        }

        pdfView = view
        isInline = request.mode == "inline"
        observePageChanges(view)

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
        } else {
            attachFullscreen(view: view)
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

    func setZoom(_ scale: CGFloat, call: CAPPluginCall) {
        guard let pdfView else {
            call.reject("No PDF is open")
            return
        }
        pdfView.autoScales = false
        pdfView.scaleFactor = max(0.1, baseScale * scale)
        call.resolve()
    }

    func dismiss(emitClose: Bool) {
        if let pageObserver {
            NotificationCenter.default.removeObserver(pageObserver)
            self.pageObserver = nil
        }
        pdfView?.delegate = nil
        pdfView?.document = nil
        pdfView?.removeFromSuperview()
        pdfView = nil

        if let fullscreenController {
            fullscreenController.dismiss(animated: true)
            self.fullscreenController = nil
        }
        if isInline {
            containerView?.removeFromSuperview()
        }
        containerView = nil
        isInline = false

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
            self.baseScale = pdfView.scaleFactor
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
            call.resolve(payload)
        }
    }

    private func attachFullscreen(view: PDFView) {
        guard let hostController else { return }
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(view)

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(
                equalTo: controller.view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            closeButton.trailingAnchor.constraint(
                equalTo: controller.view.trailingAnchor,
                constant: -16
            ),
            view.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
            view.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor)
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

    @objc private func closeTapped() {
        dismiss(emitClose: true)
    }
}
