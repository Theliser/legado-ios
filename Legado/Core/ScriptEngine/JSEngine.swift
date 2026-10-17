import CryptoKit
import Foundation
import JavaScriptCore

/// JavaScript 执行沙箱引擎，兼容 Legado 3.0 的 JS 拓展语法 (java.ajax / java.base64 / java.timeFormat 等)
public final class JSEngine {
    private let context: JSContext

    public init() {
        self.context = JSContext() ?? JSContext(virtualMachine: JSVirtualMachine())
        setupJavaBridge()
    }

    /// 执行一段 JS 脚本，并传入上下文变量 (如 result, baseUrl, book, chapter 等)
    @discardableResult
    public func evaluate(
        script: String,
        bindings: [String: Any] = [:]) -> String? {
        for (key, value) in bindings {
            context.setObject(value, forKeyedSubscript: key as NSString)
        }

        guard let jsResult = context.evaluateScript(script) else {
            return nil
        }

        if jsResult.isUndefined || jsResult.isNull {
            return nil
        }
        return jsResult.toString()
    }

    /// 注入 Legado 官方约定的 `java` 对象及其拓展方法
    private func setupJavaBridge() {
        guard let javaObj = JSValue(newObjectIn: context) else { return }

        // 1. java.base64Encode(string)
        let base64Encode: @convention(block) (String) -> String = { input in
            Data(input.utf8).base64EncodedString()
        }
        javaObj.setObject(base64Encode, forKeyedSubscript: "base64Encode" as NSString)

        // 2. java.base64Decode(string)
        let base64Decode: @convention(block) (String) -> String = { input in
            guard let data = Data(base64Encoded: input) else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        }
        javaObj.setObject(base64Decode, forKeyedSubscript: "base64Decode" as NSString)

        // 3. java.md5Encode(string)
        let md5Encode: @convention(block) (String) -> String = { input in
            let digest = Insecure.MD5.hash(data: Data(input.utf8))
            return digest.map { String(format: "%02hhx", $0) }.joined()
        }
        javaObj.setObject(md5Encode, forKeyedSubscript: "md5Encode" as NSString)

        // 4. java.timeFormat(timestamp)
        let timeFormat: @convention(block) (Double) -> String = { timestamp in
            let date = Date(timeIntervalSince1970: timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return formatter.string(from: date)
        }
        javaObj.setObject(timeFormat, forKeyedSubscript: "timeFormat" as NSString)

        // 5. java.log(msg)
        let log: @convention(block) (String) -> Void = { msg in
            #if DEBUG
                print("[Legado JS Log]: \(msg)")
            #endif
        }
        javaObj.setObject(log, forKeyedSubscript: "log" as NSString)

        // 挂载到全局
        context.setObject(javaObj, forKeyedSubscript: "java" as NSString)
    }
}
