import Foundation

/// 异步 HTTP 客户端抽象协议，便于单元测试与 Mock 模拟注入
public protocol HTTPClientProtocol: Sendable {
    func get(
        url: URL,
        headers: [String: String]?,
        timeout: TimeInterval) async throws -> String

    func post(
        url: URL,
        body: Data?,
        headers: [String: String]?,
        timeout: TimeInterval) async throws -> String

    func fetch(analyzeUrl: AnalyzeUrl) async throws -> String
    func fetchStrResponse(analyzeUrl: AnalyzeUrl) async throws -> StrResponse
}

public extension HTTPClientProtocol {
    func get(
        url: URL,
        headers: [String: String]? = nil,
        timeout: TimeInterval = 15) async throws -> String {
        try await get(url: url, headers: headers, timeout: timeout)
    }

    func post(
        url: URL,
        body: Data? = nil,
        headers: [String: String]? = nil,
        timeout: TimeInterval = 15) async throws -> String {
        try await post(url: url, body: body, headers: headers, timeout: timeout)
    }

    func fetch(analyzeUrl: AnalyzeUrl) async throws -> String {
        if analyzeUrl.method == "POST" {
            return try await post(url: analyzeUrl.url, body: analyzeUrl.body, headers: analyzeUrl.headers)
        } else {
            return try await get(url: analyzeUrl.url, headers: analyzeUrl.headers)
        }
    }

    func fetchStrResponse(analyzeUrl: AnalyzeUrl) async throws -> StrResponse {
        let startTime = Date()
        let body = try await fetch(analyzeUrl: analyzeUrl)
        let duration = Int(Date().timeIntervalSince(startTime) * 1000)
        return StrResponse(
            url: analyzeUrl.url.absoluteString,
            body: body,
            code: 200,
            message: "OK",
            headers: analyzeUrl.headers,
            isRedirect: false,
            callTime: duration)
    }
}

/// 书源抓取专用异步网络客户端
public final class HTTPClient: HTTPClientProtocol, Sendable {
    public static let shared = HTTPClient()

    private let session: URLSession
    private let defaultUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(
        url: URL,
        headers: [String: String]? = nil,
        timeout: TimeInterval = 15) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        applyHeaders(to: &request, customHeaders: headers)

        let persistentCookie = CookieStore.shared.getCookie(url: url.absoluteString)
        if !persistentCookie.isEmpty {
            request.setValue(persistentCookie, forHTTPHeaderField: "Cookie")
        } else if let host = url.host, let cookie = await CookieJar.shared.cookieHeader(for: host) {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            if let allHeaders = httpResponse.allHeaderFields as? [String: String] {
                await CookieJar.shared.saveCookies(from: allHeaders, for: url)
                if let setCookie = allHeaders["Set-Cookie"] ?? allHeaders["set-cookie"] {
                    CookieStore.shared.setCookie(url: url.absoluteString, cookie: setCookie)
                }
            }
            return CharsetDetector.decode(data: data, response: httpResponse)
        }

        return CharsetDetector.decode(data: data)
    }

    /// 发起 POST 请求
    public func post(
        url: URL,
        body: Data?,
        headers: [String: String]? = nil,
        timeout: TimeInterval = 15) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = body
        applyHeaders(to: &request, customHeaders: headers)

        let persistentCookie = CookieStore.shared.getCookie(url: url.absoluteString)
        if !persistentCookie.isEmpty {
            request.setValue(persistentCookie, forHTTPHeaderField: "Cookie")
        } else if let host = url.host, let cookie = await CookieJar.shared.cookieHeader(for: host) {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            if let allHeaders = httpResponse.allHeaderFields as? [String: String] {
                await CookieJar.shared.saveCookies(from: allHeaders, for: url)
                if let setCookie = allHeaders["Set-Cookie"] ?? allHeaders["set-cookie"] {
                    CookieStore.shared.setCookie(url: url.absoluteString, cookie: setCookie)
                }
            }
            return CharsetDetector.decode(data: data, response: httpResponse)
        }

        return CharsetDetector.decode(data: data)
    }

    /// 支持 AnalyzeUrl 高级选项（如 useWebView / webJs / webViewDelayTime / bodyJs）的请求方法
    public func fetch(analyzeUrl: AnalyzeUrl) async throws -> String {
        let rawBody: String
        if analyzeUrl.useWebView {
            let res = try await BrowserVerificationManager.shared.executeHeadlessWeb(
                url: analyzeUrl.url.absoluteString,
                webJs: analyzeUrl.webJs,
                delayTimeMs: analyzeUrl.webViewDelayTime ?? 0,
                headers: analyzeUrl.headers)
            rawBody = res.body
        } else if analyzeUrl.method == "POST" {
            rawBody = try await post(url: analyzeUrl.url, body: analyzeUrl.body, headers: analyzeUrl.headers)
        } else {
            rawBody = try await get(url: analyzeUrl.url, headers: analyzeUrl.headers)
        }

        // 如果配置了 bodyJs，执行二次 JS 结果变换处理 (对齐 Android Legado AnalyzeUrl.kt:524)
        if let bodyJs = analyzeUrl.bodyJs, !bodyJs.isEmpty {
            let engine = JSEngine()
            let transformed = engine.evaluate(script: bodyJs, bindings: [
                "result": rawBody,
                "baseUrl": analyzeUrl.url.absoluteString,
            ])
            return transformed ?? rawBody
        }

        return rawBody
    }

    /// 支持返回完整响应元数据的请求方法 (对齐 Android newCallStrResponse)
    public func fetchStrResponse(analyzeUrl: AnalyzeUrl) async throws -> StrResponse {
        let startTime = Date()
        if analyzeUrl.useWebView {
            return try await executeHeadlessStrResponse(analyzeUrl: analyzeUrl, startTime: startTime)
        }
        return try await executeHttpStrResponse(analyzeUrl: analyzeUrl, startTime: startTime)
    }

    private func executeHeadlessStrResponse(analyzeUrl: AnalyzeUrl, startTime: Date) async throws -> StrResponse {
        let res = try await BrowserVerificationManager.shared.executeHeadlessWeb(
            url: analyzeUrl.url.absoluteString,
            webJs: analyzeUrl.webJs,
            delayTimeMs: analyzeUrl.webViewDelayTime ?? 0,
            headers: analyzeUrl.headers)
        var body = res.body
        if let bodyJs = analyzeUrl.bodyJs, !bodyJs.isEmpty {
            let engine = JSEngine()
            body = engine.evaluate(script: bodyJs, bindings: [
                "result": body,
                "baseUrl": res.url,
            ]) ?? body
        }
        let duration = Int(Date().timeIntervalSince(startTime) * 1000)
        return StrResponse(
            url: res.url,
            body: body,
            code: 200,
            message: "OK",
            headers: analyzeUrl.headers,
            isRedirect: res.url != analyzeUrl.url.absoluteString,
            callTime: duration)
    }

    private func executeHttpStrResponse(analyzeUrl: AnalyzeUrl, startTime: Date) async throws -> StrResponse {
        var request = URLRequest(url: analyzeUrl.url, timeoutInterval: 15)
        request.httpMethod = analyzeUrl.method
        request.httpBody = analyzeUrl.body
        applyHeaders(to: &request, customHeaders: analyzeUrl.headers)

        let persistentCookie = CookieStore.shared.getCookie(url: analyzeUrl.url.absoluteString)
        if !persistentCookie.isEmpty {
            request.setValue(persistentCookie, forHTTPHeaderField: "Cookie")
        } else if let host = analyzeUrl.url.host, let cookie = await CookieJar.shared.cookieHeader(for: host) {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await session.data(for: request)
        var statusCode = 200
        var finalUrl = analyzeUrl.url.absoluteString
        var resHeaders: [String: String] = [:]
        var isRedirect = false
        var rawBody: String

        if let httpResponse = response as? HTTPURLResponse {
            statusCode = httpResponse.statusCode
            if let resUrl = httpResponse.url?.absoluteString {
                finalUrl = resUrl
                isRedirect = resUrl != analyzeUrl.url.absoluteString
            }
            if let allHeaders = httpResponse.allHeaderFields as? [String: String] {
                resHeaders = allHeaders
                await CookieJar.shared.saveCookies(from: allHeaders, for: analyzeUrl.url)
                if let setCookie = allHeaders["Set-Cookie"] ?? allHeaders["set-cookie"] {
                    CookieStore.shared.setCookie(url: analyzeUrl.url.absoluteString, cookie: setCookie)
                }
            }
            rawBody = CharsetDetector.decode(data: data, response: httpResponse)
        } else {
            rawBody = CharsetDetector.decode(data: data)
        }

        if let bodyJs = analyzeUrl.bodyJs, !bodyJs.isEmpty {
            let engine = JSEngine()
            rawBody = engine.evaluate(script: bodyJs, bindings: [
                "result": rawBody,
                "baseUrl": finalUrl,
            ]) ?? rawBody
        }

        let duration = Int(Date().timeIntervalSince(startTime) * 1000)
        return StrResponse(
            url: finalUrl,
            body: rawBody,
            code: statusCode,
            message: "OK",
            headers: resHeaders,
            isRedirect: isRedirect,
            callTime: duration)
    }

    private func applyHeaders(to request: inout URLRequest, customHeaders: [String: String]?) {
        request.setValue(defaultUserAgent, forHTTPHeaderField: "User-Agent")
        let acceptTypes = "text/html,application/xhtml+xml,application/xml;q=0.9,application/json,*/*;q=0.8"
        request.setValue(acceptTypes, forHTTPHeaderField: "Accept")

        if let customHeaders {
            var customUA: String?
            for (key, value) in customHeaders {
                if key.caseInsensitiveCompare("User-Agent") == .orderedSame {
                    customUA = value
                } else {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            if let customUA {
                request.setValue(customUA, forHTTPHeaderField: "User-Agent")
            }
        }
    }
}
