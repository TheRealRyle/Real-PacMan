import SwiftUI
import CoreLocation

struct GameplayMapView: View {
    let route: GameRoute
    let collected: Set<UUID>
    let player: RouteCoordinate?
    var isDemo = false
    @Environment(GameSettings.self) private var settings
    @State private var indicator: PelletIndicator?
    @State private var cameraRequest: RouteMapCameraRequest?
    @State private var mapGeneration = UUID()
    @State private var streetMapLoaded = false
    @State private var showsSavedMap = false
    @State private var handledFirstLocation = false

    var body: some View {
        RouteMapView(route: route, collected: collected, cameraRequest: cameraRequest,
                     simulatedPlayer: isDemo ? player : nil, usesDeviceLocation: !isDemo,
                     followZoom: settings.mapZoom, isGameplay: true, guidancePlayer: player,
                     onIndicatorChange: { indicator = $0 }) { available in
            streetMapLoaded = available
            showsSavedMap = !available
        }
        .id(mapGeneration)
        .overlay {
            if showsSavedMap {
                ParcoursPreview(route: route, collected: collected, player: player, height: nil)
                    .background(.indigo)
            }
        }
        .overlay(alignment: .topLeading) {
            if let indicator, !showsSavedMap { NextPelletIndicator(indicator: indicator) }
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name).font(.subheadline.weight(.bold))
                if isDemo {
                    Label("DEMO · arrow controls", systemImage: "dpad.fill")
                        .font(.caption.weight(.bold))
                }
                if showsSavedMap {
                    Text("Street map unavailable · saved layout shown")
                        .font(.caption)
                    Button("Retry street map", systemImage: "arrow.clockwise") {
                        streetMapLoaded = false
                        showsSavedMap = false
                        indicator = nil
                        mapGeneration = UUID()
                    }
                    .buttonStyle(ArcadeButtonStyle(color: .cyan))
                } else if !streetMapLoaded {
                    Text("Loading street map…").font(.caption)
                } else if route.parcours?.fieldVerified == false {
                    Text("Map draft · paths awaiting on-foot review").font(.caption)
                }
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(Color(red: 0.04, green: 0.09, blue: 0.18).opacity(0.95),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.15), lineWidth: 1) }
            .padding(12)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 10) {
                Button("Show whole parcours", systemImage: "map") {
                    handledFirstLocation = true
                    cameraRequest = RouteMapCameraRequest(target: .parcours)
                }
                Button(isDemo ? "Follow demo player" : "Follow my location", systemImage: "location.fill") {
                    handledFirstLocation = true
                    cameraRequest = RouteMapCameraRequest(target: .player)
                }
                .disabled(player == nil)
                .opacity(player == nil ? 0.5 : 1)
                .accessibilityHint(isDemo ? "Centers the map on the demo player." : "Tap again to rotate the map with your heading.")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(GameplayMapButtonStyle())
            .padding(12)
            .padding(.bottom, 32)
            .allowsHitTesting(!showsSavedMap)
            .opacity(showsSavedMap ? 0 : 1)
            .accessibilityHidden(showsSavedMap)
        }
        .task(id: mapGeneration) {
            // Keep the fully bundled layout usable if the basemap cannot finish loading.
            do { try await Task.sleep(for: .seconds(15)) }
            catch { return }
            if !streetMapLoaded { showsSavedMap = true }
        }
        .onChange(of: player, initial: true) {
            guard let player, !handledFirstLocation else { return }
            handledFirstLocation = true
            // Start close to the player when they are at the parcours. Otherwise show
            // the destination, rather than jumping to a distant GPS fix on launch.
            if route.mapCoordinates.contains(where: { $0.location.distance(from: player.location) < 500 }) {
                cameraRequest = RouteMapCameraRequest(target: .player)
            }
        }
    }
}
