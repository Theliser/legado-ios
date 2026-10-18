import Foundation

/// 统一的 Legado URL 与网络请求构建解析器上下文
public struct AnalyzeUrlContext: Sendable {
    public let key: String?
    public let page: Int?
    public let baseUrl: String
    public let headerJson: String?
    public let source: BookSource?
    public let book: Book?

    public init(
        key: String? = nil,
        page: Int? = nil,
        baseUrl: String = "",
        headerJson: String? = nil,
        source: BookSource? = nil,
        book: Book? = nil) {
        self.key = key
        self.page = page
        self.baseUrl = baseUrl
        self.headerJson = headerJson
        self.source = source
        self.book = book
    }
}

/// 统一的 Legado URL 与网络请求构建解析器 (全面对标 Android Legado AnalyzeUrl.kt)
public struct AnalyzeUrl: Sendable {
    public let url: URL
    public let method: String
    public let body: Data?
    public let headers: [String: String]

    public init(rawUrl: String, context: AnalyzeUrlContext) throws {
        var workingUrl = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        // 0. 处理 @get:{...} 变量替换
        workingUrl = Self.resolveGetVariables(workingUrl)

        // 1. 处理 @js: 或 <js></js> 动态生成 URL
        workingUrl = Self.evaluateUrlJs(rawUrl: workingUrl, context: context)

        // 2. 处理内嵌 {{ ... }} (支持 {{key}}, {{page}}, 以及 JS 计算如 {{(page-1)*50}})
        let rawKey = context.key ?? ""
        let encodedKey = rawKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawKey
        let pageStr = String(context.page ?? 1)
        workingUrl = Self.interpolateTemplate(
            url: workingUrl,
            rawKey: rawKey,
            encodedKey: encodedKey,
            page: context.page ?? 1,
            pageStr: pageStr,
            baseUrl: context.baseUrl)

        // 3. 解析 URL 与附加配置 (url,{"method": "POST", "body": "...", "headers": {...}, "charset": "gbk"})
        let options = Self.parseUrlAndOptions(
            workingUrl: workingUrl,
            headerJson: context.headerJson)

        // 4. 解析绝对 URL
        let resolvedUrlStr = Self.resolveAbsoluteUrl(options.finalUrl, baseUrl: context.baseUrl)
        guard let finalUrl = URL(string: resolvedUrlStr) else {
            throw URLError(.badURL)
        }

        // 5. 编码请求 Body 并处理编码 (支持 GBK / UTF-8)
        let (bodyData, finalHeaders) = Self.buildRequestBody(
            options: options,
            rawKey: rawKey,
            pageStr: pageStr)

        self.url = finalUrl
        self.method = options.method
        self.body = bodyData
        self.headers = finalHeaders
    }

    public init(
        rawUrl: String,
        key: String? = nil,
        page: Int? = nil,
        baseUrl: String = "",
        headerJson: String? = nil,
        source: BookSource? = nil,
        book: Book? = nil) throws {
        let ctx = AnalyzeUrlContext(
            key: key,
            page: page,
            baseUrl: baseUrl,
            headerJson: headerJson,
            source: source,
            book: book)
        try self.init(rawUrl: rawUrl, context: ctx)
    }

    private static func evaluateUrlJs(rawUrl: String, context: AnalyzeUrlContext) -> String {
        let pattern = #"(?:<js>([\s\S]*?)</js>)|(?:@js:([\s\S]*))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return rawUrl
        }
        let nsString = rawUrl as NSString
        let matches = regex.matches(in: rawUrl, range: NSRange(location: 0, length: nsString.length))
        if matches.isEmpty {
            return rawUrl
        }

        let jsEngine = JSEngine()
        var bindings = buildBindings(from: context, rawUrl: rawUrl)
        let (intermediateResult, endOffset) = executeJsMatches(
            matches: matches,
            nsString: nsString,
            rawUrl: rawUrl,
            jsEngine: jsEngine,
            bindings: &bindings)

        return resolveTrailingUrl(
            nsString: nsString,
            start: endOffset,
            currentResult: intermediateResult,
            rawUrl: rawUrl)
    }

    private static func buildBindings(from context: AnalyzeUrlContext, rawUrl: String) -> [String: Any] {
        var bindings: [String: Any] = [
            "key": context.key ?? "",
            "searchKey": context.key ?? "",
            "page": context.page ?? 1,
            "baseUrl": context.baseUrl,
            "result": rawUrl,
        ]
        if let source = context.source {
            bindings["bookSourceUrl"] = source.bookSourceUrl
            bindings["bookSourceName"] = source.bookSourceName
            bindings["loginUrl"] = source.loginUrl ?? ""
        }
        if let book = context.book {
            bindings["bookUrl"] = book.bookUrl
            bindings["bookName"] = book.name
            bindings["bookAuthor"] = book.author
        }
        return bindings
    }

    private static func executeJsMatches(
        matches: [NSTextCheckingResult],
        nsString: NSString,
        rawUrl: String,
        jsEngine: JSEngine,
        bindings: inout [String: Any]) -> (result: String, endOffset: Int) {
        var start = 0
        var current = rawUrl

        for match in matches {
            if match.range.location > start {
                let leading = nsString.substring(with: NSRange(location: start, length: match.range.location - start))
                    .trimmingCharacters(in: .whitespaces)
                if !leading.isEmpty {
                    current = leading.replacingOccurrences(of: "@result", with: current)
                }
            }
            let scriptRange = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            let script = nsString.substring(with: scriptRange)
            bindings["result"] = current
            if let output = jsEngine.evaluate(script: script, bindings: bindings),
               !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                current = output.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if script.contains("/search") || script.contains(".php") || script.contains("/") {
                var clean = script.trimmingCharacters(in: .whitespacesAndNewlines)
                if let semiRange = clean.range(of: #";\s*result\s*="#, options: .regularExpression) {
                    clean = String(clean[..<semiRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                current = clean
            }
            start = match.range.location + match.range.length
        }
        return (current, start)
    }

    private static func resolveTrailingUrl(
        nsString: NSString,
        start: Int,
        currentResult: String,
        rawUrl: String) -> String {
        guard nsString.length > start else { return currentResult }
        let trailing = nsString.substring(from: start).trimmingCharacters(in: .whitespaces)
        guard !trailing.isEmpty else { return currentResult }

        if trailing.contains("@result") {
            return trailing.replacingOccurrences(of: "@result", with: currentResult)
        } else if currentResult.isEmpty || currentResult == rawUrl {
            return trailing
        } else if !trailing.hasPrefix(",") && !currentResult.contains(trailing) {
            return trailing
        }
        return currentResult
    }

    private static func resolveGetVariables(_ input: String) -> String {
        guard input.contains("@get:{"),
              let regex = try? NSRegularExpression(pattern: #"@get:\{([^}]+)\}"#, options: []) else {
            return input
        }
        var result = input
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
        for match in matches.reversed() {
            guard let range0 = Range(match.range(at: 0), in: result),
                  let range1 = Range(match.range(at: 1), in: input) else { continue }
            let key = String(input[range1]).trimmingCharacters(in: .whitespaces)
            let val = RuleEvaluator.getVariable(key) ?? ""
            result.replaceSubrange(range0, with: val)
        }
        return result
    }

    private static func interpolateTemplate(
        url: String,
        rawKey: String,
        encodedKey: String,
        page: Int,
        pageStr: String,
        baseUrl: String = "") -> String {
        guard url.contains("{{"), url.contains("}}"),
              let regex = try? NSRegularExpression(pattern: #"\{\{([^}]+)\}\}"#, options: []) else {
            return url
        }

        var result = url
        let matches = regex.matches(in: url, options: [], range: NSRange(location: 0, length: url.utf16.count))
        let jsEngine = JSEngine()

        for match in matches.reversed() {
            guard let range0 = Range(match.range(at: 0), in: result),
                  let range1 = Range(match.range(at: 1), in: url) else {
                continue
            }
            var expr = String(url[range1]).trimmingCharacters(in: .whitespaces)
            expr = expr.replacingOccurrences(of: "\u{a0}", with: " ")
            let val: String
            if expr == "key" || expr == "searchKey" {
                val = encodedKey
            } else if expr == "page" {
                val = pageStr
            } else if expr == "baseUrl" {
                val = baseUrl
            } else if expr.hasPrefix("@get:") {
                let varKey = String(expr.dropFirst(5)).trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
                val = RuleEvaluator.getVariable(varKey) ?? ""
            } else {
                let evalScript = "var page = \(page); var key = \"\(rawKey)\"; var baseUrl = \"\(baseUrl)\"; \(expr)"
                val = jsEngine.evaluate(script: evalScript) ?? ""
            }
            result.replaceSubrange(range0, with: val)
        }
        return result
    }

    private struct ParsedUrlOptions {
        var finalUrl: String
        var method: String
        var body: String?
        var charset: String
        var headers: [String: String]
    }

    private static func parseUrlAndOptions(
        workingUrl: String,
        headerJson: String?) -> ParsedUrlOptions {
        var requestMethod = "GET"
        var requestBodyStr: String?
        var requestCharset = "utf-8"
        var finalUrlStr = workingUrl
        var mergedHeaders: [String: String] = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Mobile/15E148",
        ]

        if let headerJson, !headerJson.isEmpty,
           let data = headerJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            mergedHeaders.merge(parsed) { _, new in new }
        }

        if let commaIndex = workingUrl.firstIndex(of: ",") {
            let optionsCandidate = String(workingUrl[workingUrl.index(after: commaIndex)...])
                .trimmingCharacters(in: .whitespaces)
            if optionsCandidate.hasPrefix("{") {
                finalUrlStr = String(workingUrl[..<commaIndex]).trimmingCharacters(in: .whitespaces)
                let jsEngine = JSEngine()
                if let jsonStr = jsEngine.evaluate(script: "JSON.stringify(" + optionsCandidate + ")"),
                   let data = jsonStr.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let methodVal = dict["method"] as? String {
                        requestMethod = methodVal.uppercased()
                    }
                    if let bodyVal = dict["body"] as? String {
                        requestBodyStr = bodyVal
                    }
                    if let charsetVal = dict["charset"] as? String {
                        requestCharset = charsetVal.lowercased()
                    }
                    if let headersVal = dict["headers"] as? [String: String] {
                        mergedHeaders.merge(headersVal) { _, new in new }
                    }
                }
            }
        }
        return ParsedUrlOptions(
            finalUrl: finalUrlStr,
            method: requestMethod,
            body: requestBodyStr,
            charset: requestCharset,
            headers: mergedHeaders)
    }

    private static func buildRequestBody(
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
