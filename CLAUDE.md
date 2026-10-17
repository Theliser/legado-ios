# CLAUDE.md — Claude Code Guidelines for Legado iOS

This repository is an iOS native replica of the open-source reader **Legado (阅读 3.0)**, built with SwiftUI, XcodeGen, and Swift Package Manager.

## Critical Project Constraints

1. **Design Language & Native-First Principle**:
   - **Always prioritize Apple official native components**: Use `TabView` + `Tab` (iOS 18+), `NavigationStack`, `.searchable`, `Menu`, `ContentUnavailableView`, and native sheet detents. Never reinvent standard navigation or container controls.
   - **Fallback to Liquid Glass design ONLY when native components cannot achieve the requirement** (e.g. immersive novel reading page turner, custom typography HUD, source debug console). Custom components must strictly use `.ultraThinMaterial`, `0.5pt white.opacity` borders, SF Symbols 6, and `.sensoryFeedback`.
   - **Zero Android Material Design (MD3)**.
2. **Architecture**: **Strict MVI (Model-View-Intent) + Clean Architecture**.
   - **Views**: Zero business logic, minimal compute. Pure render `View = f(State)`. User interactions emit `Intent` via `viewModel.send(.intent)`.
   - **ViewModels**: Inherit/conform to `MVIViewModel<State, Intent, Effect>`, `@MainActor`, emit single immutable `State: Equatable`.
   - **Domain Layer**: Pure Swift UseCases and Repository Protocols in `Domain/`. No SwiftUI or UIKit imports in Domain.
   - **Data Layer**: SwiftData / SQLite, Repository Implementations, WebDAV in `Data/`.
3. **Directory Structure**:
   - `Legado/Core/`: Architecture protocols, Network, ScriptEngine, RuleParser, Utilities.
   - `Legado/DesignSystem/`: Liquid Glass UI Kit (Materials, Components, Theme, Typography).
   - `Legado/Domain/`: Models, Repository interfaces, UseCases.
   - `Legado/Data/`: Database, RepositoryImpl, WebDAV.
   - `Legado/Features/<FeatureName>/`: Every feature MUST have `View/`, `Intent/`, `State/`, `ViewModel/`.

## Common Commands

Run via `make` or direct tools:
- `make format-check` — Verify formatting and linting without modifying files.
- `make format` — Auto-format code using SwiftFormat and auto-fix SwiftLint rules.
- `make lint` — Run SwiftLint and SwiftFormat checks.
- `make generate` — Regenerate `Legado.xcodeproj` via `xcodegen generate` (run after updating `project.yml` or adding files).
- `make build` — Build iOS Simulator target formatted with `xcbeautify`.
- `make clean` — Remove `.build`, `.derivedData`, and clean Xcode build cache.

## Adding Features

- When adding a new feature module, create it in `Legado/Features/<FeatureName>/` with:
  1. `State/<FeatureName>State.swift` (Equatable, immutable struct)
  2. `Intent/<FeatureName>Intent.swift` (Enum of all user and system intents)
  3. `ViewModel/<FeatureName>ViewModel.swift` (Subclass of `MVIViewModel`)
  4. `View/<FeatureName>View.swift` (Pure declarative SwiftUI view)
- After adding Swift files or changing `project.yml`, run `make generate` to keep Xcode project in sync.
- Always run `make format-check` before completing tasks.

## Git Branching Rules
- **NEVER push directly to `main`**.
- Development happens on `feature/<name>` branched from `develop`.
- Pull Requests merge into `develop`.
- Testing and TestFlight packaging merge into `test`.
- Production releases merge into `main`.
