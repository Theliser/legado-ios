import SwiftUI

/// App 主导航标签页枚举
public enum MainTab: String, CaseIterable, Identifiable {
    case bookshelf
    case search
    case explore
    case sourceManage
    case settings

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .bookshelf: return "书架"
        case .search: return "搜索"
        case .explore: return "发现"
        case .sourceManage: return "书源"
        case .settings: return "设置"
        }
    }

    public var icon: String {
        switch self {
        case .bookshelf: return "books.vertical.fill"
        case .search: return "magnifyingglass"
        case .explore: return "compass.drawing"
        case .sourceManage: return "network"
        case .settings: return "gearshape.fill"
        }
    }
}

/// App 根视图：全面采用 iOS 18 原生 TabView 与 Tab 容器架构
struct ContentView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selectedTab: MainTab = .bookshelf

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(MainTab.bookshelf.title, systemImage: MainTab.bookshelf.icon, value: .bookshelf) {
                BookshelfView(viewModel: environment.makeBookshelfViewModel())
            }

            Tab(MainTab.search.title, systemImage: MainTab.search.icon, value: .search) {
                SearchView(viewModel: environment.makeSearchViewModel())
            }

            Tab(MainTab.explore.title, systemImage: MainTab.explore.icon, value: .explore) {
                NavigationStack {
                    ZStack {
                        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                        ContentUnavailableView(
                            "发现好书",
                            systemImage: "compass.drawing",
                            description: Text("支持从已配置的书源中探索榜单与分类排版"))
                    }
                    .navigationTitle("发现")
                }
            }

            Tab(MainTab.sourceManage.title, systemImage: MainTab.sourceManage.icon, value: .sourceManage) {
                NavigationStack {
                    ZStack {
                        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                        ContentUnavailableView(
                            "书源管理",
                            systemImage: "network",
                            description: Text("导入、调试、校验与编辑 Legado 书源规则"))
                    }
                    .navigationTitle("书源")
                }
            }

            Tab(MainTab.settings.title, systemImage: MainTab.settings.icon, value: .settings) {
                NavigationStack {
                    ZStack {
                        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                        ContentUnavailableView(
                            "系统设置",
                            systemImage: "gearshape.fill",
                            description: Text("排版偏好、WebDAV 云备份及外观配置"))
                    }
                    .navigationTitle("设置")
                }
            }
        }
        .fullScreenCover(isPresented: $demoReaderPresented) {
            let sampleBook = Book(
                bookUrl: "https://biquge.example.com/book/circle_of_inevitability",
                tocUrl: "https://biquge.example.com/book/circle_of_inevitability/toc",
                origin: "https://biquge.example.com",
                originName: "笔趣阁官方",
                name: "宿命之环",
                author: "爱潜水的乌贼",
                durChapterTitle: "第一章 宿命之始",
                durChapterIndex: 0)
            let showHUD = ProcessInfo.processInfo.arguments.contains("--open-reader-hud")
            ReaderView(viewModel: environment.makeReaderViewModel(
                book: sampleBook,
                initialChapterIndex: 0,
                showHUDInitially: showHUD))
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--open-reader-demo") ||
                ProcessInfo.processInfo.arguments.contains("--open-reader-hud") {
                demoReaderPresented = true
            }
        }
    }

    @State private var demoReaderPresented = false
}

#Preview {
    ContentView()
        .environmentObject(AppEnvironment(inMemory: true))
}
