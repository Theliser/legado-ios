import CryptoKit
import Foundation

/// 书源发现分类提取与缓存扩展 (对齐 Android Legado BookSourceExtensions.kt)
public actor BookSourceExploreCache {
    public static let shared = BookSourceExploreCache()

    private var memoryCache: [String: [ExploreKind]] = [:]

    public func get(key: String) -> [ExploreKind]? {
        memoryCache[key]
    }

    public func set(key: String, kinds: [ExploreKind]) {
        memoryCache[key] = kinds
    }

    public func remove(key: String) {
        memoryCache.removeValue(forKey: key)
    }

    public func clear() {
        memoryCache.removeAll()
    }
}

public extension BookSource {
    func getExploreKindsKey() -> String {
        let raw = "\(bookSourceUrl)\(exploreUrl ?? "")"
        let digest = Insecure.MD5.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    func exploreKinds() async -> [ExploreKind] {
        guard let exploreUrl = exploreUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !exploreUrl.isEmpty else {
            return []
        }

        let cacheKey = getExploreKindsKey()
        if let cached = await BookSourceExploreCache.shared.get(key: cacheKey) {
            return cached
        }

        var ruleStr = exploreUrl
        if exploreUrl.hasPrefix("<js>") || exploreUrl.hasPrefix("@js:") {
            if let cachedDisk = CacheManager.shared.get("explore_\(cacheKey)"), !cachedDisk.isEmpty {
                ruleStr = cachedDisk
            } else {
                let jsStr: String
                if exploreUrl.hasPrefix("@") {
                    jsStr = String(exploreUrl.dropFirst(4))
                } else if let endIdx = exploreUrl.range(of: "</js>") {
                    let startIdx = exploreUrl.index(exploreUrl.startIndex, offsetBy: 4)
                    jsStr = String(exploreUrl[startIdx ..< endIdx.lowerBound])
                } else {
                    jsStr = exploreUrl
                }

                let engine = JSEngine()
                let evaluated = engine.evaluate(script: jsStr, bindings: [
                    "baseUrl": bookSourceUrl,
                    "source": self,
                ])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if !evaluated.isEmpty {
                    ruleStr = evaluated
                    CacheManager.shared.put("explore_\(cacheKey)", evaluated)
                }
            }
        }

        var kinds: [ExploreKind] = []
        let trimmedRule = ruleStr.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedRule.hasPrefix("["), trimmedRule.hasSuffix("]"), let data = trimmedRule.data(using: .utf8),
           let parsedKinds = try? JSONDecoder().decode([ExploreKind].self, from: data) {
            kinds = parsedKinds
        }

        if kinds.isEmpty {
            let entries = trimmedRule.components(separatedBy: CharacterSet(charactersIn: "\n&"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for entry in entries {
                let parts = entry.components(separatedBy: "::")
                let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let urlStr = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                kinds.append(ExploreKind(title: title, url: urlStr))
            }
        }

        await BookSourceExploreCache.shared.set(key: cacheKey, kinds: kinds)
        return kinds
    }

    func clearExploreKindsCache() async {
        let cacheKey = getExploreKindsKey()
        await BookSourceExploreCache.shared.remove(key: cacheKey)
        CacheManager.shared.delete("explore_\(cacheKey)")
    }
}
