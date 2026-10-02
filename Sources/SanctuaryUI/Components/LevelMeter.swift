import SwiftUI

/// Small reusable level-meter bar. Level is 0.0 ... 1.0.
public struct LevelMeter: View {
    public var level: Float

    public init(level: Float) {
        self.level = level
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                Capsule()
                    .fill(level > 0.9 ? Color.red : Color.green)
                    .frame(width: geometry.size.width * CGFloat(min(1, max(0, level))))
            }
        }
        .frame(height: 6)
        .accessibilityLabel("Level")
        .accessibilityValue("\(Int(level * 100)) percent")
    }
}
