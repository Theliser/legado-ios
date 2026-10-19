import Foundation

extension AnalyzeUrl {
    struct ParsedUrlOptions {
        var finalUrl: String
        var method: String
        var body: String?
        var charset: String
        var headers: [String: String]
        var webJs: String?
        var webViewDelayTime: Int?
        var useWebView: Bool
    }

    static func parseUrlAndOptions(
        workingUrl: String,
        headerJson: String?) -> ParsedUrlOptions {
        var options = ParsedUrlOptions(
            finalUrl: workingUrl,
            method: "GET",
            body: nil,
            charset: "utf-8",
            headers: [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Mobile/15E148",
            ],
            webJs: nil,
            webViewDelayTime: nil,
            useWebView: false)

        if let headerJson, !headerJson.isEmpty,
           let data = headerJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            options.headers.merge(parsed) { _, new in new }
        }

        guard let commaIndex = workingUrl.firstIndex(of: ",") else {
            return options
        }

        let optionsCandidate = String(workingUrl[workingUrl.index(after: commaIndex)...])
            .trimmingCharacters(in: .whitespaces)
        guard optionsCandidate.hasPrefix("{") else {
            return options
        }

        options.finalUrl = String(workingUrl[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        let jsEngine = JSEngine()
        guard let jsonStr = jsEngine.evaluate(script: "JSON.stringify(" + optionsCandidate + ")"),
              let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return options
        }

        applyOptionsDictionary(dict, to: &options)
        return options
    }

    private static func applyOptionsDictionary(_ dict: [String: Any], to options: inout ParsedUrlOptions) {
        if let methodVal = dict["method"] as? String {
            options.method = methodVal.uppercased()
        }
        if let bodyVal = dict["body"] as? String {
            options.body = bodyVal
        }
        if let charsetVal = dict["charset"] as? String {
            options.charset = charsetVal.lowercased()
        }
        if let headersVal = dict["headers"] as? [String: String] {
            options.headers.merge(headersVal) { _, new in new }
        }
        if let webJsVal = dict["webJs"] as? String {
            options.webJs = webJsVal
        }
        if let delayVal = dict["webViewDelayTime"] as? Int {
            options.webViewDelayTime = delayVal
        } else if let delayVal = dict["webViewDelayTime"] as? Double {
            options.webViewDelayTime = Int(delayVal)
        } else if let delayStr = dict["webViewDelayTime"] as? String, let delayVal = Int(delayStr) {
            options.webViewDelayTime = delayVal
        }
        if let useWebViewVal = dict["useWebView"] as? Bool {
            options.useWebView = useWebViewVal
        } else if let useWebViewVal = dict["webView"] as? Bool {
            options.useWebView = useWebViewVal
        }
    }

    static func buildRequestBody(
        options: ParsedUrlOptions,
        rawKey: String,
        pageStr: String) -> (Data?, [String: String]) {
        guard let bStr = options.body else {
            return (nil, options.headers)
        }

        var updatedHeaders = options.headers
        let resolvedBody = bStr
            .replacingOccurrences(of: "{{key}}", with: rawKey)
            .replacingOccurrences(of: "{{searchKey}}", with: rawKey)
            .replacingOccurrences(of: "{{page}}", with: pageStr)

        let bodyData: Data?
        if options.charset == "gbk" || options.charset == "gb2312" {
            bodyData = resolvedBody.data(using: CharsetDetector.gbkEncoding) ?? resolvedBody.data(using: .utf8)
        } else {
            bodyData = resolvedBody.data(using: .utf8)
        }

        if options.method == "POST", updatedHeaders["Content-Type"] == nil {
            if resolvedBody.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
                updatedHeaders["Content-Type"] = "application/json; charset=\(options.charset)"
            } else {
                updatedHeaders["Content-Type"] = "application/x-www-form-urlencoded; charset=\(options.charset)"
            }
        }

        return (bodyData, updatedHeaders)
    }

    public static func resolveAbsoluteUrl(_ pathOrUrl: String, baseUrl: String) -> String {
        let trimmed = pathOrUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }
        guard let base = URL(string: baseUrl),
              let resolved = URL(string: trimmed, relativeTo: base) else {
            return trimmed
        }
        return resolved.absoluteURL.absoluteString
    }
}
