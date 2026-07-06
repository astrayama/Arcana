import SwiftUI

// MARK: - Primary buttons (`.bgold`, `.bpurp`, `.bglass`)

struct GoldButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .bodyFont(15, weight: .heavy)
                .foregroundStyle(Color(hex: 0x1C1204))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Arcana.goldGradient)
                .shimmer()
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: Arcana.Palette.gold.opacity(0.26), radius: 11)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PurpleButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .bodyFont(15, weight: .heavy)
                .foregroundStyle(Color(hex: 0x140E20))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Arcana.purpleGradient)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: Arcana.Palette.purple.opacity(0.25), radius: 11)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct GlassButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .bodyFont(14, weight: .bold)
                .foregroundStyle(Arcana.Palette.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color(hex: 0x252537).opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Arcana.Palette.fieldStroke, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Chips (`.hchip`) & segmented control (`.seg`)

struct Chip: View {
    let label: String
    var isOn = false
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            Text(label)
                .bodyFont(12, weight: .bold)
                .foregroundStyle(isOn ? Arcana.Palette.purpleSoft : Arcana.Palette.muted)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(
                    Capsule().fill(isOn ? Arcana.Palette.purple.opacity(0.14)
                                        : Arcana.Palette.glassFill.opacity(0.5))
                )
                .overlay(
                    Capsule().strokeBorder(
                        isOn ? Arcana.Palette.purple.opacity(0.6) : Arcana.Palette.fieldStroke,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

/// Upright / Reversed segmented toggle.
struct OrientationSegment: View {
    @Binding var orientation: Orientation

    var body: some View {
        HStack(spacing: 0) {
            segment(.upright)
            segment(.reversed)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(hex: 0x252537).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Arcana.Palette.fieldStroke, lineWidth: 1)
        )
    }

    private func segment(_ value: Orientation) -> some View {
        let isOn = orientation == value
        return Button {
            guard !isOn else { return }
            Haptics.tick()
            withAnimation(.snappy(duration: 0.2)) { orientation = value }
        } label: {
            Text("\(value.arrow) \(value.label)")
                .bodyFont(13, weight: .bold)
                .foregroundStyle(isOn ? Arcana.Palette.purpleSoft : Arcana.Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isOn ? Arcana.Palette.purple.opacity(0.24) : .clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI insight disclosure ("✦ AI insight ⌄" — collapsible extra)

struct InsightDisclosure: View {
    let title: String
    /// Loads the insight text lazily on first expansion.
    let loadInsight: () async -> String

    @State private var expanded = false
    @State private var insight: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.3)) { expanded.toggle() }
                if insight == nil {
                    Task { insight = await loadInsight() }
                }
            } label: {
                HStack(spacing: 8) {
                    SparkleText(size: 14, color: Arcana.Palette.purpleSoft)
                    Text(title)
                        .bodyFont(13.5, weight: .bold)
                        .foregroundStyle(Arcana.Palette.purpleSoft)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Arcana.Palette.faint)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 17).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Group {
                    if let insight {
                        Text(insight)
                            .bodyFont(13.5)
                            .foregroundStyle(Arcana.Palette.muted)
                            .lineSpacing(4)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().tint(Arcana.Palette.purpleSoft)
                            Text("Reading the card…")
                                .bodyFont(13)
                                .foregroundStyle(Arcana.Palette.faint)
                        }
                    }
                }
                .padding(.horizontal, 17)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glass()
    }
}

// MARK: - Text field / editor styling

struct GlassFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Arcana.Palette.fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Arcana.Palette.fieldStroke, lineWidth: 1)
            )
    }
}

extension View {
    func glassField() -> some View { modifier(GlassFieldBackground()) }
}
