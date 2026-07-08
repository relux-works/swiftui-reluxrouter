# Relux SwiftUI Router

ReluxRouter provides SwiftUI navigation routers for
[Relux](https://github.com/relux-works/swift-relux). The package exposes both a
generic `Router` and a `ProjectingRouter` that can inspect the actual
`NavigationPath` content without requiring every path value to be `Codable`.

This repository is organized as a small workspace:

- `Package.swift` - SwiftPM compatibility manifest for package consumers. Its
  targets point into `SDK/Sources` and `SDK/Tests`.
- `SDK/` - the SDK package contents and package-local README.
- `Sample/` - local demo iOS app repository used for UI/XCUITest validation.

`Sample/` is intentionally ignored by this repository because it has its own git
remote and history.

## ProjectingRouter

`ProjectingRouter` is a navigation router that maintains a SwiftUI
`NavigationPath` and exposes a projected view of that path for inspection.
Available from iOS 16, macOS 13, watchOS 9, and tvOS 16.

### Declaration

```swift
@MainActor
public final class ProjectingRouter<Page>: Relux.Navigation.RouterProtocol, ObservableObject where Page: PathComponent, Page: Sendable
```

### Path Projection

`ProjectingRouter` exposes computed `projectedPath` and `projectedPathStrings`,
derived from the actual `NavigationPath` contents on demand. The projection reads
concrete path elements without requiring `Codable`, so it can inspect both
Relux-driven pages and externally inserted SwiftUI navigation values while
keeping `path` as the only source of truth.

`PathProjection` is a read-only inspection value. Do not register
`navigationDestination(for: PathProjection.self)` or
`navigationDestination(for: ProjectedPage.self)`. SwiftUI route handlers should
stay attached to each module's concrete page type.

### Module-Local Destinations

Use one `ProjectingRouter` as the app-level `NavigationStack` harness, then let
feature modules keep their own route types and destination handlers inside the
view hierarchy. Module pages do not need a shared app enum or protocol.

```swift
enum AppPage: Relux.Navigation.PathComponent {
    case about
}

typealias AppRouter = Relux.Navigation.ProjectingRouter<AppPage>

NavigationStack(path: $router.path) {
    CatalogModule.Container {
        RootContainer()
            .navigationDestination(for: AppPage.self) { page in
                AppAboutPage(page: page)
            }
    }
}

enum CatalogModule {
    enum Page: Hashable, Sendable {
        case detail(id: String)
    }

    typealias NavigationLink<Label: View> = Relux.NavigationLink<Page, Label>

    struct Container<Content: View>: View {
        @ViewBuilder let content: () -> Content

        var body: some View {
            content()
                .navigationDestination(for: Page.self, destination: Self.destination)
        }

        @ViewBuilder
        static func destination(for page: Page) -> some View {
            switch page {
            case let .detail(id):
                CatalogDetailPage(id: id)
            }
        }
    }

    struct LinksSection: View {
        var body: some View {
            Section("Catalog") {
                NavigationLink(page: .detail(id: "item-42")) {
                    Text("Open via Relux")
                }

                SwiftUI.NavigationLink(value: Page.detail(id: "native-42")) {
                    Text("Open via native NavigationLink")
                }
            }
        }
    }
}
```

`Relux.NavigationLink<Page, Label>` dispatches
`Relux.Navigation.ProjectingRouterAction.push(...)`. The router appends the
original concrete `Page` value to the live `NavigationPath`, so SwiftUI still
resolves it through `navigationDestination(for: CatalogModule.Page.self)`.
Native `NavigationLink(value:)` values and Relux-driven values therefore appear
in the same computed projection.

If reflected output is too noisy for a route value, conform that page to
`Relux.Navigation.PathProjectionRepresentable` and return a compact string.
Do not use `Codable` for projection: non-codable route payloads are supported.

### Relux Actions

```swift
public enum Action: Relux.Action {
    case push(page: Page, allowingDuplicates: Bool = false)
    case set(pages: [Page])
    case removeLast(count: Int = 1)
}
```

## Router

`Router` is a simpler navigation router available from iOS 17, macOS 14,
watchOS 10, tvOS 17, and macCatalyst 17.

### Declaration

```swift
@Observable @MainActor
public final class Router<Page>: Relux.Navigation.RouterProtocol where Page: PathComponent, Page: Sendable
```

### Actions

```swift
public enum Action: Relux.Action {
    case push(page: Page)
    case set(pages: [Page])
    case removeLast(count: Int = 1)
}
```

## Usage

The routers can be used in conjunction with SwiftUI's `NavigationStack` or
`NavigationSplitView` to create dynamic navigation experiences.

Both routers can manage navigation in SwiftUI applications. `ProjectingRouter`
adds inspection and duplicate-prevention helpers for mixed Relux/native
navigation stacks. Use it with SwiftUI reference semantics through
`@EnvironmentObject`. `Router` offers a simpler API for basic navigation needs
inside unified SwiftUI environment injection through `@Environment`.

### Initialization and Connection to Relux

To use either router, connect the instances to the Relux state machine during
container initialization, then attach them to views through the corresponding
environment-access modifier. On initialization, resolve the generic page with a
concrete type specific to your app.

```swift
@main @MainActor
struct Anteater: App {
    @StateObject private var reluxContainer = Anteater.reluxContainerInstance

    init() {
        Anteater.configureIoC()
    }

    var body: some Scene {
        WindowGroup {
            EntryPoint.ContentContainer()
                .passingObservableToEnvironment(fromStore: reluxContainer.relux.store)
        }
    }
}
```

Define your navigation pages:

```swift
import Relux

extension UI.Dashboard { enum Navigation {} }
extension UI.Profile { enum Navigation {} }

extension UI.Dashboard.Navigation {
    enum Page: Relux.Navigation.PathComponent {
        case info
        case details
    }
}

extension UI.Profile.Navigation {
    enum Page: Relux.Navigation.PathComponent {
        case info
        case details
    }
}
```

Set up your Relux container:

```swift
extension Anteater {
    private static var reluxContainerInstance: ReluxContainer {
        .init(
            logger: IoC.get(type: (any Relux.Logger).self)!,
            modules: .resolvedModules,
            routers: [
                Relux.Navigation.Router<UI.Dashboard.Navigation.Page>(),
                Relux.Navigation.Router<UI.Profile.Navigation.Page>()
            ]
        )
    }
}
```

### Controlling Navigation

Dispatch navigation actions as regular Relux actions:

```swift
Button(action: {
    Task {
        await action {
            Relux.Navigation.ProjectingRouter.Action.push(page: UI.Dashboard.Navigation.Page.info)
        }
    }
}) {
    Text("Info Page")
}
```

## The Relux Stack

This package is part of the Relux stack: the
[Relux](https://github.com/relux-works/swift-relux) unidirectional data-flow
architecture for Swift 6, a family of modules around it, and agent-ready testing
tools. The stack is how we build MVPs fast on agentic rails and then scale them
into enterprise-grade apps: Tuist workspaces, strict modularization, and a UDF
architecture proven in production for years. Browse the full picture in the
[Relux Works open-source catalog](https://relux.works/en/open-source/).

<!-- relux-ecosystem:start -->

## About Relux Works

This project is part of the open-source ecosystem of
[Relux Works](https://relux.works), an AI-native software development studio.
We build fixed-price MVPs, rescue vibe-coded apps, run local AI inference, and
train teams to work with coding agents. Much of the infrastructure behind that
work is open source.

- Full catalog: [relux.works/en/open-source](https://relux.works/en/open-source/)
- Agentic enablement: [agent harnesses & team training](https://relux.works/en/agentic-enablement/)
- Hire us the agent-native way: point your assistant at `https://api.relux.works/mcp`
- Contact: ivan@relux.works

<!-- relux-ecosystem:end -->

## Development Tools

- Swift Package Manager: builds and tests the SDK.
  - Build from repo root: `swift build`
  - Test from repo root: `swift test`
  - Package-local build: `cd SDK && swift build`
  - Package-local test: `cd SDK && swift test`
  - Artifacts: `.build/` or `SDK/.build/`
- ios-app-manager: scaffolds and maintains the sample iOS app.
  - Config: `Sample/ios-app-manager.json`
  - Setup: `cd Sample && make setup`
  - Build: `cd Sample && make build`
  - UI test: `cd Sample && make test`
  - Xcode/DerivedData artifacts: `Sample/Derived/`, `Sample/DerivedData/`
- task-board: local agent workflow board for this checkout.
  - Config: `task-board.config.json`
  - Board data: `.task-board/`
  - Both are local-only and ignored by git in this repository.

## License

ReluxRouter is released under the [MIT License](https://github.com/relux-works/swift-relux/blob/main/LICENSE).
