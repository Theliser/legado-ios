# Legado iOS (阅读 iOS 原生重构版)

本项目是开源热门小说阅读器 **[Legado (阅读 3.0)](https://github.com/HapeLee/legado-with-MD3)** 的 iOS 原生重构版本。

全面遵循 **iOS 18+ 原机人机交互指南 (HIG)** 与 **iOS 原生液态玻璃美学**，基于 **MVI 单向数据流** 与 **Clean Architecture** 构建，采用 **XcodeGen** 驱动工程定义。

---

## 🌟 核心设计理念

1. **原生优先原则 (Native-First Principle)**：
   - 凡是 iOS 系统提供原生支持的组件与容器（iOS 18+ `TabView` + `Tab`、`.searchable`、`NavigationStack`、`Menu`、原生 Sheet Detents），直接使用第一方组件，享受系统级流体高光与列表内容穿透折射；
   - 仅在阅读器沉浸翻页、排版 HUD 等特化场景下，按照 iOS 原生液态玻璃规范自研组件。
2. **纯粹 MVI 单向数据流 (Model-View-Intent)**：
   - **View 零业务逻辑**：`View = f(State)`，仅做纯声明式渲染，禁止数据计算与越层访问；
   - **离散 Intent 驱动**：所有交互均发射强类型 `Intent` 由 `ViewModel` 处理；
   - **不可变 State**：每个模块暴露唯一的 `State: Equatable`。
3. **数据缓存下沉**：
   - ViewModel 绝不直连数据库；
   - 缓存作为内部细节封装在 `Data/` 仓储层（L1 内存缓存 -> L2 本地数据库 -> L3 远程抓取），对外提供统一的抽象协议。

---

## 🛠️ 技术栈与依赖管理

- **语言 & 运行环境**：Swift 6.4 / iOS 18.0+
- **UI 框架**：SwiftUI (原生液态玻璃材料与 iOS 18 新导航体系)
- **工程脚手架**：XcodeGen (`project.yml`)
- **依赖管理**：Swift Package Manager (SPM，拒绝 CocoaPods)
- **代码规范**：SwiftLint (0.65.1) + SwiftFormat (0.64.0)
- **编译日志优化**：xcbeautify (3.2.1)

---

## 🚀 快速上手与常用命令

本项目通过 `Makefile` 提供标准化的开发指令：

```bash
# 1. 初始化本地开发环境与 Git 钩子
make setup

# 2. 修改 project.yml 后重新生成 Xcode 工程
make generate

# 3. 运行代码格式化并自动修复 Lint 问题
make format

# 4. 检查代码规范与格式（CI 检查标准）
make format-check

# 5. 编译 iOS 模拟器目标
make build

# 6. 清理构建产物与缓存
make clean
```

---

## 🌿 Git 分支管理与协作规范 (Git Flow)

本项目采用规范的移动端流水线分支策略，禁止直接向受保护分支推送代码：

```
       [feature/xxx] (新功能开发)
             │
             ▼ PR
[develop] (核心开发集成分支) ───► [test] (测试/打包预备分支) ───► [main] (生产发布主分支)
                                      │                             ▲
                                      └─ (TestFlight 验证打 Tag) ────┘
```

- **`main` (生产发布分支)**：受保护分支，仅接受来自 `test` 分支的经测试验证的发布 PR，保持随时可提交 App Store 的稳定状态；
- **`develop` (核心开发分支)**：受保护分支，所有日常功能的集成主干；
- **`feature/<name>` (特性分支)**：从 `develop` 检出，开发完成并通过 `make format-check` 后向 `develop` 提 PR；
- **`test` (测试/预备分支)**：从 `develop` 阶段性切出，用于打包 TestFlight、内部回归测试与 Bug 修复，验证完成后双向合入 `main` 与 `develop`；
- **`hotfix/<name>` (紧急修复分支)**：从 `main` 检出修复关键线上问题，修复后合并回 `main` 与 `develop`。

---

## 🤖 多 AI Agent 协作支持

本项目内置了全面的 AI Agent 开发约束与上下文配置：
- [AGENTS.md](AGENTS.md) — 全局架构与开发总则 (适用于 Gemini / Antigravity / 通用 Agent)
- [CLAUDE.md](CLAUDE.md) — Claude Code 专属指令与构建规范
- [.cursor/rules/](.cursor/rules/) & [.cursorrules](.cursorrules) — Cursor 上下文规则
- [.github/copilot-instructions.md](.github/copilot-instructions.md) — GitHub Copilot 补全规则
- [.windsurfrules](.windsurfrules) — Windsurf / Cascade 规则
