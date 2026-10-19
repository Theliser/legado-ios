import Foundation

/// 书源轻量投影模型 (对齐 Android Legado BookSourcePart.kt / book_sources_part 视图)
public struct BookSourcePart: Identifiable, Codable, Equatable, Sendable {
    public var id: String {
        bookSourceUrl
    }

    public var bookSourceUrl: String
    public var bookSourceName: String
    public var bookSourceGroup: String?
    public var customOrder: Int
    public var enabled: Bool
    public var enabledExplore: Bool
    public var hasLoginUrl: Bool
    public var lastUpdateTime: Int64
    public var respondTime: Int64
    public var weight: Int
    public var hasExploreUrl: Bool

    public init(
        bookSourceUrl: String = "",
        bookSourceName: String = "",
        bookSourceGroup: String? = nil,
        customOrder: Int = 0,
        enabled: Bool = true,
        enabledExplore: Bool = true,
        hasLoginUrl: Bool = false,
        lastUpdateTime: Int64 = 0,
        respondTime: Int64 = 180_000,
        weight: Int = 0,
        hasExploreUrl: Bool = false) {
        self.bookSourceUrl = bookSourceUrl
        self.bookSourceName = bookSourceName
        self.bookSourceGroup = bookSourceGroup
        self.customOrder = customOrder
        self.enabled = enabled
        self.enabledExplore = enabledExplore
        self.hasLoginUrl = hasLoginUrl
        self.lastUpdateTime = lastUpdateTime
        self.respondTime = respondTime
        self.weight = weight
        self.hasExploreUrl = hasExploreUrl
    }

    public init(source: BookSource) {
        let hasLogin = !(source.loginUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasExplore = !(source.exploreUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        self.init(
            bookSourceUrl: source.bookSourceUrl,
            bookSourceName: source.bookSourceName,
            bookSourceGroup: source.bookSourceGroup,
            customOrder: source.customOrder ?? 0,
            enabled: source.enabled ?? true,
            enabledExplore: source.enabledExplore ?? true,
            hasLoginUrl: hasLogin,
            lastUpdateTime: source.lastUpdateTime ?? 0,
            respondTime: source.respondTime ?? 180_000,
            weight: source.weight ?? 0,
            hasExploreUrl: hasExplore)
    }

    public init(from source: BookSource) {
        self.init(source: source)
    }

    public func getDisplayNameGroup() -> String {
        guard let group = bookSourceGroup, !group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return bookSourceName
        }
        return "\(bookSourceName) (\(group))"
    }

    public mutating func addGroup(_ groups: String) {
        var groupSet = Set(
            (bookSourceGroup ?? "")
                .components(separatedBy: CharacterSet(charactersIn: ",;，； \t\n"))
                .filter { !$0.isEmpty })
        let newGroups = groups
            .components(separatedBy: CharacterSet(charactersIn: ",;，； \t\n"))
            .filter { !$0.isEmpty }
        groupSet.formUnion(newGroups)
        bookSourceGroup = groupSet.sorted().joined(separator: ",")
    }

    public mutating func removeGroup(_ groups: String) {
        var groupSet = Set(
            (bookSourceGroup ?? "")
                .components(separatedBy: CharacterSet(charactersIn: ",;，； \t\n"))
                .filter { !$0.isEmpty })
        let removeGroups = Set(
            groups
                .components(separatedBy: CharacterSet(charactersIn: ",;，； \t\n"))
                .filter { !$0.isEmpty })
        groupSet.subtract(removeGroups)
        bookSourceGroup = groupSet.sorted().joined(separator: ",")
    }
}
