import Foundation

/// 跨会话持久化与统一 Cookie 存储 (完全对齐 Android Legado CookieStore)
public final class CookieStore: @unchecked Sendable {
    public static let shared = CookieStore()

    private let lock = NSLock()
    private let userDefaultsKey = "legado_persistent_cookies_store"
    private var cookieCache: [String: String] = [:]

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String] {
            cookieCache = saved
        }
    }

    public static func getCookie(url: String) -> String {
        shared.getCookie(url: url)
    }

    public static func setCookie(url: String, cookie: String) {
        shared.setCookie(url: url, cookie: cookie)
    }

    public static func replaceCookie(url: String, cookie: String) {
        shared.replaceCookie(url: url, cookie: cookie)
    }

    public static func getKey(url: String, key: String) -> String {
        shared.getKey(url: url, key: key)
    }

    public static func cookieToMap(_ cookie: String) -> [String: String] {
        shared.cookieToMap(cookie)
    }

    public static func mapToCookie(_ map: [String: String]) -> String {
        shared.mapToCookie(map)
    }

    public static func removeCookie(url: String) {
        shared.removeCookie(url: url)
    }

    public func getCookie(url: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let host = extractHost(url) else { return "" }
        return cookieCache[host] ?? ""
    }

    public func getKey(url: String, key: String) -> String {
        let cookieStr = getCookie(url: url)
        return cookieToMap(cookieStr)[key] ?? ""
    }

    public func replaceCookie(url: String, cookie: String) {
        setCookie(url: url, cookie: cookie)
    }

    public func cookieToMap(_ cookieStr: String) -> [String: String] {
        parseCookies(cookieStr)
    }

    public func mapToCookie(_ map: [String: String]) -> String {
        map.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    public func setCookie(url: String, cookie: String) {
        guard !cookie.isEmpty, let host = extractHost(url) else { return }
        lock.lock()
        defer { lock.unlock() }

        let existing = cookieCache[host] ?? ""
        var cookieMap = parseCookies(existing)
        let incoming = parseCookies(cookie)
        for (key, val) in incoming {
            cookieMap[key] = val
        }
        let serialized = cookieMap.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        cookieCache[host] = serialized
        UserDefaults.standard.set(cookieCache, forKey: userDefaultsKey)

        syncToSystemCookieStorage(host: host, cookieMap: cookieMap)
    }

    public func removeCookie(url: String) {
        guard let host = extractHost(url) else { return }
        lock.lock()
        defer { lock.unlock() }
        cookieCache.removeValue(forKey: host)
        UserDefaults.standard.set(cookieCache, forKey: userDefaultsKey)
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        cookieCache.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    private func extractHost(_ urlStr: String) -> String? {
        let trimmed = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let host = url.host {
            return host.lowercased()
        }
        if let url = URL(string: "https://" + trimmed), let host = url.host {
            return host.lowercased()
        }
        return nil
    }

    private func parseCookies(_ cookieStr: String) -> [String: String] {
        var map: [String: String] = [:]
        let items = cookieStr.components(separatedBy: ";")
        for item in items {
            let pair = item.components(separatedBy: "=")
            if pair.count >= 2 {
                let key = pair[0].trimmingCharacters(in: .whitespaces)
                let val = pair.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    map[key] = val
                }
            }
        }
        return map
    }

    private func syncToSystemCookieStorage(host: String, cookieMap: [String: String]) {
        for (name, val) in cookieMap {
            let properties: [HTTPCookiePropertyKey: Any] = [
                .domain: host,
                .path: "/",
                .name: name,
                .value: val,
                .secure: "TRUE",
                .expires: Date().addingTimeInterval(365 * 24 * 3600),
            ]
            if let cookie = HTTPCookie(properties: properties) {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }
}
