import SwiftUI

struct RouteLibraryView: View {
    @Environment(GameStore.self) private var game
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedID: UUID?
    private let previewID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var ids: [UUID] {
        game.archive.routes.isEmpty ? [previewID] : game.archive.routes.map(\.id)
    }

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
                        Text("LEVELS")
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
                            if game.archive.routes.isEmpty {
                                LevelCardView(title: "Your first adventure", number: 1, pellets: 30,
                                              progress: 0, isPreview: true, color: .indigo)
                                    .scrollTransition(.interactive, axis: .horizontal) { [reduceMotion] content, phase in
                                        content
                                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.92))
                                            .rotationEffect(.degrees(reduceMotion ? 0 : phase.value * 3))
                                    }
                                    .containerRelativeFrame(.horizontal)
                                    .id(previewID)
                            } else {
                                ForEach(game.archive.routes) { route in
                                    LevelCardView(title: route.name,
                                                  number: (game.archive.routes.firstIndex(where: { $0.id == route.id }) ?? 0) + 1,
                                                  pellets: route.pellets.count,
                                                  progress: bestProgress(route), isPreview: false,
                                                  color: .indigo)
                                        .scrollTransition(.interactive, axis: .horizontal) { [reduceMotion] content, phase in
                                        content
                                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.92))
                                            .rotationEffect(.degrees(reduceMotion ? 0 : phase.value * 3))
                                    }
                                    .containerRelativeFrame(.horizontal)
                                        .id(route.id)
                                }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.bottom, 12)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $selectedID)
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, 28, for: .scrollContent)
                    .scrollClipDisabled()
                    .phaseAnimator([0, 1, 2], trigger: selectedID) { [reduceMotion] content, phase in
                        content
                            .scaleEffect(reduceMotion ? 1 : (phase == 1 ? 1.025 : 1))
                            .offset(y: reduceMotion ? 0 : (phase == 1 ? -5 : 0))
                    } animation: { _ in
                        reduceMotion ? .linear(duration: 0) : .spring(response: 0.32, dampingFraction: 0.45)
                    }
                    .arcadeEntrance(delay: 0.12)

                    HStack(spacing: 24) {
                        Button("Previous level", systemImage: "chevron.left") { move(-1) }
                            .labelStyle(.iconOnly)
                            .disabled(currentIndex == 0)
                            .opacity(currentIndex == 0 ? 0.4 : 1)
                        Text("\(currentIndex + 1) / \(ids.count)")
                            .font(.title3.weight(.black))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .accessibilityLabel("Level \(currentIndex + 1) of \(ids.count)")
                        Button("Next level", systemImage: "chevron.right") { move(1) }
                            .labelStyle(.iconOnly)
                            .disabled(currentIndex == ids.count - 1)
                            .opacity(currentIndex == ids.count - 1 ? 0.4 : 1)
                    }
                    .buttonStyle(ArcadeButtonStyle(color: .cyan))
                    .arcadeEntrance(delay: 0.22)

                    if let route = game.archive.routes.first(where: { $0.id == ids[currentIndex] }) {
                        ArcadeNavigationLink { RouteDetailView(route: route).toolbar(.visible, for: .navigationBar) } label: {
                            Label("LET'S GO", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ArcadeButtonStyle(color: .green))
                        .padding(.horizontal, 28)
                    } else {
                        VStack(spacing: 8) {
                            Text("YOUR NEXT ADVENTURE STARTS HERE")
                                .font(.headline.weight(.black))
                            Text("Level card preview · your routes will appear here.")
                                .font(.subheadline)
                        }
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 28)
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
        .onAppear { if selectedID == nil { selectedID = ids.first } }
        .onChange(of: ids) { selectedID = ids.first }
        .onChange(of: selectedID) { old, new in
            if let old, let new, old != new, ids.contains(old), ids.contains(new) {
                ArcadeAudio.shared.play(.level)
            }
        }
    }

    private func move(_ offset: Int) {
        let index = min(max(currentIndex + offset, 0), ids.count - 1)
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.62)) { selectedID = ids[index] }
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
