import Relux

extension Relux {
    public enum Navigation {}
}

extension Relux.Navigation {
    public protocol RouterProtocol: Relux.State {}
    public protocol PathComponent: Equatable, Hashable, Sendable {}
}
