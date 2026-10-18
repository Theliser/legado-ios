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

    /// 发起 GET 请求并自动进行编码转换
    public func get(
        url: URL,
        headers: [String: String]? = nil,
        timeout: TimeInterval = 15) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        applyHeaders(to: &request, customHeaders: headers)

        if let host = url.host, let cookie = await CookieJar.shared.cookieHeader(for: host) {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            if let allHeaders = httpResponse.allHeaderFields as? [String: String] {
                await CookieJar.shared.saveCookies(from: allHeaders, for: url)
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

        if let host = url.host, let cookie = await CookieJar.shared.cookieHeader(for: host) {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            if let allHeaders = httpResponse.allHeaderFields as? [String: String] {
                await CookieJar.shared.saveCookies(from: allHeaders, for: url)
            }
            return CharsetDetector.decode(data: data, response: httpResponse)
        }

        return CharsetDetector.decode(data: data)
    }

    private func applyHeaders(to request: inout URLRequest, customHeaders: [String: String]?) {
        request.setValue(defaultUserAgent, forHTTPHeaderField: "User-Agent")
        let acceptTypes = "text/html,application/xhtml+xml,application/xml;q=0.9,application/json,*/*;q=0.8"
        request.setValue(acceptTypes, forHTTPHeaderField: "Accept")

        if let customHeaders {
            for (key, value) in customHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
    }
}
