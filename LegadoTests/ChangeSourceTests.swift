import Foundation
@testable import Legado
import Testing

@Suite("Change Source Suite")
struct ChangeSourceTests {
    @Test("Test Chapter Index Matching Algorithm in ChangeBookSourceUseCase")
    func chapterMatching() {
        let dummyBookRepo = BookRepositoryImpl(modelContainer: ModelContainerProvider(inMemory: true).container)
        let dummySourceRepo = BookSourceRepositoryImpl(modelContainer: ModelContainerProvider(inMemory: true).container)
        let useCase = ChangeBookSourceUseCase(
            sourceRepository: dummySourceRepo,
            bookRepository: dummyBookRepo)

        let targetToc = [
            Chapter(url: "https://b.com/1", title: "第一章 诡异降临", bookUrl: "https://b.com/book", index: 0),
            Chapter(url: "https://b.com/2", title: "第二章 迷雾重重", bookUrl: "https://b.com/book", index: 1),
            Chapter(url: "https://b.com/3", title: "第三章 宿命之枪", bookUrl: "https://b.com/book", index: 2),
            Chapter(url: "https://b.com/4", title: "第 4 章 暗夜低语", bookUrl: "https://b.com/book", index: 3),
        ]

        // 1. 完全精确匹配
        let exact = useCase.matchChapterIndex(
            targetToc: targetToc,
            currentTitle: "第二章 迷雾重重",
            currentIndex: 0)
        #expect(exact == 1)

        // 2. 包含匹配 (去除空格或符号微小差异)
        let contains = useCase.matchChapterIndex(
            targetToc: targetToc,
            currentTitle: "宿命之枪",
            currentIndex: 0)
        #expect(contains == 2)

        // 3. 章节序号提取匹配 (带空格第 4 章)
        let numberMatch = useCase.matchChapterIndex(
            targetToc: targetToc,
            currentTitle: "第4章",
            currentIndex: 0)
        #expect(numberMatch == 3)

        // 4. 标题不匹配时的索引兜底
        let fallback = useCase.matchChapterIndex(
            targetToc: targetToc,
            currentTitle: "完全不存在的章节名",
            currentIndex: 2)
        #expect(fallback == 2)

        // 5. 索引越界保护
        let clamped = useCase.matchChapterIndex(
            targetToc: targetToc,
            currentTitle: nil,
            currentIndex: 999)
        #expect(clamped == 3)
    }

    @Test("Test ChangeSourceCandidate Equality and Properties")
    func candidateProperties() {
        let candidate = ChangeSourceCandidate(
            origin: "https://source1.com",
            originName: "测试书源1",
            bookUrl: "https://source1.com/book/10",
            name: "诡秘之主",
            author: "爱潜水的乌贼",
            latestChapterTitle: "最终章 愚者",
            elapsedMs: 250,
            isCurrent: true)

        #expect(candidate.id == "https://source1.com_https://source1.com/book/10")
        #expect(candidate.isCurrent == true)
        #expect(candidate.elapsedMs == 250)
        #expect(candidate.originName == "测试书源1")
    }

    @Test("Test ChangeSourceViewModel MVI State Transitions")
    @MainActor
    func viewModelFlow() {
        let provider = ModelContainerProvider(inMemory: true)
        let bookRepo = BookRepositoryImpl(modelContainer: provider.container)
        let sourceRepo = BookSourceRepositoryImpl(modelContainer: provider.container)

        let initialBook = Book(
            bookUrl: "https://old.com/book/1",
            origin: "https://old.com",
            originName: "旧书源",
            name: "宿命之环",
            author: "爱潜水的乌贼",
            durChapterTitle: "第一章",
            durChapterIndex: 0)

        let useCase = ChangeBookSourceUseCase(
            sourceRepository: sourceRepo,
            bookRepository: bookRepo)

        let viewModel = ChangeSourceViewModel(
            book: initialBook,
            currentChapterTitle: "第一章",
            currentChapterIndex: 0,
            changeBookSourceUseCase: useCase)

        #expect(viewModel.state.book.name == "宿命之环")
        #expect(viewModel.state.isSearching == true)

        // 测试选择当前书源抛出无需切换提示
        let currentCandidate = ChangeSourceCandidate(
            origin: "https://old.com",
            originName: "旧书源",
            bookUrl: "https://old.com/book/1",
            name: "宿命之环",
            author: "爱潜水的乌贼",
            isCurrent: true)

        viewModel.send(.selectCandidate(currentCandidate))
        // 验证没有进入 switching 状态
        #expect(viewModel.state.isSwitching == false)
    }
}
