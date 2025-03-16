import Relux
import SwiftUI

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
extension View {
    /// Presents a stack of modal sheets managed by a ModalRouter.
    /// - Parameters:
    ///   - router: The ModalRouter instance managing the modal stack.
    ///   - depth: Number of nested sheets to support (1-8).
    ///   - content: A view builder that creates the content for each modal sheet.
    @ViewBuilder
    public func sheetStack<Page>(
        router: Relux.Navigation.ModalRouter<Page>,
        @ViewBuilder content: @escaping (Page) -> some View
    ) -> some View where Page: Relux.Navigation.ModalComponent {
        modifier(
            ModalStackModifier(
                router: router,
                depth: min(max(router.maxDepth, 1), 8),
                content: content
            )
        )
    }
}

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, macCatalyst 17, *)
private struct ModalStackModifier<Page: Relux.Navigation.ModalComponent, InternalContent: View>: ViewModifier {
    let router: Relux.Navigation.ModalRouter<Page>
    let depth: Int
    let content: (Page) -> InternalContent

    func body(content: Content) -> some View {
        content
            .sheet(item: router[page: 0]) { page in
                self.content(page)
                    .modifier(Level1(router: router, content: self.content))
            }
    }

    private struct Level1: ViewModifier {
        let router: Relux.Navigation.ModalRouter<Page>
        let content: (Page) -> InternalContent

        func body(content: Content) -> some View {
            content
                .sheet(item: router[page: 1]) { page in
                    self.content(page)
                        .modifier(Level2(router: router, content: self.content))
                }
        }
    }

    private struct Level2: ViewModifier {
        let router: Relux.Navigation.ModalRouter<Page>
        let content: (Page) -> InternalContent

        func body(content: Content) -> some View {
            content
                .sheet(item: router[page: 2]) { page in
                    self.content(page)
                        .modifier(Level3(router: router, content: self.content))
                }
        }
    }

    private struct Level3: ViewModifier {
        let router: Relux.Navigation.ModalRouter<Page>
        let content: (Page) -> InternalContent

        func body(content: Content) -> some View {
            content
                .sheet(item: router[page: 3]) { page in
                    self.content(page)
                        .modifier(Level4(router: router, content: self.content))
                }
        }
    }

    private struct Level4: ViewModifier {
        let router: Relux.Navigation.ModalRouter<Page>
        let content: (Page) -> InternalContent

        func body(content: Content) -> some View {
            content
                .sheet(item: router[page: 4]) { page in
                    self.content(page)
                        .modifier(Level5(router: router, content: self.content))
                }
        }
    }

    private struct Level5: ViewModifier {
        let router: Relux.Navigation.ModalRouter<Page>
        let content: (Page) -> InternalContent

        func body(content: Content) -> some View {
            content
                .sheet(item: router[page: 5]) { page in
                    self.content(page)
                        .modifier(Level6(router: router, content: self.content))
                }
        }
    }

    private struct Level6: ViewModifier {
        let router: Relux.Navigation.ModalRouter<Page>
        let content: (Page) -> InternalContent

        func body(content: Content) -> some View {
            content
                .sheet(item: router[page: 6]) { page in
                    self.content(page)
                        .modifier(Level7(router: router, content: self.content))
                }
        }
    }

    private struct Level7: ViewModifier {
        let router: Relux.Navigation.ModalRouter<Page>
        let content: (Page) -> InternalContent

        func body(content: Content) -> some View {
            content
                .sheet(item: router[page: 7]) { page in
                    self.content(page)
                }
        }
    }
}
