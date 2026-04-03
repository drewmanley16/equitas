import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var style: Style = .gold
    let action: () -> Void

    enum Style { case gold, purple, ghost }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon) }
                Text(title).font(EquitasTheme.headlineFont)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(labelColor)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
        }
        .shadow(color: shadowColor, radius: 14)
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .gold:
            EquitasTheme.goldGradient
        case .purple:
            LinearGradient(
                colors: [EquitasTheme.purple, EquitasTheme.purpleDim],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .ghost:
            Color.white.opacity(0.06)
        }
    }

    private var labelColor: Color {
        switch style {
        case .gold:   return Color(red: 0.10, green: 0.06, blue: 0.00)
        case .purple: return .white
        case .ghost:  return EquitasTheme.gold
        }
    }

    private var strokeColor: Color {
        switch style {
        case .gold:   return EquitasTheme.goldLight.opacity(0.4)
        case .purple: return EquitasTheme.purple.opacity(0.4)
        case .ghost:  return EquitasTheme.gold.opacity(0.3)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .gold:   return EquitasTheme.gold.opacity(0.4)
        case .purple: return EquitasTheme.purple.opacity(0.5)
        case .ghost:  return .clear
        }
    }
}
