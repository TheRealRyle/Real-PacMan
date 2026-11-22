import SwiftUI

/// Each versioned selection card owns its download and refreshes from persistent packs.
struct ParcoursDownloadView: View {
    let route: GameRoute
    @State private var offline = OfflineMapStore()
    @State private var downloadRequested = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 10) {
            Label(offline.isDownloaded ? "DOWNLOADED · READY OFFLINE" : "OFFLINE MAP", systemImage: offline.isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                .font(.caption.weight(.heavy))
                .foregroundStyle(offline.isDownloaded ? Color.green : Color.white)
            Text(offline.status)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .accessibilityLabel("\(route.name): \(offline.status)")
            if offline.isDownloading {
                if let progress = offline.progress {
                    ProgressView(value: progress).tint(.cyan)
                        .accessibilityLabel("Offline map download progress")
                } else {
                    ProgressView().tint(.cyan).accessibilityLabel("Downloading offline map")
                }
                ArcadeActionButton { downloadRequested = false } label: {
                    Label("PAUSE DOWNLOAD", systemImage: "pause.fill")
                }.buttonStyle(ArcadeButtonStyle(color: .yellow))
            } else if !offline.isDownloaded {
                ArcadeActionButton { downloadRequested = true } label: {
                    Label(offline.canResume ? "RESUME DOWNLOAD" : "DOWNLOAD PARCOURS", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ArcadeButtonStyle(color: .cyan))
                .disabled(offline.isChecking || downloadRequested)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
        .task { await offline.refreshStatus(for: route) }
        .task(id: downloadRequested) {
            guard downloadRequested else { return }
            await offline.download(route)
            downloadRequested = false
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active { downloadRequested = false }
        }
        .onDisappear { downloadRequested = false }
    }
}
