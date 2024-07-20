import Combine
import Relux
import SwiftUI

extension Relux.Navigation.Router {
    public enum ProjectedPage: Equatable {
        case known(Page)
        case external
    }
}

extension Relux.Navigation {
    @MainActor
    public final class Router<Page>: Relux.Navigation.RouterProtocol where Page: PathComponent {
        public typealias Page = Page
        private var pipelines: Set<AnyCancellable> = []

        @Published public var path: NavigationPath = .init()
        @Published public var pathProjection: [ProjectedPage] = []

        public init() {
            initPipelines()
        }
    }
}

extension Relux.Navigation.Router {
    public func reduce(with action: ReluxAction) async {
        switch action as? Relux.Navigation.Router<Page>.Action {
            case .none: break
            case let .some(action):
                print(">>> reduce with action: \(action)")
                internalReduce(with: action)
        }
    }

    public func cleanup() async {
    }
}

extension Relux.Navigation.Router {
    private func initPipelines() {
        $path
            .receive(on: DispatchQueue.main)
            .print(">>> path: ")
            .sink { [weak self] path in
                guard let self else { return }
                let pagesDiff = path.count - self.pathProjection.count
                switch pagesDiff {
                    case 0: break
                    case ..<0: self.pathProjection.removeLast(abs(pagesDiff))
                    default:
                        let pages = Array<ProjectedPage>(repeating: .external, count: pagesDiff)
                        self.pathProjection.append(contentsOf: pages)
                }
            }
            .store(in: &pipelines)

        $pathProjection
            .receive(on: DispatchQueue.main)
            .print(">>> projection: ")
            .sink { [weak self] projectedPath in
                guard let self else { return }
                let pagesDiff = projectedPath.count - self.path.count
                switch pagesDiff {
                    case 0: break
                    case ..<0: self.path.removeLast(abs(pagesDiff))
                    default:
                        projectedPath
                            .suffix(pagesDiff)
                            .forEach { page in
                                switch page {
                                    case .external: return
                                    case let .known(p): self.path.append(p)
                                }
                            }
                }
            }
            .store(in: &pipelines)
    }
}
