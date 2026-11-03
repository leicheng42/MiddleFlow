import AppKit
import SwiftUI

enum FlowTheme {
    static let ember = Color(red: 1.00, green: 0.51, blue: 0.18)
    static let emberDeep = Color(red: 0.92, green: 0.31, blue: 0.08)
    static let mint = Color(red: 0.34, green: 0.82, blue: 0.65)
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.075)
    static let graphite = Color(red: 0.12, green: 0.12, blue: 0.115)
    static let warmPaper = Color(red: 0.965, green: 0.945, blue: 0.91)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let subtleBorder = Color.primary.opacity(0.08)
    static let cardRadius: CGFloat = 20

    static let accentGradient = LinearGradient(
        colors: [ember, emberDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sidebarGradient = LinearGradient(
        colors: [
            Color(red: 0.105, green: 0.105, blue: 0.10),
            Color(red: 0.07, green: 0.07, blue: 0.067)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct FlowCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: FlowTheme.cardRadius, style: .continuous)
                    .fill(.background)
                    .overlay {
                        RoundedRectangle(cornerRadius: FlowTheme.cardRadius, style: .continuous)
                            .stroke(FlowTheme.subtleBorder, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.035), radius: 18, y: 7)
            }
    }
}

struct SectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(FlowTheme.ember)
            Text(title)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct StatusPill: View {
    let title: String
    let color: Color
    var pulse = false

    @State private var animate = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .overlay {
                    if pulse {
                        Circle()
                            .stroke(color.opacity(0.45), lineWidth: 1.5)
                            .scaleEffect(animate ? 2.15 : 1)
                            .opacity(animate ? 0 : 1)
                    }
                }
            Text(title)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(color.opacity(0.11), in: Capsule())
        .onAppear {
            guard pulse else { return }
            withAnimation(.easeOut(duration: 1.45).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

struct PreferenceRow<Control: View>: View {
    let icon: String
    let title: String
    let detail: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FlowTheme.ember)
                .frame(width: 32, height: 32)
                .background(FlowTheme.ember.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.vertical, 11)
    }
}

struct FlowToggle: View {
    @Binding var isOn: Bool
    var tint: Color = FlowTheme.ember

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? tint : Color.primary.opacity(0.14))
                    .frame(width: 40, height: 23)
                Circle()
                    .fill(.white)
                    .frame(width: 17, height: 17)
                    .padding(3)
                    .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "已开启" : "已关闭")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct FlowButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case quiet
    }

    var kind: Kind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(background)
            .overlay {
                if kind != .primary {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(FlowTheme.subtleBorder, lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .white
        case .secondary: return .primary
        case .quiet: return .secondary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .primary:
            FlowTheme.accentGradient
        case .secondary:
            Color.primary.opacity(0.055)
        case .quiet:
            Color.clear
        }
    }
}
