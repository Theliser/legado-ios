# GitHub Copilot Instructions for Legado iOS

This repository is an iOS native SwiftUI implementation of the open-source reader **Legado (阅读 3.0)**.

## Core Rules for Code Suggestions

### 1. Architecture: MVI (Model-View-Intent)
- **Do NOT put business logic, state mutations, sorting, or data transformations inside SwiftUI Views**.
- All SwiftUI Views must be pure functions of a single immutable state: `View = f(viewModel.state)`.
- When suggesting user interaction handlers, emit an `Intent` via `viewModel.send(.intentName)` rather than mutating local state or executing async fetches directly in the View.
- ViewModels must conform to the MVI protocol, be marked `@MainActor`, and expose `@Published private(set) var state: State`.

### 2. UI Style: Native-First Principle & Liquid Glass Fallback
- **Always prioritize Apple official native components**:
  - Always suggest `TabView` + `Tab` (iOS 18+), `NavigationStack`, `.searchable`, `Menu`, `ContentUnavailableView`, and sheet detents.
  - Never suggest custom `ZStack` fake bottom bars, fake navigation bars, or custom tab bars.
- **Only suggest custom components if native components cannot fulfill the requirement**:
  - When custom components are strictly necessary (e.g. reader HUDs, custom typography adjustments), use the **iOS Liquid Glass specification**:
    - Translucent backgrounds: `.background(.ultraThinMaterial)` or `.background(.thinMaterial)`.
    - Glass card styling: `.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))` with `.overlay(RoundedRectangle(...).stroke(.white.opacity(0.15), lineWidth: 0.5))`.
    - Native SF Symbols 6 with hierarchical or palette rendering: `Image(systemName: "...").symbolRenderingMode(.hierarchical)`.
    - Haptics: `.sensoryFeedback(...)`.
- **Do NOT suggest Android Material Design 3 patterns** (e.g. Android FAB buttons, MD3 pill navigation bars, MD3 color schemes).

### 3. File & Module Structure
- Place domain models and use cases in `Legado/Domain/` (pure Swift, no SwiftUI/UIKit).
- Place database and persistence in `Legado/Data/`.
- Place UI features in `Legado/Features/<FeatureName>/` with dedicated `View/`, `Intent/`, `State/`, and `ViewModel/` subdirectories.
- Place reusable glass styling in `Legado/DesignSystem/`.
