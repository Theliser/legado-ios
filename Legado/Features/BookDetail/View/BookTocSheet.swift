import SwiftUI

/// 章节目录抽屉组件 (基于 iOS 原生 Sheet Detents + 超薄液态材质)
public struct BookTocSheet: View {
    let chapters: [Chapter]
    let durChapterIndex: Int
    let isReverse: Bool
    let searchText: String
    let onToggleReverse: () -> Void
    let onSearchChange: (String) -> Void
    let onSelectChapter: (Chapter) -> Void

    public init(
        chapters: [Chapter],
        durChapterIndex: Int,
        isReverse: Bool,
        searchText: String,
        onToggleReverse: @escaping () -> Void,
        onSearchChange: @escaping (String) -> Void,
        onSelectChapter: @escaping (Chapter) -> Void) {
        self.chapters = chapters
        self.durChapterIndex = durChapterIndex
        self.isReverse = isReverse
        self.searchText = searchText
        self.onToggleReverse = onToggleReverse
        self.onSearchChange = onSearchChange
        self.onSelectChapter = onSelectChapter
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
                // 顶部工具栏
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

                Divider()

                // 章节列表
                if displayedChapters.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollViewReader { proxy in
                        List(displayedChapters) { chapter in
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
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: Binding(
                    get: { searchText },
                    set: { onSearchChange($0) }),
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "搜索章节名...")
        }
        .presentationDetents([.fraction(0.4), .medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }
}
