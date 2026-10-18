# AGENTS.md — Legado iOS AI Agent 协作与研发总则

本文档是本项目针对所有接入的 AI 编程助手（包括 Gemini / Antigravity、Claude Code、Cursor、Windsurf、GitHub Copilot 等）制定的最高研发规范与开发约束。所有参与本项目的 AI Agent 必须无条件遵守本文件中的规范。

---

## 1. 项目全貌与核心目标

- **项目定位**：开源阅读器 [Legado (阅读 3.0)](https://github.com/HapeLee/legado-with-MD3) 的 iOS 原生版本。
- **视觉风格**：**严禁使用 Android Material Design 风格**。全面采用 **iOS 原生液态玻璃（Liquid Glass / Vibrancy / Materials）美学**，深度适配 iOS 18+ 原生人机交互指南（HIG）。
- **工程构建**：工程采用 **XcodeGen** (`project.yml`) 驱动，原生集成 Swift Package Manager (SPM)，禁止使用 CocoaPods。

---

## 2. 架构模式规范：强制 MVI (Model-View-Intent)

本项目在展示层（Presentation Layer）严格执行 **MVI 单向数据流架构**与 **Clean Architecture**。

```
[ User Interaction ] 
        │ 
        ▼
   View (纯声明渲染) ───( 发送 Intent )───► ViewModel (状态中枢)
        ▲                                          │
        │                                          ▼ (调用 UseCase)
  ( 唯一 State 驱动 )                        Domain / Data Layer
        │                                          │
        └──────────( 发射新不可变 State )──────────┘
```

### 2.1 视图层（View）铁律
1. **零业务逻辑（Zero Business Logic）**：
   - 严禁在 `View` 内部进行任何条件排序、数据过滤、日期计算、文本拼接等复杂计算；
   - 严禁在 `View` 中直接访问任何 Repository、网络 API、文件读写或 SwiftData/数据库对象；
   - 视图只做纯数据映射渲染：`View = f(State)`。
2. **唯一交互入口**：
   - 所有用户交互（点击、滑动、输入、生命周期事件）必须映射为强类型 Intent，并通过 `viewModel.send(.someIntent)` 发送。
3. **极简局部状态**：
   - 仅允许保留纯 UI 动效相关的轻量状态（如 `@State private var isMenuPresented = false`），其余所有展示数据一律来自 `viewModel.state`。

### 2.2 ViewModel 层铁律
1. 必须使用 `@MainActor` 标注，继承或遵守 `MVIViewModel<State, Intent, Effect>` 协议；
2. 仅暴露单一不可变状态 `@Published private(set) var state: State`；
3. 负责接收并派发 `Intent`，调用 `Domain/UseCases` 执行异步业务逻辑，并在状态完成后统一产出新 `State`；
4. 一次性副作用（如 Toast 提示、导航跳转、触感震动）通过 `Effect` 管道通知 View，不可将瞬态事件污染至持久 State 中。

---

## 3. UI 视觉与组件规范：原生优先原则（Native-First Principle）

## 3. UI 视觉与组件规范：Apple 官方原生液态玻璃（Liquid Glass）强制规范

参考 Apple 官方设计与研发指南：[Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) 与 [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)。

### 3.1 官方原生优先与自动采纳原则（First-Party First）
1. **系统框架原生组件自动采纳 Liquid Glass**：
   - 凡是系统原生支持的控件、导航与容器，**必须直接使用官方组件**，享受系统级自动 Liquid Glass 材质、高光、流体响应与无障碍适配；
   - **根导航与标签栏（Tab Bar）**：必须使用 iOS 18+ 原生 `TabView` + `Tab`，享受系统级流体气泡（Liquid Bubble）高光与背景实时折射模糊；
   - **搜索栏**：必须使用官方 `.searchable`；
   - **页面导航**：必须使用官方 `NavigationStack`；
   - **选项菜单**：必须使用官方 `Menu`，状态缺省必须使用官方 `ContentUnavailableView`；
   - **模态弹出**：必须优先采用 iOS 原生 Sheet Detents：`.presentationDetents([.fraction(0.35), .medium, .large])` 配合 `.presentationBackground(.ultraThinMaterial)`。

2. **铁律：杜绝破坏液态玻璃折射的自定义背景（Reduce Custom Backgrounds）**：
   - **严禁**在页面根容器、NavigationView/NavigationStack 或 TabView 承载的视图中直接使用大面积不透明硬背景（如 `.background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())`）；
   - 这类不透明硬背景会彻底遮蔽并破坏 TabBar 与 NavigationBar 官方提供的 Liquid Glass 背景实时折射和滚动边缘光效（Scroll Edge Effect）；
   - 背景层必须允许内容滑动穿透与自然模糊折射。

### 3.2 按钮（Buttons）Liquid Glass 强制规范
1. **标准按钮样式规范**：
   - 强调类主要操作（Primary Action）：使用 `.buttonStyle(.borderedProminent)` 配备 `.tint(...)`，或使用设计系统提供的 `GlassProminentButtonStyle(tint:)`；
   - 次要操作与辅助操作（Secondary Action）：使用设计系统提供的 `GlassButtonStyle()` 或 `.buttonStyle(.bordered)`；
   - 所有按钮统一采用 **连续平滑圆角（Continuous Corner Radius）**（如 `Capsule(style: .continuous)` 或 `RoundedRectangle(cornerRadius: ..., style: .continuous)`）。
2. **严禁按钮反模式（Strict Anti-Patterns）**：
   - 🚫 **严禁**使用硬编码纯色硬背景制作按钮（如 `.background(Color.accentColor)`、`.background(Color.blue)`、`.background(Color.red)`）；
   - 🚫 **严禁**使用未经平滑过渡的粗暴直角或非连续圆角；
   - 🚫 **严禁**按钮点击无触感反馈或无弹簧阻尼按压缩放（必须搭配 `scaleEffect(isPressed ? 0.96 : 1.0)` 与 `.sensoryFeedback`）。

### 3.3 自定义容器与悬浮栏（Custom Containers & Floating Bars）规范
1. **材质系统**：自定义悬浮面板、操作卡片与 HUD 必须基于 `DesignSystem/Materials/GlassCard.swift` 与 `DesignSystem/Components/GlassFloatingBar.swift`，基于 `.ultraThinMaterial` 或 `.thinMaterial` 渲染；
2. **高光微描边（Subpixel Light Highlight）**：玻璃容器外周必须配备亚像素微光反光描边：
   - 暗黑模式：`.stroke(Color.white.opacity(0.15), lineWidth: 0.5)`；
   - 明亮模式：`.stroke(Color.white.opacity(0.35), lineWidth: 0.5)`；
3. **图标与文字分层**：必须使用 **SF Symbols 6**（支持分层 `.symbolRenderingMode(.hierarchical)` 或 `.palette` 渲染），文字严禁使用硬编码色，严格使用系统语义层级（`.primary`, `.secondary`, `.tertiary`）；
4. **流体触感与弹簧阻尼**：交互必须搭配系统级轻触感反馈 `.sensoryFeedback(.impact(weight: .light), trigger: ...)`，动效统一采用弹簧阻尼 `.animation(.spring(response: 0.35, dampingFraction: 0.82), value: ...)`。

---

## 4. 目录结构与模块文件归属约束

所有源码必须严格归入以下目录，禁止随意根目录新建零散代码：

```
Legado/
├── App/                       # App 入口、生命周期与全局注入 (LegadoApp.swift, AppEnvironment.swift)
├── Core/                      # 基础底层引擎（纯 Swift 设施，无业务特性）
│   ├── Architecture/          # MVI 核心协议与基类 (MVIViewModel, ViewState, ViewIntent)
│   ├── Network/               # 基础 HTTP Client、GBK/Big5/UTF-8 字符解码
│   ├── ScriptEngine/          # JavaScriptCore / QuickJS 执行环境
│   ├── RuleParser/            # 书源规则引擎 (XPath, CSS, JSONPath, 正则)
│   └── Utilities/             # 触感震动、日志打印、通用扩展
├── DesignSystem/              # 液态玻璃设计系统
│   ├── Materials/             # 玻璃修饰符与容器 (GlassCard, GlassBackground)
│   ├── Components/            # 玻璃按钮、悬浮操作栏、搜索条
│   ├── Typography/            # 动态字体规范
│   └── Theme/                 # 语义调色盘与全局常数
├── Domain/                    # 纯业务领域模型与用例 (Clean Architecture，严禁依赖 SwiftUI/UIKit)
│   ├── Model/                 # 领域实体 (Book, Chapter, BookSource, ReadRecord)
│   ├── Repository/            # 数据仓库协议接口
│   └── UseCases/              # 纯业务用例 (SearchBooksUseCase, ParseBookSourceUseCase)
├── Data/                      # 数据持久化与基础设施实现
│   ├── Database/              # SwiftData / SQLite 数据模型与存储实现
│   ├── RepositoryImpl/        # Repository 协议的具体实现
│   └── WebDAV/                # WebDAV 同步与云备份实现
└── Features/                  # 业务功能模块（严格按功能分包，每包内聚 MVI）
    ├── Bookshelf/             # 书架 (View/, Intent/, State/, ViewModel/)
    ├── Reader/                # 阅读器核心 (View/, Engine/, Intent/, State/, ViewModel/)
    ├── Explore/               # 发现与分类排版 (View/, Intent/, State/, ViewModel/)
    ├── Search/                # 多源聚合搜索 (View/, Intent/, State/, ViewModel/)
    ├── BookDetail/            # 书籍详情与目录 (View/, Intent/, State/, ViewModel/)
    ├── SourceManage/          # 书源管理、导入、调试与规则编辑
    └── Settings/              # 设置与 WebDAV 配置
```

### 4.1 新增功能铁律：
- **新增 Feature**：必须在 `Features/<FeatureName>/` 下建立完整的 `View/`, `Intent/`, `State/`, `ViewModel/` 四件套；
- **业务逻辑**：必须通过 `Domain/UseCases` 承载，严禁跨层将业务逻辑泄漏至 View 中；
- **外部依赖**：只能在 `project.yml` 中声明 SPM 依赖，并执行 `make generate` 更新工程，切勿手动拖拽第三方源代码入库。

---

## 5. 开发工作流与常用命令

在修改代码或执行构建时，AI Agent 必须优先调用 Makefile 命令：

- `make lint` / `make format-check`：检查代码格式规范与 SwiftLint 违规；
- `make format`：自动执行 SwiftFormat 格式化并自动修复 SwiftLint 规则；
- `make generate`：更新 `project.yml` 后的重新生成 Xcode 工程；
- `make build`：使用 `xcbeautify` 构建模拟器应用并检验编译；
- `make clean`：清理构建缓存。

提交代码前，确保执行 `make format-check` 无告警无报错。

---

## 6. Git 分支管理与提交流水线铁律

1. **分支职责模型**：
   - `main`：生产发布主分支，保持随时可提交 App Store 状态；
   - `develop`：核心日常开发集成分支；
   - `test`：测试与预发打包分支，用于打包 TestFlight 与回归验证；
   - `feature/<name>`：功能分支，所有新特性从 `develop` 拉出开发。
2. **保护机制约束**：
   - **严禁直接向 `main` 分支推送代码**；
   - 所有新需求必须在 `feature/<name>` 分支完成，通过 `make format-check` 后提交 Pull Request 合入 `develop`；
   - 阶段性发布时，由 `develop` 合入 `test` 进行真机打包测试，无误后通过发布 PR 合并入 `main`。
