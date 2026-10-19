import Foundation

/// 基础源抽象协议与通用能力扩展 (对齐 Android Legado BaseSource.kt)
public protocol BaseSource: Sendable {
    var concurrentRate: String? { get set }
    var loginUrl: String? { get set }
    var loginUi: String? { get set }
    var header: String? { get set }
    var enabledCookieJar: Bool? { get set }
    var jsLib: String? { get set }

    func getTag() -> String
    func getKey() -> String
}

public extension BaseSource {
    func getLoginJs() -> String? {
        guard let login = loginUrl else { return nil }
        if login.hasPrefix("@js:") {
            return String(login.dropFirst(4))
        } else if login.hasPrefix("<js>") {
            let startIdx = login.index(login.startIndex, offsetBy: 4)
            if let endIdx = login.range(of: "</js>") {
                return String(login[startIdx ..< endIdx.lowerBound])
            }
            return String(login[startIdx...])
        }
        return login
    }

    func getLoginHeader() -> String? {
        CacheManager.shared.get("loginHeader_\(getKey())")
    }

    func getLoginHeaderMap() -> [String: String]? {
        guard let cache = getLoginHeader(),
              let data = cache.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        var map: [String: String] = [:]
        for (key, value) in dict {
            map[key] = "\(value)"
        }
        return map
    }

    func putLoginHeader(_ headerStr: String) {
        if let data = headerStr.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let cookie = (dict["Cookie"] as? String) ?? (dict["cookie"] as? String)
            if let cookie {
                CookieStore.shared.replaceCookie(url: getKey(), cookie: cookie)
            }
        }
        CacheManager.shared.put("loginHeader_\(getKey())", headerStr)
    }

    func removeLoginHeader() {
        CacheManager.shared.delete("loginHeader_\(getKey())")
        CookieStore.shared.removeCookie(url: getKey())
    }

    func setVariable(_ variable: String?) {
        putVariable(variable)
    }

    func putVariable(_ variable: String?) {
        if let variable {
            CacheManager.shared.put("sourceVariable_\(getKey())", variable)
        } else {
            CacheManager.shared.delete("sourceVariable_\(getKey())")
        }
    }

    func getVariable() -> String {
        CacheManager.shared.get("sourceVariable_\(getKey())") ?? ""
    }

    func put(key: String, value: String) -> String {
        CacheManager.shared.put("v_\(getKey())_\(key)", value)
        return value
    }

    func get(key: String) -> String {
        CacheManager.shared.get("v_\(getKey())_\(key)") ?? ""
    }
}
