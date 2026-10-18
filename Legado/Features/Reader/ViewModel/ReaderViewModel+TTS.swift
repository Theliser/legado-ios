import Foundation

// MARK: - 朗读与连续跨章听书支持扩展

public extension ReaderViewModel {
    /// 获取下一章节正文供连续无缝听书使用
    func fetchNextChapterForTTS() async -> (title: String, content: String)? {
        let nextIndex = state.currentChapterIndex + 1
        guard nextIndex < state.chapters.count else { return nil }
        let nextChapter = state.chapters[nextIndex]
        guard let content = try? await getChapterContentUseCase.execute(
            chapter: nextChapter,
            origin: state.book.origin) else {
            return nil
        }
        self.send(.loadChapter(nextIndex))
        return (title: nextChapter.title, content: content)
    }
}
