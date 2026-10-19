import Foundation

extension AnalyzeUrl {
    struct ParsedUrlOptions {
        var finalUrl: String
        var method: String
        var body: String?
        var charset: String
        var headers: [String: String]
        var webJs: String?
        var bodyJs: String?
        var webViewDelayTime: Int?
        var useWebView: Bool
        var retry: Int
        var type: String?
    }

    static func parseUrlAndOptions(
        workingUrl: String,
        headerJson: String?,
        baseUrl: String? = nil) -> ParsedUrlOptions {
        var options = ParsedUrlOptions(
            finalUrl: workingUrl,
            method: "GET",
            body: nil,
            charset: "utf-8",
            headers: [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Mobile/15E148",
            ],
            webJs: nil,
            bodyJs: nil,
            webViewDelayTime: nil,
            useWebView: false,
            retry: 0,
            type: nil)

        // 1. 解析 source.header (对齐 Android BaseSource.kt getHeaderMap，支持 @js: 与 <js></js>)
        if let headerJson, !headerJson.isEmpty {
            let parsedHeaders = parseHeaderJson(headerJson, baseUrl: baseUrl ?? workingUrl)
            mergeHeaders(parsedHeaders, into: &options.headers)
        }

        // 2. 解析 URL 选项 (url,{...})
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

    static func parseHeaderJson(_ rawHeader: String, baseUrl: String) -> [String: String] {
        var trimmed = rawHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@js:") {
            let script = String(trimmed.dropFirst(4))
            let engine = JSEngine()
            trimmed = engine.evaluate(script: script, bindings: [
                "baseUrl": baseUrl,
            ])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } else if trimmed.hasPrefix("<js>"), trimmed.contains("</js>"),
                  let start = trimmed.range(of: "<js>")?.upperBound,
                  let end = trimmed.range(of: "</js>", options: .backwards)?.lowerBound {
            let script = String(trimmed[start ..< end])
            let engine = JSEngine()
            trimmed = engine.evaluate(script: script, bindings: [
                "baseUrl": baseUrl,
            ])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        var result: [String: String] = [:]
        for (headerKey, headerValue) in dict {
            result[headerKey] = "\(headerValue)"
        }
        return result
    }

    static func mergeHeaders(_ newHeaders: [String: String], into target: inout [String: String]) {
        for (key, val) in newHeaders {
            if key.caseInsensitiveCompare("User-Agent") == .orderedSame {
                let keysToRemove = target.keys.filter { $0.caseInsensitiveCompare("User-Agent") == .orderedSame }
                for existingKey in keysToRemove {
                    target.removeValue(forKey: existingKey)
                }
                target["User-Agent"] = val
            } else {
                target[key] = val
            }
        }
    }

    private static func applyOptionsDictionary(_ dict: [String: Any], to options: inout ParsedUrlOptions) {
        applyMethodAndBody(dict, to: &options)
        applyHeadersFromDict(dict, to: &options)
        applyScripts(dict, to: &options)
        applyDelayAndExtraOptions(dict, to: &options)
    }

    private static func applyMethodAndBody(_ dict: [String: Any], to options: inout ParsedUrlOptions) {
        if let methodVal = dict["method"] as? String {
            options.method = methodVal.uppercased()
        }
        if let bodyVal = dict["body"] as? String {
            options.body = bodyVal
        } else if let bodyDict = dict["body"] as? [String: Any],
                  let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict),
                  let bodyStr = String(data: bodyData, encoding: .utf8) {
            options.body = bodyStr
        }
        if let charsetVal = dict["charset"] as? String {
            options.charset = charsetVal.lowercased()
        }
    }

    private static func applyHeadersFromDict(_ dict: [String: Any], to options: inout ParsedUrlOptions) {
        if let headersDict = dict["headers"] as? [String: Any] {
            var extracted: [String: String] = [:]
            for (headerKey, headerValue) in headersDict {
                extracted[headerKey] = "\(headerValue)"
            }
            mergeHeaders(extracted, into: &options.headers)
        } else if let headersStr = dict["headers"] as? String,
                  let data = headersStr.data(using: .utf8),
                  let headersDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var extracted: [String: String] = [:]
            for (headerKey, headerValue) in headersDict {
                extracted[headerKey] = "\(headerValue)"
            }
            mergeHeaders(extracted, into: &options.headers)
        }

        // 顶层平铺 HTTP 请求头支持
        let knownHeaders = ["cookie", "referer", "authorization", "origin", "accept"]
        for (headerKey, headerValue) in dict {
            if headerKey.caseInsensitiveCompare("User-Agent") == .orderedSame {
                mergeHeaders(["User-Agent": "\(headerValue)"], into: &options.headers)
            } else if knownHeaders.contains(headerKey.lowercased()) {
                mergeHeaders([headerKey: "\(headerValue)"], into: &options.headers)
            }
        }
    }

    private static func applyScripts(_ dict: [String: Any], to options: inout ParsedUrlOptions) {
        if let webJsVal = dict["webJs"] as? String {
            options.webJs = webJsVal
        }
        if let bodyJsVal = dict["bodyJs"] as? String {
            options.bodyJs = bodyJsVal
        }
        if let jsVal = dict["js"] as? String {
            let jsEngine = JSEngine()
            if let newUrl = jsEngine.evaluate(script: jsVal, bindings: ["result": options.finalUrl]) {
                options.finalUrl = newUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    private static func applyDelayAndExtraOptions(_ dict: [String: Any], to options: inout ParsedUrlOptions) {
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
        if let retryVal = dict["retry"] as? Int {
            options.retry = retryVal
        }
        if let typeVal = dict["type"] as? String {
            options.type = typeVal
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

    public static func resolveAbsoluteUrl(_ pathOrUrl: String, baseUrl: String, charset: String = "utf-8") -> String {
        let trimmed = pathOrUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        var absolute = trimmed
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            if let base = URL(string: baseUrl),
               let resolved = URL(string: trimmed, relativeTo: base) {
                absolute = resolved.absoluteURL.absoluteString
            }
        }
        return encodeUrlWithCharset(absolute, charset: charset)
    }

    private static func encodeUrlWithCharset(_ urlStr: String, charset: String) -> String {
        guard let questionIndex = urlStr.firstIndex(of: "?") else {
            return urlStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlStr
        }
        let basePart = String(urlStr[..<questionIndex])
        let queryPart = String(urlStr[urlStr.index(after: questionIndex)...])

        let encodedBase = basePart.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? basePart
        let isGbk = charset.lowercased() == "gbk" || charset.lowercased() == "gb2312"
        let pairs = queryPart.components(separatedBy: "&")
        let encodedPairs = pairs.map { pair -> String in
            let pairComponents = pair.components(separatedBy: "=")
            let key = pairComponents[0]
            guard pairComponents.count > 1 else { return key }
            let val = pairComponents.dropFirst().joined(separator: "=")
            if isGbk && !val.contains("%") {
                let encodedVal = CharsetDetector.percentEncodeGBK(val)
                return "\(key)=\(encodedVal)"
            } else if !val.contains("%") {
                let encodedVal = val.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? val
                return "\(key)=\(encodedVal)"
            }
            return pair
        }
        return "\(encodedBase)?\(encodedPairs.joined(separator: "&"))"
    }
}

public extension BookSource {
    /// 获取书源请求头规则字典 (对齐 Android Legado BaseSource.kt getHeaderMap)
    func getHeaderMap(defaultUA: String? = nil) -> [String: String] {
        var baseHeaders: [String: String] = [:]
        if let defaultUA, !defaultUA.isEmpty {
            baseHeaders["User-Agent"] = defaultUA
        }
        if let header, !header.isEmpty {
            let parsed = AnalyzeUrl.parseHeaderJson(header, baseUrl: bookSourceUrl)
            AnalyzeUrl.mergeHeaders(parsed, into: &baseHeaders)
        }
        return baseHeaders
    }
}
