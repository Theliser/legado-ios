import CryptoKit
import Foundation
import JavaScriptCore

/// JavaScript 执行沙箱引擎，深度兼容 Legado 3.0 的 JS 拓展语法 (java.ajax / java.get / java.post / java.base64 等)
public final class JSEngine {
    let context: JSContext
    var memoryStorage: [String: String] = [:]
    var sourceVariables: [String: Any] = [:]
    var currentContent = ""
    var currentBaseUrl = ""
    var currentHeaderJson: String?
    var currentSource: BookSource?

    public init() {
        self.context = JSContext() ?? JSContext(virtualMachine: JSVirtualMachine())
        setupBridges()
    }

    /// 执行一段 JS 脚本，并传入上下文变量 (如 result, baseUrl, book, chapter 等)
    @discardableResult
    public func evaluate(
        script: String,
        bindings: [String: Any] = [:]) -> String? {
        applyContextBindings(bindings)

        // 绑定外部变量
        for (key, value) in bindings {
            context.setObject(value, forKeyedSubscript: key as NSString)
        }

        // 绑定 source 与 book 对象
        bindSpecialObjects(from: bindings)

        guard let jsResult = context.evaluateScript(script) else {
            return nil
        }

        if jsResult.isUndefined || jsResult.isNull {
            return nil
        }

        // 如果结果是复杂 JS 对象或数组，转换为标准 JSON 字符串返回
        if jsResult.isObject {
            let json = context.objectForKeyedSubscript("JSON" as NSString)
            let stringify = json?.objectForKeyedSubscript("stringify" as NSString)
            if let stringified = stringify?.call(withArguments: [jsResult]),
               !stringified.isUndefined, !stringified.isNull {
                let jsonStr = stringified.toString()
                if jsonStr != "{}" {
                    return jsonStr
                }
            }
        }

        return jsResult.toString()
    }

    private func applyContextBindings(_ bindings: [String: Any]) {
        if let baseUrl = bindings["baseUrl"] as? String {
            self.currentBaseUrl = baseUrl
        }
        if let result = bindings["result"] as? String {
            self.currentContent = result
        }
        if let header = bindings["headerJson"] as? String ?? bindings["header"] as? String {
            self.currentHeaderJson = header
        }
        if let source = bindings["source"] as? BookSource {
            self.currentSource = source
            if self.currentHeaderJson == nil {
                self.currentHeaderJson = source.header
            }
            if self.currentBaseUrl.isEmpty {
                self.currentBaseUrl = source.bookSourceUrl
            }
        }
    }

    private func bindSpecialObjects(from bindings: [String: Any]) {
        let sourceUrl = bindings["baseUrl"] as? String
            ?? bindings["bookSourceUrl"] as? String
            ?? currentSource?.bookSourceUrl
            ?? ""
        let sourceName = bindings["bookSourceName"] as? String
            ?? currentSource?.bookSourceName
            ?? ""
        let loginUrl = bindings["loginUrl"] as? String
            ?? currentSource?.loginUrl
            ?? ""
        let header = currentHeaderJson ?? currentSource?.header ?? ""

        bindSourceSpecialObject(
            sourceUrl: sourceUrl,
            sourceName: sourceName,
            loginUrl: loginUrl,
            header: header,
            bindings: bindings)

        // 绑定全局 Map(key) 辅助方法 (在很多书源中如番茄小说中用来读取 key)
        let mapFunc: @convention(block) (String) -> String = { [weak self] key in
            self?.memoryStorage[key] ?? ""
        }
        context.setObject(mapFunc, forKeyedSubscript: "Map" as NSString)

        bindBookSpecialObject(bindings: bindings)
        bindChapterSpecialObject(bindings: bindings)
    }

    private func bindSourceSpecialObject(
        sourceUrl: String,
        sourceName: String,
        loginUrl: String,
        header: String,
        bindings: [String: Any]) {
        let sourceObj = JSValue(newObjectIn: context)
        sourceObj?.setObject(sourceUrl, forKeyedSubscript: "bookSourceUrl" as NSString)
        sourceObj?.setObject(sourceName, forKeyedSubscript: "bookSourceName" as NSString)
        sourceObj?.setObject(loginUrl, forKeyedSubscript: "loginUrl" as NSString)
        sourceObj?.setObject(header, forKeyedSubscript: "header" as NSString)

        let getVar: @convention(block) (JSValue?) -> Any? = { [weak self] keyVal in
            guard let self else { return nil }
            if let varKey = keyVal?.toString(), !varKey.isEmpty, varKey != "undefined", varKey != "null" {
                return self.sourceVariables["\(sourceUrl)_\(varKey)"] ?? self.sourceVariables[varKey]
            }
            return self.sourceVariables[sourceUrl]
        }
        let setVar: @convention(block) (JSValue, JSValue?) -> Void = { [weak self] arg1, arg2 in
            guard let self else { return }
            if let arg2, !arg2.isUndefined, !arg2.isNull {
                let key = arg1.toString() ?? ""
                self.sourceVariables["\(sourceUrl)_\(key)"] = arg2.toObject()
            } else {
                self.sourceVariables[sourceUrl] = arg1.toObject()
            }
        }
        let getKey: @convention(block) () -> String = { sourceUrl }
        let getHeaderMap: @convention(block) () -> [String: String] = { [weak self] in
            guard let self else { return [:] }
            let hJson = self.currentHeaderJson ?? (bindings["header"] as? String) ?? ""
            return AnalyzeUrl.parseHeaderJson(hJson, baseUrl: sourceUrl)
        }

        sourceObj?.setObject(getVar, forKeyedSubscript: "getVariable" as NSString)
        sourceObj?.setObject(setVar, forKeyedSubscript: "setVariable" as NSString)
        sourceObj?.setObject(getKey, forKeyedSubscript: "getKey" as NSString)
        sourceObj?.setObject(getKey, forKeyedSubscript: "getTag" as NSString)
        sourceObj?.setObject(getHeaderMap, forKeyedSubscript: "getHeaderMap" as NSString)
        sourceObj?.setObject(getKey, forKeyedSubscript: "getLoginHeader" as NSString)
        context.setObject(sourceObj, forKeyedSubscript: "source" as NSString)
    }

    private func bindBookSpecialObject(bindings: [String: Any]) {
        let bookObj = JSValue(newObjectIn: context)
        bookObj?.setObject(bindings["bookUrl"] ?? "", forKeyedSubscript: "bookUrl" as NSString)
        bookObj?.setObject(bindings["bookName"] ?? "", forKeyedSubscript: "name" as NSString)
        bookObj?.setObject(bindings["bookAuthor"] ?? "", forKeyedSubscript: "author" as NSString)
        bookObj?.setObject(0, forKeyedSubscript: "type" as NSString)
        context.setObject(bookObj, forKeyedSubscript: "book" as NSString)
    }

    private func bindChapterSpecialObject(bindings: [String: Any]) {
        let chapterObj = JSValue(newObjectIn: context)
        let chapterTitle = (bindings["title"] as? String) ?? (bindings["chapterTitle"] as? String) ?? ""
        let chapterUrl = (bindings["chapterUrl"] as? String) ?? ""
        let chapterIndex = (bindings["chapterIndex"] as? Int) ?? 0

        chapterObj?.setObject(chapterTitle, forKeyedSubscript: "title" as NSString)
        chapterObj?.setObject(chapterUrl, forKeyedSubscript: "url" as NSString)
        chapterObj?.setObject(chapterIndex, forKeyedSubscript: "index" as NSString)

        let getVar: @convention(block) (JSValue?) -> Any? = { [weak self] keyVal in
            guard let self else { return nil }
            let key = keyVal?.toString() ?? ""
            return self.memoryStorage["ch_\(chapterUrl)_\(key)"] ?? self.memoryStorage[key]
        }
        let setVar: @convention(block) (JSValue, JSValue?) -> Void = { [weak self] arg1, arg2 in
            guard let self else { return }
            if let arg2, !arg2.isUndefined, !arg2.isNull {
                let key = arg1.toString() ?? ""
                self.memoryStorage["ch_\(chapterUrl)_\(key)"] = arg2.toString()
            } else {
                self.memoryStorage["ch_\(chapterUrl)"] = arg1.toString()
            }
        }
        chapterObj?.setObject(getVar, forKeyedSubscript: "getVariable" as NSString)
        chapterObj?.setObject(setVar, forKeyedSubscript: "setVariable" as NSString)
        chapterObj?.setObject(setVar, forKeyedSubscript: "putVariable" as NSString)
        context.setObject(chapterObj, forKeyedSubscript: "chapter" as NSString)

        if let title = bindings["title"] as? String {
            context.setObject(title, forKeyedSubscript: "title" as NSString)
        }
        if let src = bindings["src"] as? String {
            context.setObject(src, forKeyedSubscript: "src" as NSString)
        }
        if let nextChapterUrl = bindings["nextChapterUrl"] as? String {
            context.setObject(nextChapterUrl, forKeyedSubscript: "nextChapterUrl" as NSString)
        }
        if let fromBookInfo = bindings["fromBookInfo"] as? Bool {
            context.setObject(fromBookInfo, forKeyedSubscript: "fromBookInfo" as NSString)
        }
    }
}
