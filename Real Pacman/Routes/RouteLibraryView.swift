import SwiftUI

struct RouteLibraryView: View {
    @Environment(GameStore.self) private var game
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(GameSettings.self) private var settings
    @State private var selectedID: UUID?
    @State private var prototype: GameRoute?
    @State private var prototypeError: String?
    private var entries: [ParcoursCandidate] {
        ParcoursCatalogue.entries(saved: game.archive.routes, prototype: prototype)
    }

    private var ids: [UUID] { entries.map(\.id) }

    private var currentIndex: Int {
        ids.firstIndex(of: selectedID ?? ids[0]) ?? 0
    }

    var body: some View {
        ZStack {
            ArcadeBackground()
            ScrollView {
                VStack(spacing: 28) {
                    HStack {
                        ArcadeActionButton { dismiss() } label: { Label("Back", systemImage: "arrow.left") }
                            .labelStyle(.iconOnly)
                            .buttonStyle(ArcadeButtonStyle(color: .yellow))
                            .accessibilityLabel("Back to main menu")
                        Spacer()
                        Text("PARCOURS")
                            .font(.system(.largeTitle, design: .rounded, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 0, y: 3)
                        Spacer()
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                            .frame(width: 60)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 20)
                    .arcadeEntrance(delay: 0.03)

                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 20) {
                            ForEach(entries) { entry in
                                LevelCardView(
                                    title: entry.name,
                                    number: (ids.firstIndex(of: entry.id) ?? 0) + 1,
                                    pellets: entry.route?.pellets.count,
                                    progress: entry.route.map(bestProgress) ?? 0,
                                    isPreview: entry.route?.parcours?.fieldVerified == false || entry.route == nil,
                                    color: entry.id == ParcoursCatalogue.verneyID ? .indigo : .blue,
                                    subtitle: entry.description,
                                    status: entry.route == nil ? "PLANNED" :
                                        (entry.route?.parcours?.fieldVerified == false ? "MAP DRAFT" : "SAVED"),
                                    points: entry.route?.totalPoints,
                                    distance: entry.route.map { route in
                                        "\(Int(route.distanceMeters.rounded())) m of paths"
                                    }, previewRoute: entry.route)
                                    .scrollTransition(.interactive, axis: .horizontal) { [reduceMotion] content, phase in
                                        content
                                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.97))
                                    }
                                    .containerRelativeFrame(.horizontal)
                                    .id(entry.id)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.bottom, 12)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    // Native scrolling preserves flick velocity and supplies progressive
                    // resistance and spring-back at both boundaries.
                    .scrollBounceBehavior(.always, axes: .horizontal)
                    .scrollPosition(id: $selectedID)
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, 28, for: .scrollContent)
                    .scrollClipDisabled()
                    .arcadeEntrance(delay: 0.12)

                    HStack(spacing: 24) {
                        ArcadeActionButton(sound: nil) { move(-1) } label: {
                            Label("Previous level", systemImage: "chevron.left")
                        }
                            .labelStyle(.iconOnly)
                            .disabled(currentIndex == 0)
                            .opacity(currentIndex == 0 ? 0.4 : 1)
                        Text("\(currentIndex + 1) / \(ids.count)")
                            .font(.title3.weight(.black))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .accessibilityLabel("Level \(currentIndex + 1) of \(ids.count)")
                        ArcadeActionButton(sound: nil) { move(1) } label: {
                            Label("Next level", systemImage: "chevron.right")
                        }
                            .labelStyle(.iconOnly)
                            .disabled(currentIndex == ids.count - 1)
                            .opacity(currentIndex == ids.count - 1 ? 0.4 : 1)
                    }
                    .buttonStyle(ArcadeButtonStyle(color: .cyan))
                    .arcadeEntrance(delay: 0.22)

                    let entry = entries[currentIndex]
                    if let route = entry.route {
                        ArcadeNavigationLink { ParcoursModeView(route: route) } label: {
                            Label("CHOOSE MODE", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ArcadeButtonStyle(color: .green))
                        .padding(.horizontal, 28)
                        Text(route.parcours?.fieldVerified == false
                             ? "Map draft · paths awaiting on-foot review"
                             : "Download this parcours above for offline play")
                            .font(.caption).foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center).padding(.horizontal, 28)
                    } else {
                        ArcadeNavigationLink { ParcoursLocationView(candidate: entry) } label: {
                            Label("VIEW LOCATION", systemImage: "map").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ArcadeButtonStyle(color: .cyan))
                        .padding(.horizontal, 28)
                    }

                    if let prototypeError {
                        Text(prototypeError).font(.caption).foregroundStyle(.yellow).padding(.horizontal, 28)
                    }
                    ArcadeActionButton {
                        Task { await game.fetchRoutes(server: settings.serverURL) }
                    } label: {
                        Label(game.isLoading ? "REFRESHING…" : "REFRESH PARCOURS", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(ArcadeButtonStyle(color: .cyan))
                    .disabled(game.isLoading || settings.serverURL.isEmpty)
                    .opacity(settings.serverURL.isEmpty ? 0.5 : 1)
                    if settings.serverURL.isEmpty {
                        Text("Add a route server in Settings to load more published parcours.")
                            .font(.caption).foregroundStyle(.white.opacity(0.8)).padding(.horizontal, 28)
                    }

                    if game.archive.activeSession != nil {
                        ArcadeNavigationLink { GameplayView().toolbar(.visible, for: .navigationBar) } label: { Text("RESUME WALK") }
                            .buttonStyle(ArcadeButtonStyle())
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if prototype == nil {
                do { prototype = try ParcoursCatalogue.loadVerney() }
                catch { prototypeError = "The bundled map draft could not be loaded." }
            }
            if selectedID == nil { selectedID = ids.first }
        }
        .onChange(of: ids) { selectedID = ids.first }
        .onChange(of: selectedID) { old, new in
            if let old, let new, old != new, ids.contains(old), ids.contains(new) {
                ArcadeAudio.shared.play(.level)
            }
        }
    }

    private func move(_ offset: Int) {
        let index = min(max(currentIndex + offset, 0), ids.count - 1)
        withAnimation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0)) { selectedID = ids[index] }
    }

    private func bestProgress(_ route: GameRoute) -> Double {
        guard !route.pellets.isEmpty else { return 0 }
        let sessions = game.archive.results + [game.archive.activeSession].compactMap { $0 }
        let count = sessions.filter { $0.route.id == route.id && $0.route.version == route.version }
            .map { $0.collectedPelletIDs.count }.max() ?? 0
        return min(1, Double(count) / Double(route.pellets.count))
    }
}

#Preview {
    NavigationStack { RouteLibraryView() }
        .environment(GameStore())
        .environment(GameSettings())
}
