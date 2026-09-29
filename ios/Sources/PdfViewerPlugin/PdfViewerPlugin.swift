import Foundation
import Capacitor
import PDFKit
import UIKit

@objc(PdfViewerPlugin)
public class PdfViewerPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "PdfViewerPlugin"
    public let jsName = "PdfViewer"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "open", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "close", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "goToPage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setZoom", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private let implementation = PdfViewer()
    private var session: PdfViewerSession?

    @objc func open(_ call: CAPPluginCall) {
        guard let source = call.getString("source"), !source.isEmpty else {
            call.reject("source is required")
            return
        }

        let sourceType = PdfViewer.inferSourceType(
            source: source,
            sourceType: call.getString("sourceType")
        )
        let mode = call.getString("mode") ?? "fullscreen"
        let elementId = call.getString("elementId")
        let password = call.getString("password")
        let page = call.getInt("page") ?? 1
        let scrollMode = call.getString("scrollMode") ?? "continuous"
        let headers = Self.stringMap(from: call.getObject("headers"))

        if mode == "inline", elementId == nil || elementId?.isEmpty == true {
            let message = PdfViewerError.missingElementId.localizedDescription
            notifyListeners("error", data: ["message": message])
            call.reject(message)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let document = try PdfViewer.loadDocument(
                    source: source,
                    sourceType: sourceType,
                    headers: headers,
                    password: password
                )
                DispatchQueue.main.async {
                    guard let self else { return }
                    let active = self.ensureSession()
                    let request = PdfOpenRequest(
                        document: document,
                        mode: mode,
                        elementId: elementId,
                        page: page,
                        scrollMode: scrollMode
                    )
                    active.present(request: request, call: call)
                }
            } catch {
                DispatchQueue.main.async {
                    let message = error.localizedDescription
                    self?.notifyListeners("error", data: ["message": message])
                    call.reject(message)
                }
            }
        }
    }

    @objc func close(_ call: CAPPluginCall) {
        DispatchQueue.main.async { [weak self] in
            self?.session?.dismiss(emitClose: true)
            call.resolve()
        }
    }

    @objc func goToPage(_ call: CAPPluginCall) {
        let pageNumber = call.getInt("page") ?? 1
        DispatchQueue.main.async { [weak self] in
            guard let session = self?.session else {
                call.reject("No PDF is open")
                return
            }
            session.goToPage(pageNumber, call: call)
        }
    }

    @objc func setZoom(_ call: CAPPluginCall) {
        let scale = CGFloat(call.getFloat("scale") ?? 1)
        DispatchQueue.main.async { [weak self] in
            guard let session = self?.session else {
                call.reject("No PDF is open")
                return
            }
            session.setZoom(scale, call: call)
        }
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve([
            "version": implementation.getPluginVersion()
        ])
    }

    private func ensureSession() -> PdfViewerSession {
        if let session {
            return session
        }
        let created = PdfViewerSession(
            plugin: self,
            webView: bridge?.webView,
            hostController: bridge?.viewController
        )
        session = created
        return created
    }

    private static func stringMap(from object: JSObject?) -> [String: String]? {
        guard let object else { return nil }
        var result: [String: String] = [:]
        for (key, value) in object {
            if let string = value as? String {
                result[key] = string
            }
        }
        return result.isEmpty ? nil : result
    }
}
