import SwiftUI

struct LevelCardView: View {
    let title: String
    let number: Int
    let pellets: Int
    let progress: Double
    let isPreview: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text(String(format: "%02d", number))
                    .font(.title2.weight(.black))
                Spacer()
                Label(isPreview ? "PREVIEW" : "WALK", systemImage: "figure.walk")
                    .font(.caption.weight(.heavy))
            }
            .foregroundStyle(.white.opacity(0.85))

            Image(systemName: "face.smiling.inverse")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.yellow)
                .shadow(color: .black.opacity(0.45), radius: 0, y: 4)
                .accessibilityHidden(true)

            Text(title.uppercased())
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 0, y: 3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                Label("\(pellets)", systemImage: "circle.fill")
                Label("\(pellets * 10)", systemImage: "star.fill")
            }
            .font(.headline.weight(.heavy))
            .foregroundStyle(.yellow)
            .accessibilityLabel("\(pellets) pellets, \(pellets * 10) possible points")

            VStack(spacing: 10) {
                HStack {
                    Text("BEST RUN")
                    Spacer()
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                }
                .font(.caption.weight(.black))
                ProgressView(value: progress)
                    .tint(.green)
                    .padding(8)
                    .background(.black.opacity(0.35), in: Capsule())
                    .overlay { Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 2) }
                    .accessibilityLabel("Best run")
            }
            .foregroundStyle(.white)
        }
        .padding(26)
        .frame(maxWidth: .infinity)
        .background(color.gradient, in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 21)
                .strokeBorder(.white.opacity(0.3), lineWidth: 2)
                .padding(7)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(.black.opacity(0.55), lineWidth: 4)
        }
        .shadow(color: .black.opacity(0.35), radius: 0, y: 8)
    }
}
