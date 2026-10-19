import Foundation

public extension BookSource {
    mutating func addGroup(_ groups: String) {
        var currentSet = Set(
            (bookSourceGroup ?? "")
                .components(separatedBy: CharacterSet(charactersIn: ",;，； \t\n"))
                .filter { !$0.isEmpty })
        let newGroups = groups
            .components(separatedBy: CharacterSet(charactersIn: ",;，； \t\n"))
            .filter { !$0.isEmpty }
        currentSet.formUnion(newGroups)
        bookSourceGroup = currentSet.sorted().joined(separator: ",")
    }

    mutating func removeGroup(_ groups: String) {
        guard let group = bookSourceGroup else { return }
        var currentSet = Set(
            group
                .components(separatedBy: CharacterSet(charactersIn: ",;，； \t\n"))
                .filter { !$0.isEmpty })
        let toRemove = Set(
            groups
                .components(separatedBy: CharacterSet(charactersIn: ",;，； \t\n"))
                .filter { !$0.isEmpty })
        currentSet.subtract(toRemove)
        bookSourceGroup = currentSet.isEmpty ? nil : currentSet.sorted().joined(separator: ",")
    }

    func hasGroup(_ group: String) -> Bool {
        guard let bookSourceGroup else { return false }
        let groups = bookSourceGroup
            .components(separatedBy: CharacterSet(charactersIn: ",;，； \t\n"))
            .filter { !$0.isEmpty }
        return groups.contains(group)
    }

    mutating func removeInvalidGroups() {
        let invalidNames = getInvalidGroupNames()
        if !invalidNames.isEmpty {
            removeGroup(invalidNames)
        }
    }

    mutating func removeErrorComment() {
        guard let comment = bookSourceComment else { return }
        let filtered = comment
            .components(separatedBy: "\n\n")
            .filter { !$0.hasPrefix("// Error: ") }
        bookSourceComment = filtered.isEmpty ? nil : filtered.joined(separator: "\n")
    }

    mutating func addErrorComment(_ error: String) {
        let prefix = "// Error: \(error)"
        if let comment = bookSourceComment, !comment.isEmpty {
            bookSourceComment = "\(prefix)\n\n\(comment)"
        } else {
            bookSourceComment = prefix
        }
    }

    mutating func addErrorComment(_ error: Error) {
        addErrorComment(error.localizedDescription)
    }

    func getCheckKeyword(default def: String = "系统") -> String {
        if let keyword = ruleSearch?.checkKeyWord,
           !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !keyword.contains("http"),
           !keyword.contains("::"),
           !keyword.contains("++"),
           !keyword.contains("--") {
            return keyword
        }
        return def
    }

    func getInvalidGroupNames() -> String {
        guard let group = bookSourceGroup else { return "" }
        let invalids = group
            .components(separatedBy: CharacterSet(charactersIn: ",;，； \t\n"))
            .filter { $0.contains("失效") || $0 == "校验超时" }
        return invalids.joined(separator: ",")
    }

    func getDisplayVariableComment(otherComment: String) -> String {
        guard let variable = variableComment, !variable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return otherComment
        }
        return "\(variable)\n\(otherComment)"
    }

    func equal(to other: BookSource) -> Bool {
        bookSourceName == other.bookSourceName
            && bookSourceUrl == other.bookSourceUrl
            && bookSourceGroup == other.bookSourceGroup
            && bookSourceType == other.bookSourceType
            && bookUrlPattern == other.bookUrlPattern
            && bookSourceComment == other.bookSourceComment
            && customOrder == other.customOrder
            && enabled == other.enabled
            && enabledExplore == other.enabledExplore
            && enabledCookieJar == other.enabledCookieJar
            && variableComment == other.variableComment
            && concurrentRate == other.concurrentRate
            && jsLib == other.jsLib
            && header == other.header
            && loginUrl == other.loginUrl
            && loginUi == other.loginUi
            && loginCheckJs == other.loginCheckJs
            && coverDecodeJs == other.coverDecodeJs
            && homepageModules == other.homepageModules
            && exploreUrl == other.exploreUrl
            && searchUrl == other.searchUrl
            && ruleSearch == other.ruleSearch
            && ruleExplore == other.ruleExplore
            && ruleBookInfo == other.ruleBookInfo
            && ruleToc == other.ruleToc
            && ruleContent == other.ruleContent
    }
}
