import Foundation

/// 书源实时规则调试用例
public final class DebugBookSourceUseCase: Sendable {
    private let searchService: SourceSearchService

    public init(searchService: SourceSearchService = .shared) {
        self.searchService = searchService
    }

    /// 执行书源搜索规则测试并产生实时诊断报告
    public func execute(source: BookSource, keyword: String) async -> SourceDebugReport {
        let startTime = Date()
        var logs: [SourceDebugLog] = []

        logs.append(SourceDebugLog(level: .info, message: "开始调试书源: \(source.bookSourceName)"))
        logs.append(SourceDebugLog(level: .info, message: "书源地址: \(source.bookSourceUrl)"))
        logs.append(SourceDebugLog(level: .info, message: "测试关键字: \(keyword)"))

        // 校验搜索规则配置
        guard let ruleSearch = source.ruleSearch,
              let searchUrl = source.searchUrl, !searchUrl.isEmpty else {
            logs.append(SourceDebugLog(level: .error, message: "书源缺少 searchUrl 或 ruleSearch 配置"))
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            return SourceDebugReport(
                sourceName: source.bookSourceName,
                isSuccess: false,
                durationMs: elapsed,
                logs: logs)
        }

        logs.append(SourceDebugLog(level: .info, message: "搜索规则 URL: \(searchUrl)"))
        if let bookList = ruleSearch.bookList {
            logs.append(SourceDebugLog(level: .info, message: "列表选择器: \(bookList)"))
        }

        do {
            let results = try await searchService.search(source: source, keyword: keyword)
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)

            if results.isEmpty {
                logs.append(SourceDebugLog(level: .warning, message: "网络请求成功，但未解析出匹配的书籍 (耗时 \(elapsed)ms)"))
                return SourceDebugReport(
                    sourceName: source.bookSourceName,
                    isSuccess: false,
                    durationMs: elapsed,
                    logs: logs)
            }

            logs.append(SourceDebugLog(level: .success, message: "成功解析出 \(results.count) 条书籍结果 (耗时 \(elapsed)ms)"))
            if let first = results.first {
                logs.append(SourceDebugLog(level: .success, message: "样例书名: \(first.name) | 作者: \(first.author)"))
                logs.append(SourceDebugLog(level: .info, message: "详情 URL: \(first.bookUrl)"))
            }

            return SourceDebugReport(
                sourceName: source.bookSourceName,
                isSuccess: true,
                durationMs: elapsed,
                logs: logs,
                sampleResult: results.first)
        } catch {
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            logs.append(SourceDebugLog(
                level: .error,
                message: "调试发生异常: \(error.localizedDescription) (耗时 \(elapsed)ms)"))
            return SourceDebugReport(
                sourceName: source.bookSourceName,
                isSuccess: false,
                durationMs: elapsed,
                logs: logs)
        }
    }
}
