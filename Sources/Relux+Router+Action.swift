import Relux

extension Relux.Navigation.Router {
    public enum Action: ReluxAction {
        case push(page: Page, allowingDuplicates: Bool = false)
        case set(pages: [Page])
        case removeLast(count: Int = 1)
    }
}
