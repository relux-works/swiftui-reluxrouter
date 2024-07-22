import Relux

extension Relux.Navigation.Router {
    func internalReduce(with action: Relux.Navigation.Router<Page>.Action) {
        switch action {
            case let .push(page, allowingDuplicates):
                switch allowingDuplicates {
                    case true:
                        self.pathProjection.append(.known(page))
                    case false:
                        if self.pathProjection.contains(.known(page)) { return }
                        self.pathProjection.append(.known(page))
                }

            case let .set(pages):
                self.pathProjection = pages.map { .known($0) }
                self.path = .init(pages)

            case let .removeLast(count):
                let itemsCountToRemove = min(count, self.pathProjection.count)
                self.pathProjection.removeLast(itemsCountToRemove)
        }
    }
}
