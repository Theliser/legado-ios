import Foundation

public enum BookshelfEffect: ViewEffect, Equatable {
    case navigateToReader(UUID)
    case showToast(String)
}

@MainActor
public final class BookshelfViewModel: BaseMVIViewModel<BookshelfState, BookshelfIntent, BookshelfEffect> {
    public init() {
        super.init(initialState: BookshelfState())
    }

    override public func send(_ intent: BookshelfIntent) {
        switch intent {
        case .onAppear, .refresh:
            loadBooks()

        case let .selectGroup(group):
            updateState { $0.selectedGroup = group }

        case let .didSelectBook(id):
            emitEffect(.navigateToReader(id))
        }
    }

    private func loadBooks() {
        updateState { $0.isLoading = true }

        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            updateState { state in
                state.isLoading = false
                state.books = [
                    BookshelfBookItem(
                        title: "大奉打更人",
                        author: "卖报小郎君",
                        latestChapter: "第一千一百八十二章 终局",
                        progressPercent: 0.72),
                    BookshelfBookItem(
                        title: "赤心巡天",
                        author: "情何以甚",
                        latestChapter: "第十五章 霜雪满头",
                        progressPercent: 0.45),
                    BookshelfBookItem(
                        title: "诡秘之主",
                        author: "爱潜水的乌贼",
                        latestChapter: "第二百三十四章 赞美愚者",
                        progressPercent: 0.98),
                    BookshelfBookItem(
                        title: "宿命之环",
                        author: "爱潜水的乌贼",
                        latestChapter: "第一百八十章 命运的窥探",
                        progressPercent: 0.31),
                    BookshelfBookItem(
                        title: "剑来",
                        author: "烽火戏诸侯",
                        latestChapter: "第一千零九十章 风雪夜归人",
                        progressPercent: 0.86),
                    BookshelfBookItem(
                        title: "道诡异仙",
                        author: "狐尾的笔",
                        latestChapter: "第九百六十四章 真的假的",
                        progressPercent: 0.64),
                    BookshelfBookItem(
                        title: "万族之劫",
                        author: "老鹰吃小鸡",
                        latestChapter: "第九百七十四章 平定诸天",
                        progressPercent: 0.53),
                ]
            }
        }
    }
}
