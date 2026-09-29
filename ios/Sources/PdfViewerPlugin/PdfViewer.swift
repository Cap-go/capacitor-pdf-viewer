import Foundation
import PDFKit
import UIKit

@objc public class PdfViewer: NSObject {
    @objc public func getPluginVersion() -> String {
        return "native"
    }

    /// Infer source type when the caller omits `sourceType`.
    public static func inferSourceType(source: String, sourceType: String?) -> String {
        if let sourceType, !sourceType.isEmpty {
            return sourceType
        }
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("data:") {
            return "base64"
        }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return "url"
        }
        if !trimmed.contains("://") && Self.looksLikeBase64(trimmed) {
            return "base64"
        }
        return "file"
    }

    /// Convert a 1-based page number to a 0-based PDFKit page index.
    public static func pageIndex(fromOneBased page: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 0 }
        let clamped = max(1, min(page, pageCount))
        return clamped - 1
    }

    /// Convert a 0-based PDFKit page index to a 1-based page number.
    public static func oneBasedPage(fromIndex index: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 1 }
        let clamped = max(0, min(index, pageCount - 1))
        return clamped + 1
    }

    private static func looksLikeBase64(_ value: String) -> Bool {
        let compact = value.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        guard compact.count > 32 else { return false }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        return compact.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    public static func loadDocument(
        source: String,
        sourceType: String,
        headers: [String: String]?,
        password: String?
    ) throws -> PDFDocument {
        let data: Data
        switch sourceType {
        case "url":
            data = try Self.download(urlString: source, headers: headers)
        case "base64":
            data = try Self.decodeBase64(source)
        default:
            data = try Self.readFile(source)
        }

        guard let document = PDFDocument(data: data) else {
            throw PdfViewerError.invalidDocument
        }
        if document.isLocked {
            let unlocked = document.unlock(withPassword: password ?? "")
            if !unlocked || document.isLocked {
                throw PdfViewerError.passwordRequired
            }
        }
        return document
    }

    private static func download(urlString: String, headers: [String: String]?) throws -> Data {
        guard let url = URL(string: urlString) else {
            throw PdfViewerError.invalidSource
        }
        var request = URLRequest(url: url)
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultError: Error?
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                resultError = error
            } else if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                resultError = PdfViewerError.downloadFailed(http.statusCode)
            } else {
                resultData = data
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        if let resultError {
            throw resultError
        }
        guard let resultData else {
            throw PdfViewerError.invalidDocument
        }
        return resultData
    }

    private static func decodeBase64(_ source: String) throws -> Data {
        let payload: String
        if source.lowercased().hasPrefix("data:"), let comma = source.firstIndex(of: ",") {
            payload = String(source[source.index(after: comma)...])
        } else {
            payload = source
        }
        let cleaned = payload.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        guard let data = Data(base64Encoded: cleaned) else {
            throw PdfViewerError.invalidSource
        }
        return data
    }

    private static func readFile(_ source: String) throws -> Data {
        if source.lowercased().hasPrefix("file://"), let url = URL(string: source) {
            return try Data(contentsOf: url)
        }
        let path = source.hasPrefix("file://") ? String(source.dropFirst("file://".count)) : source
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }
}

enum PdfViewerError: LocalizedError {
    case invalidSource
    case invalidDocument
    case passwordRequired
    case downloadFailed(Int)
    case elementNotFound
    case missingElementId

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            return "Invalid PDF source"
        case .invalidDocument:
            return "Could not open PDF document"
        case .passwordRequired:
            return "PDF is password protected"
        case .downloadFailed(let code):
            return "Failed to download PDF (\(code))"
        case .elementNotFound:
            return "Inline element not found"
        case .missingElementId:
            return "elementId is required when mode is inline"
        }
    }
}
