import SwiftUI

struct ParcoursLocationView: View {
    let candidate: ParcoursCandidate

    var body: some View {
        ArcadePage(title: "PARCOURS", symbol: "map.fill") {
            ArcadePanel(title: candidate.name.uppercased()) {
                Label("LOCATION PLANNED", systemImage: "mappin.circle.fill")
                    .foregroundStyle(.yellow)
                Text(candidate.description)
                Text("The boundary, public walking paths, starting point and pellets are still being prepared.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                Text("Explore will be available once the parcours has been mapped and checked.")
                    .font(.caption)
            }
            .arcadeEntrance(delay: 0.1)
        }
    }
}
