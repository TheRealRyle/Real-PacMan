import SwiftUI

struct CompletionSummaryView: View {
    let collected: Int
    let total: Int
    let distance: Double
    let rules: ModeProgress?
    let revealed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let fraction = revealed || reduceMotion ? min(1, max(0, Double(collected) / Double(max(1, total)))) : 0
        VStack(alignment: .leading, spacing: 18) {
            Text("RUN SUMMARY")
                .font(.caption.weight(.black)).tracking(1.5)
                .foregroundStyle(.cyan)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Label("Pellets collected", systemImage: "circle.fill")
                Spacer(minLength: 8)
                Text("\(collected) / \(total)").monospacedDigit()
            }
            .font(.subheadline.weight(.bold)).foregroundStyle(.white)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule().fill(collected == total ? Color.green : .yellow)
                    .scaleEffect(x: fraction, y: 1, anchor: .leading)
            }
            .frame(height: 8)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.65), value: revealed)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pellets collected")
            .accessibilityValue("\(collected) of \(total)")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                CompletionStat(title: "DISTANCE", value: "\(Int(distance.rounded()).formatted()) m", symbol: "shoeprints.fill", color: .cyan)
                if let rules, rules.activeElapsed > 0 {
                    let seconds = Int(rules.activeElapsed)
                    CompletionStat(title: "ACTIVE TIME", value: String(format: "%02d:%02d", seconds / 60, seconds % 60), symbol: "timer", color: .yellow)
                }
                if let rules, !rules.ghosts.isEmpty {
                    CompletionStat(title: "HEARTS LEFT", value: "\(rules.livesRemaining) / 3", symbol: "heart.fill", color: .pink)
                }
            }
        }
        .padding(20)
        .background(Color(red: 0.04, green: 0.10, blue: 0.22), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.cyan.opacity(0.2), lineWidth: 1) }
    }
}

private struct CompletionStat: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption2.weight(.heavy)).foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(.white).monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
