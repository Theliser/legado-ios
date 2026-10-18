import CryptoKit
import Foundation
import JavaScriptCore

/// JavaScript 执行沙箱引擎，深度兼容 Legado 3.0 的 JS 拓展语法 (java.ajax / java.get / java.post / java.base64 等)
public final class JSEngine {
    let context: JSContext
    var memoryStorage: [String: String] = [:]
    var sourceVariables: [String: Any] = [:]

    public init() {
        self.context = JSContext() ?? JSContext(virtualMachine: JSVirtualMachine())
        setupBridges()
    }

    /// 执行一段 JS 脚本，并传入上下文变量 (如 result, baseUrl, book, chapter 等)
    @discardableResult
    public func evaluate(
        script: String,
        bindings: [String: Any] = [:]) -> String? {
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
        if jsResult.isObject, let jsonFunc = context.objectForKeyedSubscript("JSON" as NSString)?
            .objectForKeyedSubscript("stringify" as NSString),
           let stringified = jsonFunc.call(withArguments: [jsResult]),
           !stringified.isUndefined, !stringified.isNull {
            let jsonStr = stringified.toString()
            if jsonStr != "{}" {
                return jsonStr
            }
        }

        return jsResult.toString()
    }

    private func bindSpecialObjects(from bindings: [String: Any]) {
        // 绑定 source 辅助对象
        let sourceObj = JSValue(newObjectIn: context)
        let sourceUrl = bindings["baseUrl"] as? String ?? bindings["bookSourceUrl"] as? String ?? ""
        sourceObj?.setObject(sourceUrl, forKeyedSubscript: "bookSourceUrl" as NSString)
        sourceObj?.setObject(bindings["bookSourceName"] ?? "", forKeyedSubscript: "bookSourceName" as NSString)
        sourceObj?.setObject(bindings["loginUrl"] ?? "", forKeyedSubscript: "loginUrl" as NSString)

        let getVar: @convention(block) () -> Any? = { [weak self] in
            self?.sourceVariables[sourceUrl]
        }
        let setVar: @convention(block) (JSValue) -> Void = { [weak self] value in
            self?.sourceVariables[sourceUrl] = value.toObject()
        }
        let getLoginMap: @convention(block) () -> [String: String] = {
            [:]
        }
        sourceObj?.setObject(getVar, forKeyedSubscript: "getVariable" as NSString)
        sourceObj?.setObject(setVar, forKeyedSubscript: "setVariable" as NSString)
        sourceObj?.setObject(getLoginMap, forKeyedSubscript: "getLoginInfoMap" as NSString)
        context.setObject(sourceObj, forKeyedSubscript: "source" as NSString)

        // 绑定 book 辅助对象
        let bookObj = JSValue(newObjectIn: context)
        bookObj?.setObject(bindings["bookUrl"] ?? "", forKeyedSubscript: "bookUrl" as NSString)
        bookObj?.setObject(bindings["bookName"] ?? "", forKeyedSubscript: "name" as NSString)
        bookObj?.setObject(bindings["bookAuthor"] ?? "", forKeyedSubscript: "author" as NSString)
        bookObj?.setObject(0, forKeyedSubscript: "type" as NSString)
        context.setObject(bookObj, forKeyedSubscript: "book" as NSString)
    }
}
