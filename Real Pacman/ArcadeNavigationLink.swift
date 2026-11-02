import SwiftUI

struct ArcadeNavigationLink<Destination: View, Label: View>: View {
    @ViewBuilder let destination: () -> Destination
    @ViewBuilder let label: () -> Label
    @State private var isPresented = false

    var body: some View {
        ArcadeActionButton { isPresented = true } label: { label() }
            .navigationDestination(isPresented: $isPresented) { destination() }
    }
}
