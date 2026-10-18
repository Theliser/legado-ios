# Legado iOS Apple 原生液态玻璃（Liquid Glass）视觉与工程设计规范

> **权威参考文档**：
> - Apple Developer: [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
> - Apple Developer: [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
> - Apple Human Interface Guidelines: [Materials & Vibrancy](https://developer.apple.com/design/human-interface-guidelines/materials)

---

## 1. 核心设计哲学：流动（Fluidity）、折射（Refraction）与材质（Material）

Liquid Glass（液态玻璃）是 Apple 现代界面的核心材质层。它将**光学玻璃的透光、模糊与高光折射**，与**触控交互的流体物理回弹（Fluid Morphing & Spring Dynamics）**深度结合。

### 核心定位
1. **内容在上，玻璃悬浮**：Liquid Glass 构筑的是浮动于视觉内容之上的“功能层”与“交互层”，绝不能作为厚重的实体阻隔；
2. **通透穿透，禁止遮挡**：界面的底层色彩与动态排版必须能够自然穿透玻璃层产生散射，严禁使用不透明硬背景将折射通道切断；
3. **触觉与视觉共振**：每一次触碰、悬停与点击，必须伴随亚像素光泽流转、轻量阻尼缩放与系统级触感反馈。

---

## 2. 界面四大核心支柱规范

### 2.1 根导航与标签栏（Tab Bar）规范
- **第一原则**：严格采用 iOS 18+ 原生 `TabView` 与 `Tab(title, systemImage: icon, value: selection)`；
- **系统动效**：系统将自动赋予底栏浮动“流体气泡（Liquid Bubble）”高光与光晕折射效果，iPad 上自动适配悬浮胶囊侧边栏；
- **禁止反模式**：
  - ❌ **严禁**给子视图添加遮蔽整个屏幕的纯色不透明背景（例如 `.background(Color(...).ignoresSafeArea())`），此行为会使底栏无法获取背景像素导致折射模糊失效；
  - ❌ **严禁**手写自定义 `UITabBar` 或私自更改 `UITabBarAppearance.opaqueBackground()`。

### 2.2 按钮系统（Buttons）规范
在本项目中，所有按钮必须严格遵循以下两类规范，彻底清除“扁平不透明硬色块”：

#### A. 官方标准样式（Preferred for Forms & Standard Controls）
- **主要操作（Primary）**：使用 `.buttonStyle(.borderedProminent)`，搭配 `.tint(color)`；
- **次要操作（Secondary）**：使用 `.buttonStyle(.bordered)` 或 `.buttonStyle(.borderless)`；
- **圆角形态**：使用 `.buttonBorderShape(.capsule)` 或 `.buttonBorderShape(.roundedRectangle(radius: 12))`。

#### B. 自定义液态玻璃按钮（Glass Button System）
适用于悬浮操作栏（Floating Bar）、模态操作面板与玻璃卡片内的交互：
- **`GlassButtonStyle`**：
  - 材质：`.ultraThinMaterial` / `.thinMaterial`；
  - 边框：亚像素光泽反光微描边（暗色 `white.opacity(0.15)`，亮色 `white.opacity(0.35)`，线宽 `0.5`）；
  - 触控：按压时弹簧缩放 `scaleEffect(configuration.isPressed ? 0.96 : 1.0)`；
  - 形状：`Capsule(style: .continuous)` 或平滑圆角矩形。
- **`GlassProminentButtonStyle(tint:)`**：
  - 具有语义着色发光感的高强调玻璃按钮，结合色彩半透渗透与高光边缘，绝非生硬的不透明实心填充。

#### 严禁的反模式（Anti-Patterns）
```swift
// ❌ 错误示范：粗暴的实心色块背景，破坏液态玻璃感
Button("确认导入") { ... }
    .background(Color.accentColor)
    .clipShape(RoundedRectangle(cornerRadius: 10))

// ❌ 错误示范：硬编码红/蓝背景
Button("开始") { ... }
    .background(Color.blue)

// ✅ 正确规范：液态玻璃发光按钮
Button("确认导入") { ... }
    .buttonStyle(GlassProminentButtonStyle(tint: .accentColor))

// ✅ 正确规范：原生 Bordered Prominent 结合 Liquid Glass
Button("开始") { ... }
    .buttonStyle(.borderedProminent)
    .tint(.blue)
```

### 2.3 容器与卡片（Containers & Cards）
- 统一使用 `DesignSystem/Materials/GlassCard.swift`；
- 多视图排布时，优先采用连续圆角（`RoundedRectangle(cornerRadius: 16, style: .continuous)`）；
- 外轮廓配备亚像素光泽描边 `.stroke(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.35), lineWidth: 0.5)`；
- 阴影统一采用环境弥散投影（`AppTheme.Shadow.glass`）。

### 2.4 悬浮胶囊栏（Floating Bar）
- 统一使用 `DesignSystem/Components/GlassFloatingBar.swift`；
- 专用于阅读器沉浸式 HUD、章节快速切换栏、书架批量操作浮动栏；
- 必须基于 `Capsule(style: .continuous)` 呈现，搭配轻微向上弹簧动效。

---

## 3. 设计规范代码对照清单

| 组件类别 | 违规写法（禁止使用） | 规范写法（强制使用） |
| :--- | :--- | :--- |
| **主要按钮** | `.background(Color.accentColor)` | `.buttonStyle(GlassProminentButtonStyle(tint: .accentColor))` 或 `.buttonStyle(.borderedProminent)` |
| **次要按钮** | `.background(Color.gray.opacity(...))` | `.buttonStyle(GlassButtonStyle())` 或 `.buttonStyle(.bordered)` |
| **危险按钮** | `.background(Color.red)` | `.buttonStyle(GlassProminentButtonStyle(tint: .red))` |
| **悬浮操作栏** | `HStack { ... }.background(Color.white)` | `GlassFloatingBar { ... }` |
| **卡片容器** | `VStack { ... }.background(Color.secondarySystemBackground)` | `GlassCard { ... }` 或 `.glassBackground()` |
| **模态面板** | 手写全屏遮罩 `Color.black.opacity(...)` | `.presentationBackground(.ultraThinMaterial)` |
| **底栏折射** | 页面根节点加全屏硬色背景覆盖 | 保持背景半透或利用原生 List/ScrollView 自然渗透 |
| **按压交互** | 无反馈直接执行动作 | `.scaleEffect(isPressed ? 0.96 : 1.0)` + `.sensoryFeedback(.impact(weight: .light))` |
