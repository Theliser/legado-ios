import Foundation

public extension AnalyzeUrl {
    init(
        mUrl: String,
        key: String? = nil,
        page: Int? = 1,
        baseUrl: String? = nil,
        source: BookSource? = nil,
        ruleData _: RuleDataInterface? = nil,
        chapter _: Chapter? = nil,
        book: Book? = nil) throws {
        let base = baseUrl ?? source?.bookSourceUrl ?? book?.bookUrl ?? ""
        let ctx = AnalyzeUrlContext(
            key: key,
            page: page,
            baseUrl: base,
            headerJson: source?.header,
            source: source,
            book: book)
        try self.init(rawUrl: mUrl, context: ctx)
    }

    /// 异步获取响应正文与元数据 (对齐 Android Legado AnalyzeUrl.getStrResponseAwait)
    func getStrResponseAwait(
        httpClient: HTTPClientProtocol = HTTPClient.shared,
        jsStr: String? = nil,
        sourceRegex _: String? = nil) async throws -> StrResponse {
        let response = try await httpClient.fetchStrResponse(analyzeUrl: self)
        if let jsStr, !jsStr.isEmpty {
            let engine = JSEngine()
            if let transformed = engine.evaluate(script: jsStr, bindings: [
                "result": response.body ?? "",
                "baseUrl": response.url,
            ]) {
                response.body = transformed
            }
        }
        return response
    }

    /// 执行动态 JavaScript 脚本 (对齐 Android Legado AnalyzeUrl.evalJS)
    func evalJS(_ jsStr: String, result: Any? = nil) -> Any? {
        let engine = JSEngine()
        var bindings: [String: Any] = [
            "baseUrl": url.absoluteString,
            "key": context.key ?? "",
            "page": context.page ?? 1,
        ]
        if let res = result as? StrResponse {
            bindings["result"] = res.body ?? ""
        } else if let result {
            bindings["result"] = result
        }
        if let source = context.source {
            bindings["source"] = source
        }
        if let book = context.book {
            bindings["book"] = book
        }
        let output = engine.evaluate(script: jsStr, bindings: bindings)
        if let output, let strRes = result as? StrResponse {
            strRes.body = output
            return strRes
        }
        return output
    }
}
