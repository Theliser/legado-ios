import Foundation
@testable import Legado
import Testing

@Suite("Real Book Source Import and Debug Suite")
struct RealBookSourceTests {
    /// 真实书源 1: 酷我小说 (来自 aoaostar/legado，无需登录，API JSON 源)
    let kuwoSourceJson = """
    {
      "bookSourceGroup": "API",
      "bookSourceName": "酷我小说",
      "bookSourceType": 0,
      "bookSourceUrl": "http://appi.kuwo.cn",
      "customOrder": 4,
      "enabled": true,
      "enabledCookieJar": true,
      "enabledExplore": false,
      "header": "{\\n\\t\\"Accept\\": \\"*/*\\",\\n\\t\\"Connection\\": \\"Close\\",\\n\\t\\"User-Agent\\": \\"Dalvik/2.1.0 (Linux; U; Android 8.0.0; LND-AL40 Build/HONORLND-AL40)\\"\\n}",
      "lastUpdateTime": 1713846723225,
      "respondTime": 5653,
      "ruleBookInfo": {
        "author": "$.author_name",
        "coverUrl": "$.cover_url",
        "init": "$.data",
        "intro": "$.intro##(^|[。！？]+[”」）】]?)##$1<br>",
        "kind": "{{$.category_name}},{{$.status}},{{$.update_time}}@js:result.replace(/30/,\\"连载\\").replace(/50/,\\"完结\\").replace(/\\\\s..:.*/,\\"\\")",
        "lastChapter": "$.new_chapter_name##正文卷.|正文.|VIP卷.|默认卷.|卷_|VIP章节.|免费章节.|章节目录.|最新章节.|[\\\\(（【].*?[求更票谢乐发订合补加架字修Kk].*?[】）\\\\)]",
        "name": "$.title",
        "tocUrl": "/novels/api/book/{{$.book_id}}/chapters?paging=0",
        "wordCount": "$.all_words"
      },
      "ruleContent": {
        "content": "$.data.content"
      },
      "ruleExplore": {},
      "ruleSearch": {
        "author": "$.author_name",
        "bookList": "$.data",
        "bookUrl": "/novels/api/book/{{$.book_id}}",
        "coverUrl": "$.cover_url",
        "intro": "$.intro",
        "kind": "{{$.category_name}},{{$.status}}@js:result.replace(/30/,\\"连载\\").replace(/50/,\\"完结\\")",
        "name": "$.title",
        "wordCount": "$.all_words"
      },
      "ruleToc": {
        "chapterList": "$.data",
        "chapterName": "$.chapter_title##正文卷.|正文.|VIP卷.|默认卷.|卷_|VIP章节.|免费章节.|章节目录.|最新章节.|[\\\\(（【].*?[求更票谢乐发订合补加架字修Kk].*?[】）\\\\)]",
        "chapterUrl": "/novels/api/book/{{$.book_id}}/chapters/{{$.chapter_id}}",
        "updateTime": "{{$.volume_name}}•{{$.original_words}}字"
      },
      "searchUrl": "/novels/api/book/search?keyword={{key}}&pi={{page}}&ps=30",
      "weight": 50
    }
    """

    @Test("Test Parsing Real Book Source JSON (Kuwo)")
    func parseRealKuwoSource() throws {
        let parser = ParseBookSourceUseCase()
        let sources = try parser.parse(json: kuwoSourceJson)

        #expect(sources.count == 1)
        let source = sources[0]
        #expect(source.bookSourceName == "酷我小说")
        #expect(source.bookSourceUrl == "http://appi.kuwo.cn")
        #expect(source.searchUrl?.contains("/novels/api/book/search") == true)
        #expect(source.ruleSearch?.bookList == "$.data")
        #expect(source.ruleSearch?.name == "$.title")
        #expect(source.ruleSearch?.author == "$.author_name")
    }

    @Test("Test Real Book Source Debugging Console (Kuwo Search & Rule Execution)")
    func debugRealKuwoSource() async throws {
        let parser = ParseBookSourceUseCase()
        let sources = try parser.parse(json: kuwoSourceJson)
        #expect(!sources.isEmpty)
        let source = sources[0]

        let debugUseCase = DebugBookSourceUseCase()
        let report = await debugUseCase.execute(source: source, keyword: "斗罗大陆")

        print("--- 酷我书源调试诊断报告 ---")
        print("书源: \(report.sourceName) | 是否通过: \(report.isSuccess) | 耗时: \(report.durationMs)ms")
        for log in report.logs {
            print("[\(log.level.rawValue)] \(log.message)")
        }
        if let sample = report.sampleResult {
            print("抓取样例: 《\(sample.name)》 作者: \(sample.author) | URL: \(sample.bookUrl)")
        }
        print("----------------------------")

        #expect(report.isSuccess == true)
        #expect(report.sampleResult != nil)
        #expect(report.sampleResult?.name.contains("斗罗大陆") == true)
    }

    @Test("Test Real Book Source Debugging Direct Targets (TOC & Content & Streaming)")
    func kuwoDebugDirectTargets() async throws {
        let parser = ParseBookSourceUseCase()
        let sources = try parser.parse(json: kuwoSourceJson)
        #expect(!sources.isEmpty)
        let source = sources[0]

        let debugUseCase = DebugBookSourceUseCase()

        // 1. 测试示例生成
        let examples = debugUseCase.generateExamples(for: source)
        #expect(!examples.isEmpty)
        #expect(examples.contains { $0.target == .search })

        // 2. 测试直接调试正文页 (Target = .content)
        final class LogCollector: @unchecked Sendable {
            private let lock = NSLock()
            private(set) var logs: [SourceDebugLog] = []
            func append(_ log: SourceDebugLog) {
                lock.lock()
                defer { lock.unlock() }
                logs.append(log)
            }
        }
        let collector = LogCollector()
        let contentReport = await debugUseCase.execute(
            source: source,
            target: .content,
            query: "http://appi.kuwo.cn/novels/api/book/22292070000065702/chapters/95743741677860190",
            onLog: { newLog in
                collector.append(newLog)
            })

        #expect(contentReport.isSuccess == true)
        #expect(!collector.logs.isEmpty)
        #expect(collector.logs.contains { $0.message.contains("正文抓取成功") })
    }
}
