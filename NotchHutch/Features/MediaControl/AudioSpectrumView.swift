import SwiftUI

struct AudioSpectrumView: View {
    let isPlaying: Bool
    @EnvironmentObject var settings: SettingsManager
    private let barCount = 4
    private let minHeight: CGFloat = 2
    private let maxHeight: CGFloat = 16

    var body: some View {
        Group {
            if isPlaying {
                // TimelineView suspends automatically when the view is not
                // being drawn (occluded window, display asleep) — unlike a
                // Timer in .common mode, which fires forever.
                TimelineView(.periodic(from: .now, by: 0.15)) { context in
                    bars(heights: randomHeights())
                        .animation(.easeInOut(duration: 0.15), value: context.date)
                }
            } else {
                bars(heights: Array(repeating: minHeight, count: barCount))
                    .animation(.easeOut(duration: 0.2), value: isPlaying)
            }
        }
        .frame(height: maxHeight)
    }

    private func bars(heights: [CGFloat]) -> some View {
        HStack(spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(settings.colorSpectrum)
                    .frame(
                        width: 2.5,
                        height: heights[safe: index] ?? minHeight
                    )
            }
        }
    }

    private func randomHeights() -> [CGFloat] {
        (0..<barCount).map { index in
            // Create a more realistic spectrum pattern
            // Lower frequencies (left) tend to be higher, higher frequencies (right) vary more
            let baseHeight: CGFloat
            if index < 2 {
                baseHeight = CGFloat.random(in: maxHeight * 0.6...maxHeight)
            } else {
                baseHeight = CGFloat.random(in: maxHeight * 0.3...maxHeight * 0.8)
            }
            return max(minHeight, min(maxHeight, baseHeight))
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
