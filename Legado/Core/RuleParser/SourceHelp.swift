import Foundation

/// 书源帮助类 (对齐 Android Legado io.legado.app.help.source.SourceHelp.kt)
public enum SourceHelp {
    /// 调整排序序号 (避免序号超限或重复，对齐 Android SourceHelp.kt:161)
    @discardableResult
    public static func adjustSortNumber(_ sources: [BookSource]) -> [BookSource] {
        var copy = sources
        adjustSortNumber(sources: &copy)
        return copy
    }

    /// 调整排序序号 (避免序号超限或重复，对齐 Android SourceHelp.kt:161)
    public static func adjustSortNumber(sources: inout [BookSource]) {
        let orders = sources.compactMap(\.customOrder)
        let maxOrder = orders.max() ?? 0
        let minOrder = orders.min() ?? 0
        let hasDuplicate = Set(orders).count < orders.count

        if maxOrder > 99999 || minOrder < -99999 || hasDuplicate || orders.count < sources.count {
            for index in sources.indices {
                sources[index].customOrder = index
            }
        }
    }

    /// 过滤并校验是否包含 18+ 域名或分组 (对齐 Android SourceHelp.kt:143)
    public static func is18Plus(_ source: BookSource) -> Bool {
        if let group = source.bookSourceGroup, group.contains("18") || group.contains("成人") {
            return true
        }
        if source.bookSourceName.contains("福利") || source.bookSourceName.contains("18+") {
            return true
        }
        return is18Plus(source.bookSourceUrl)
    }

    /// 过滤并校验是否包含 18+ 域名
    public static func is18Plus(_ url: String?) -> Bool {
        guard let url, !url.isEmpty, let host = URL(string: url)?.host?.lowercased() else {
            return false
        }
        let parts = host.components(separatedBy: ".")
        guard parts.count >= 2 else { return false }
        let rootDomain = "\(parts[parts.count - 2]).\(parts[parts.count - 1])"
        return prohibited18PlusDomains.contains(rootDomain)
    }

    /// 清理已删除书源的内存缓存及变量
    public static func deleteBookSource(key: String) {
        CacheManager.shared.delete(key)
        CacheManager.shared.clearSourceVariables()
    }

    /// 批量清理已删除书源
    public static func deleteBookSources(sources: [BookSource]) {
        for source in sources {
            CacheManager.shared.delete(source.bookSourceUrl)
        }
        CacheManager.shared.clearSourceVariables()
    }

    /// 批量清理已删除书源片段
    public static func deleteBookSourceParts(sources: [BookSourcePart]) {
        for source in sources {
            CacheManager.shared.delete(source.bookSourceUrl)
        }
        CacheManager.shared.clearSourceVariables()
    }

    private static let prohibited18PlusDomains: Set = [
        "18comic.vip",
        "wnacg.com",
        "jmcomic.me",
    ]
}
