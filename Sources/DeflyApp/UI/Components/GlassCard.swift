import SwiftUI

struct GlassCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundStyle)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                        .strokeBorder(
                            Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                    }
            }
            .shadow(
                color: .black.opacity(
                    reduceTransparency ? 0 : 0.06
                ),
                radius: 12,
                y: 4
            )
    }

    private var backgroundStyle: AnyShapeStyle {
        if reduceTransparency {
            AnyShapeStyle(
                Color(nsColor: .windowBackgroundColor)
            )
        } else {
            AnyShapeStyle(.regularMaterial)
        }
    }
}
