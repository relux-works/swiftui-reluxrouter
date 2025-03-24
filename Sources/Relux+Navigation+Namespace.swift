import Relux

extension Relux {
    public enum Navigation {}
}

extension Relux.Navigation {
    public protocol RouterProtocol: Relux.HybridState {}
    public protocol PathComponent: Equatable, Hashable, Sendable {}
}
