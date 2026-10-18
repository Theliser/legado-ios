import Foundation

/// 专用于单元测试、全流程自动化验收与 UI Preview 的 Mock HTTP 客户端
public final class MockHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    public typealias Handler = @Sendable (URL, [String: String]?, Data?) throws -> String

    private let lock = NSLock()
    private var urlHandlers: [String: Handler] = [:]
    private var defaultHandler: Handler?

    public init() {}

    /// 注册指定 URL 前缀或精准匹配的模拟响应
    public func register(matching pattern: String, handler: @escaping Handler) {
        lock.lock()
        defer { lock.unlock() }
        urlHandlers[pattern] = handler
    }

    /// 注册默认回退响应
    public func registerDefault(handler: @escaping Handler) {
        lock.lock()
        defer { lock.unlock() }
        defaultHandler = handler
    }

    /// 清空所有注册规则
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        urlHandlers.removeAll()
        defaultHandler = nil
    }

    public func get(
        url: URL,
        headers: [String: String]?,
        timeout _: TimeInterval) async throws -> String {
        try matchHandler(url: url, headers: headers, body: nil)
    }

    public func post(
        url: URL,
        body: Data?,
        headers: [String: String]?,
        timeout _: TimeInterval) async throws -> String {
        try matchHandler(url: url, headers: headers, body: body)
    }

    private func matchHandler(url: URL, headers: [String: String]?, body: Data?) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        let urlString = url.absoluteString

        // 优先匹配精准或包含 pattern
        for (pattern, handler) in urlHandlers where urlString.contains(pattern) {
            return try handler(url, headers, body)
        }

        if let defaultHandler {
            return try defaultHandler(url, headers, body)
        }

        throw URLError(.fileDoesNotExist)
    }
}
