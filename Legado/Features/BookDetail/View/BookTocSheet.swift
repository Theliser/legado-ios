import SwiftUI

/// 章节目录与书签抽屉组件 (基于 iOS 原生 Sheet Detents + 超薄液态材质)
public struct BookTocSheet: View {
    public enum Tab: String, CaseIterable, Identifiable {
        case toc = "目录"
        case bookmark = "书签"

        public var id: String {
            rawValue
        }
    }

    let chapters: [Chapter]
    let durChapterIndex: Int
    let isReverse: Bool
    let searchText: String
    let bookmarks: [Bookmark]
    let onToggleReverse: () -> Void
    let onSearchChange: (String) -> Void
    let onSelectChapter: (Chapter) -> Void
    let onSelectBookmark: (Bookmark) -> Void
    let onDeleteBookmark: (Bookmark) -> Void

    @State private var selectedTab: Tab = .toc
    @Environment(\.dismiss) private var dismiss

    public init(
        chapters: [Chapter],
        durChapterIndex: Int,
        isReverse: Bool,
        searchText: String,
        bookmarks: [Bookmark] = [],
        onToggleReverse: @escaping () -> Void,
        onSearchChange: @escaping (String) -> Void,
        onSelectChapter: @escaping (Chapter) -> Void,
        onSelectBookmark: @escaping (Bookmark) -> Void = { _ in },
        onDeleteBookmark: @escaping (Bookmark) -> Void = { _ in }) {
        self.chapters = chapters
        self.durChapterIndex = durChapterIndex
        self.isReverse = isReverse
        self.searchText = searchText
        self.bookmarks = bookmarks
        self.onToggleReverse = onToggleReverse
        self.onSearchChange = onSearchChange
        self.onSelectChapter = onSelectChapter
        self.onSelectBookmark = onSelectBookmark
        self.onDeleteBookmark = onDeleteBookmark
    }

    private var displayedChapters: [Chapter] {
        var list = chapters
        if isReverse {
            list.reverse()
        }
        if !searchText.isEmpty {
            list = list.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabSegmentedControl
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                if selectedTab == .toc {
                    tocSection
                } else {
                    bookmarkSection
                }
            }
            .navigationTitle(selectedTab == .toc ? "目录" : "书签")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: Binding(
                    get: { searchText },
                    set: { onSearchChange($0) }),
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "搜索章节名...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.fraction(0.45), .medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }

    private var tabSegmentedControl: some View {
        Picker("视图", selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var tocSection: some View {
        VStack(spacing: 0) {
            tocToolbar
            Divider()

            if displayedChapters.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                tocList
            }
        }
    }

    private var tocToolbar: some View {
        HStack(spacing: 12) {
            Text("共 \(chapters.count) 章")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onToggleReverse()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2)
                    Text(isReverse ? "倒序" : "正序")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
            }
            .tint(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var tocList: some View {
        ScrollViewReader { proxy in
            List(displayedChapters) { chapter in
                chapterRow(chapter)
                    .id(chapter.index)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .onAppear {
                if durChapterIndex >= 0 && durChapterIndex < chapters.count {
                    proxy.scrollTo(durChapterIndex, anchor: .center)
                }
            }
        }
    }

    private func chapterRow(_ chapter: Chapter) -> some View {
        Button {
            onSelectChapter(chapter)
        } label: {
            HStack(spacing: 10) {
                Text("\(chapter.index + 1).")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .leading)

                Text(chapter.title)
                    .font(.body)
                    .foregroundStyle(
                        chapter.index == durChapterIndex ? Color.accentColor : Color.primary)
                    .lineLimit(1)

                Spacer()

                if chapter.index == durChapterIndex {
                    Text("当前")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var bookmarkSection: some View {
        if bookmarks.isEmpty {
            ContentUnavailableView(
                "暂无书签",
                systemImage: "bookmark",
                description: Text("阅读时轻触右上角书签按钮即可添加"))
        } else {
            List {
                ForEach(bookmarks) { bookmark in
                    bookmarkRow(bookmark)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDeleteBookmark(bookmark)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
        }
    }

    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        Button {
            onSelectBookmark(bookmark)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(bookmark.chapterName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)

                    Spacer()

                    Text(bookmark.formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(bookmark.bookText)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !bookmark.content.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(bookmark.content)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
