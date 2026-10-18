import Foundation

/// 书源连通性与可用性体检用例
public final class CheckBookSourceHealthUseCase: Sendable {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient = .shared) {
        self.httpClient = httpClient
    }

    /// 探测单个书源的可用性与网络响应耗时
    public func check(source: BookSource) async -> SourceHealthReport {
        let startTime = CFAbsoluteTimeGetCurrent()
        guard let url = URL(string: source.bookSourceUrl) else {
            return SourceHealthReport(
                sourceUrl: source.bookSourceUrl,
                sourceName: source.bookSourceName,
                isHealthy: false,
                responseTimeMs: 0,
                statusCode: nil,
                errorMessage: "书源地址格式非法")
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 6.0
            if let header = source.header,
               let data = header.data(using: .utf8),
               let headerDict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                for (key, value) in headerDict {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }

            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            if let httpResponse = response as? HTTPURLResponse {
                let isSuccess = (200 ..< 400).contains(httpResponse.statusCode)
                return SourceHealthReport(
                    sourceUrl: source.bookSourceUrl,
                    sourceName: source.bookSourceName,
                    isHealthy: isSuccess,
                    responseTimeMs: elapsedMs,
                    statusCode: httpResponse.statusCode,
                    errorMessage: isSuccess ? nil : "HTTP 状态码: \(httpResponse.statusCode)")
            } else {
                return SourceHealthReport(
                    sourceUrl: source.bookSourceUrl,
                    sourceName: source.bookSourceName,
                    isHealthy: true,
                    responseTimeMs: elapsedMs,
                    statusCode: 200)
            }
        } catch {
            let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            return SourceHealthReport(
                sourceUrl: source.bookSourceUrl,
                sourceName: source.bookSourceName,
                isHealthy: false,
                responseTimeMs: elapsedMs,
                statusCode: nil,
                errorMessage: error.localizedDescription)
        }
    }

    public typealias ProgressCallback = @Sendable (SourceHealthReport, _ completed: Int, _ total: Int) -> Void

    /// 批量并发探测多个书源，并支持实时进度回调
    public func checkBatch(
        sources: [BookSource],
        concurrency: Int = 5,
        onProgress: ProgressCallback? = nil) async -> [SourceHealthReport] {
        guard !sources.isEmpty else { return [] }

        let semaphore = AsyncSemaphore(value: max(1, concurrency))
        let total = sources.count

        return await withTaskGroup(of: SourceHealthReport.self) { group in
            for source in sources {
                group.addTask {
                    await semaphore.withPermit {
                        await self.check(source: source)
                    }
                }
            }

            var results: [SourceHealthReport] = []
            var completedCount = 0

            for await report in group {
                completedCount += 1
                results.append(report)
                onProgress?(report, completedCount, total)
            }

            return results
        }
    }
}
