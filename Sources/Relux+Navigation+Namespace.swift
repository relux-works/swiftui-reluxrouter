import Relux

extension Relux {
    public enum Navigation {}
}

extension Relux.Navigation {
    public protocol RouterProtocol: Relux.HybridState {
        func restore() async
    }
    public protocol PathComponent: Equatable, Hashable, Sendable {}
}
