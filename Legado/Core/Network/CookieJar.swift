import Foundation

/// 书源专用 Cookie 管理容器
public actor CookieJar {
    public static let shared = CookieJar()

    private var storage: [String: [String: String]] = [:]

    public init() {}

    /// 获取指定 Host 的 Cookie 拼接字符串 (用于 Header `Cookie: ...`)
    public func cookieHeader(for host: String) -> String? {
        guard let cookies = storage[host.lowercased()], !cookies.isEmpty else {
            return nil
        }
        return cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    /// 设置指定 Host 的 Cookie
    public func setCookie(name: String, value: String, for host: String) {
        let normalizedHost = host.lowercased()
        var current = storage[normalizedHost] ?? [:]
        current[name] = value
        storage[normalizedHost] = current
    }

    /// 从 `Set-Cookie` 响应头字符串中解析并保存 Cookie
    public func saveCookies(from headerFields: [String: String], for url: URL) {
        guard let host = url.host?.lowercased() else { return }

        for (key, value) in headerFields where key.lowercased() == "set-cookie" {
            let parts = value.components(separatedBy: ";")
            if let firstPart = parts.first {
                let pair = firstPart.components(separatedBy: "=")
                if pair.count == 2 {
                    let name = pair[0].trimmingCharacters(in: .whitespaces)
                    let val = pair[1].trimmingCharacters(in: .whitespaces)
                    setCookie(name: name, value: val, for: host)
                }
            }
        }
    }

    /// 清理指定 Host 的 Cookie
    public func clear(for host: String) {
        storage.removeValue(forKey: host.lowercased())
    }
}
