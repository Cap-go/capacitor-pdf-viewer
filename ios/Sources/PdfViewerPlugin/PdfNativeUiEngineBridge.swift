import Foundation
import UIKit
import WebKit
import WebViewNativeUIEngine

final class PdfNativeUiEngineBridge {
    private var projection: NativeUIProjection?

    var isActive: Bool {
        projection != nil
    }

    func attach(
        webView: WKWebView,
        pluginJsName: String,
        elementId: String,
        containerProvider: @escaping () -> UIView?
    ) {
        detach()
        let selector = Self.projectionSelector(for: elementId)
        let listeners = NativeUIProjection.ReceiveListeners(
            update: ["pageChange", "zoomChange", "load"],
            projection: .init(
                native: ["shown"],
                web: ["transitionStarted"],
                none: ["hidden"]
            )
        )
        do {
            projection = try NativeUIProjection(
                webView: webView,
                plugin: pluginJsName,
                projectionSelector: selector,
                receiveListeners: listeners,
                view: { containerProvider() }
            )
        } catch {
            CAPLog.print("[PdfViewer] Native UI projection unavailable: \(error)")
            projection = nil
        }
    }

    func detach() {
        projection?.destroy()
        projection = nil
    }

    func receive(eventName: String, data: [String: Any]?) {
        projection?.receive(eventName, data: data)
    }

    private static func projectionSelector(for elementId: String) -> String {
        let escaped = elementId
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "#\(escaped)"
    }
}