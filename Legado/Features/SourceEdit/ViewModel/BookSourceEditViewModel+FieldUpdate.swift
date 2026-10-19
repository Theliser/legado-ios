import Foundation

extension BookSourceEditViewModel {
    func handleUpdateField(key: String, value: String) {
        updateState { state in
            state.activeFieldKey = key
            if key.hasPrefix("ruleSearch.") || key == "searchUrl" {
                self.updateSearchField(state: &state, key: key, value: value)
            } else if key.hasPrefix("ruleExplore.") || key == "exploreUrl" {
                self.updateExploreField(state: &state, key: key, value: value)
            } else if key.hasPrefix("ruleBookInfo.") {
                self.updateInfoField(state: &state, key: key, value: value)
            } else if key.hasPrefix("ruleToc.") {
                self.updateTocField(state: &state, key: key, value: value)
            } else if key.hasPrefix("ruleContent.") {
                self.updateContentField(state: &state, key: key, value: value)
            } else if key.hasPrefix("ruleReview.") {
                self.updateReviewField(state: &state, key: key, value: value)
            } else {
                self.updateBaseField(state: &state, key: key, value: value)
            }
            state.isDirty = true
        }
    }

    func handleInsertSyntaxChip(_ token: String) {
        guard let key = state.activeFieldKey else {
            emitEffect(.showToast("请先选择要插入的字段输入框"))
            return
        }
        let currentVal = state.fieldValue(for: key)
        let newVal = currentVal.isEmpty ? token : "\(currentVal)\(token)"
        handleUpdateField(key: key, value: newVal)
        emitEffect(.hapticFeedback)
    }

    func handleToggleBoolean(key: String, value: Bool) {
        updateState {
            if key == "enabled" {
                $0.source.enabled = value
            } else if key == "enabledExplore" {
                $0.source.enabledExplore = value
            }
            $0.isDirty = true
        }
        emitEffect(.hapticFeedback)
    }

    // MARK: - 分组字段更新辅助

    private func updateBaseField(state: inout BookSourceEditState, key: String, value: String) {
        switch key {
        case "bookSourceName": state.source.bookSourceName = value
        case "bookSourceUrl": state.source.bookSourceUrl = value
        case "bookSourceGroup": state.source.bookSourceGroup = value.isEmpty ? nil : value
        case "bookSourceComment": state.source.bookSourceComment = value.isEmpty ? nil : value
        case "loginUrl": state.source.loginUrl = value.isEmpty ? nil : value
        case "header": state.source.header = value.isEmpty ? nil : value
        case "bookUrlPattern": state.source.bookUrlPattern = value.isEmpty ? nil : value
        default: break
        }
    }

    private func updateSearchField(state: inout BookSourceEditState, key: String, value: String) {
        if key == "searchUrl" {
            state.source.searchUrl = value.isEmpty ? nil : value
            return
        }
        var rule = state.source.ruleSearch ?? RuleSearch()
        let val = value.isEmpty ? nil : value
        if !applySearchPrimaryRule(&rule, key: key, val: val) {
            applySearchSecondaryRule(&rule, key: key, val: val)
        }
        state.source.ruleSearch = rule
    }

    private func applySearchPrimaryRule(_ rule: inout RuleSearch, key: String, val: String?) -> Bool {
        switch key {
        case "ruleSearch.checkKeyWord": rule.checkKeyWord = val
        case "ruleSearch.bookList": rule.bookList = val
        case "ruleSearch.name": rule.name = val
        case "ruleSearch.author": rule.author = val
        case "ruleSearch.kind": rule.kind = val
        default: return false
        }
        return true
    }

    private func applySearchSecondaryRule(_ rule: inout RuleSearch, key: String, val: String?) {
        switch key {
        case "ruleSearch.wordCount": rule.wordCount = val
        case "ruleSearch.lastChapter": rule.lastChapter = val
        case "ruleSearch.intro": rule.intro = val
        case "ruleSearch.coverUrl": rule.coverUrl = val
        case "ruleSearch.bookUrl": rule.bookUrl = val
        default: break
        }
    }

    private func updateExploreField(state: inout BookSourceEditState, key: String, value: String) {
        if key == "exploreUrl" {
            state.source.exploreUrl = value.isEmpty ? nil : value
            return
        }
        var rule = state.source.ruleExplore ?? RuleExplore()
        let val = value.isEmpty ? nil : value
        if !applyExplorePrimaryRule(&rule, key: key, val: val) {
            applyExploreSecondaryRule(&rule, key: key, val: val)
        }
        state.source.ruleExplore = rule
    }

    private func applyExplorePrimaryRule(_ rule: inout RuleExplore, key: String, val: String?) -> Bool {
        switch key {
        case "ruleExplore.bookList": rule.bookList = val
        case "ruleExplore.name": rule.name = val
        case "ruleExplore.author": rule.author = val
        case "ruleExplore.kind": rule.kind = val
        default: return false
        }
        return true
    }

    private func applyExploreSecondaryRule(_ rule: inout RuleExplore, key: String, val: String?) {
        switch key {
        case "ruleExplore.wordCount": rule.wordCount = val
        case "ruleExplore.lastChapter": rule.lastChapter = val
        case "ruleExplore.intro": rule.intro = val
        case "ruleExplore.coverUrl": rule.coverUrl = val
        case "ruleExplore.bookUrl": rule.bookUrl = val
        default: break
        }
    }

    private func updateInfoField(state: inout BookSourceEditState, key: String, value: String) {
        var rule = state.source.ruleBookInfo ?? RuleBookInfo()
        let val = value.isEmpty ? nil : value
        if !applyInfoPrimaryRule(&rule, key: key, val: val) {
            applyInfoSecondaryRule(&rule, key: key, val: val)
        }
        state.source.ruleBookInfo = rule
    }

    private func applyInfoPrimaryRule(_ rule: inout RuleBookInfo, key: String, val: String?) -> Bool {
        switch key {
        case "ruleBookInfo.init": rule.bookInfoInit = val
        case "ruleBookInfo.name": rule.name = val
        case "ruleBookInfo.author": rule.author = val
        case "ruleBookInfo.kind": rule.kind = val
        case "ruleBookInfo.wordCount": rule.wordCount = val
        default: return false
        }
        return true
    }

    private func applyInfoSecondaryRule(_ rule: inout RuleBookInfo, key: String, val: String?) {
        switch key {
        case "ruleBookInfo.lastChapter": rule.lastChapter = val
        case "ruleBookInfo.intro": rule.intro = val
        case "ruleBookInfo.coverUrl": rule.coverUrl = val
        case "ruleBookInfo.tocUrl": rule.tocUrl = val
        case "ruleBookInfo.canReName": rule.canReName = val
        default: break
        }
    }

    private func updateTocField(state: inout BookSourceEditState, key: String, value: String) {
        var rule = state.source.ruleToc ?? RuleToc()
        let val = value.isEmpty ? nil : value
        switch key {
        case "ruleToc.chapterList": rule.chapterList = val
        case "ruleToc.chapterName": rule.chapterName = val
        case "ruleToc.chapterUrl": rule.chapterUrl = val
        case "ruleToc.isVip": rule.isVip = val
        case "ruleToc.updateTime": rule.updateTime = val
        case "ruleToc.nextTocUrl": rule.nextTocUrl = val
        default: break
        }
        state.source.ruleToc = rule
    }

    private func updateContentField(state: inout BookSourceEditState, key: String, value: String) {
        var rule = state.source.ruleContent ?? RuleContent()
        let val = value.isEmpty ? nil : value
        switch key {
        case "ruleContent.content": rule.content = val
        case "ruleContent.nextContentUrl": rule.nextContentUrl = val
        case "ruleContent.sourceRegex": rule.sourceRegex = val
        case "ruleContent.webJs": rule.webJs = val
        default: break
        }
        state.source.ruleContent = rule
    }

    private func updateReviewField(state: inout BookSourceEditState, key: String, value: String) {
        var rule = state.source.ruleReview ?? RuleReview()
        let val = value.isEmpty ? nil : value
        switch key {
        case "ruleReview.reviewUrl": rule.reviewUrl = val
        case "ruleReview.contentRule": rule.contentRule = val
        case "ruleReview.avatarRule": rule.avatarRule = val
        case "ruleReview.postTimeRule": rule.postTimeRule = val
        default: break
        }
        state.source.ruleReview = rule
    }
}
