# Relux SwiftUI Router

This documentation covers two navigation router implementations: `ProjectingRouter` and `Router`. Both are part of the `Relux.Navigation` namespace and conform to the `RouterProtocol` for use with [Relux](https://github.com/relux-works/swift-relux), a unidirectional data flow architectural library designed to work seamlessly with Swift 6's concurrency model and tailored for use within SwiftUI applications.

## ProjectingRouter

`ProjectingRouter` is a navigation router that maintains both a navigation path for use within SwiftUI navigation stack, and a projected path – a version of the path useful for inspection. Available from iOS 16, macOS 13, watchOS 9, tvOS 16.

### Declaration

```swift
@MainActor
public final class ProjectingRouter<Page>: Relux.Navigation.RouterProtocol, ObservableObject where Page: PathComponent, Page: Sendable
```

### Relux Actions

```swift
public enum Action: Relux.Action {
    case push(page: Page, allowingDuplicates: Bool = false)
    case set(pages: [Page])
    case removeLast(count: Int = 1)
}
```

## Router

`Router` is a simpler navigation router available from iOS 17, macOS 14, watchOS 10, tvOS 17, and macCatalyst 17.

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

The routers can be used in conjunction with SwiftUI's `NavigationStack` or `NavigationSplitView` to create dynamic navigation experiences.

Both routers can be used to manage navigation in SwiftUI applications. The `ProjectingRouter` provides additional functionality for handling external pages and preventing duplicates – use it with SwiftUI reference semantics environment `@EnvironmentObject`. The `Router` offers a simpler API for basic navigation needs within unified SwiftUI environment `@Environment`.

### Initialization and Connection to Relux 

To use either router, connect the instances to Relux state machine on container initialization, attach to views through corresponding environment-access modifier. On initialization, resolve generic page with concrete type specific for your app.

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

// namespace
extension UI.Dashboard { enum Navigation {} }
extension UI.Profile { enum Navigation { } }

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

### Controlling navigation

To control the navigation programmatically, dispatch the navigation action as usual Relux action:

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

## License

ReluxRouter is released under the [MIT License](https://github.com/relux-works/swift-relux/blob/main/LICENSE).
