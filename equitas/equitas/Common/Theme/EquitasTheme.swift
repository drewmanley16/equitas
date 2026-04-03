import SwiftUI

enum EquitasTheme {
    // MARK: - Colors
    static let background    = Color(red: 0.04, green: 0.00, blue: 0.08)
    static let backgroundMid = Color(red: 0.08, green: 0.02, blue: 0.14)
    static let gold          = Color(red: 0.83, green: 0.69, blue: 0.22)
    static let goldLight     = Color(red: 0.95, green: 0.85, blue: 0.50)
    static let purple        = Color(red: 0.48, green: 0.31, blue: 1.00)
    static let purpleDim     = Color(red: 0.30, green: 0.18, blue: 0.60)
    static let glassStroke   = Color.white.opacity(0.12)
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.55)

    // MARK: - Gradients
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.06, green: 0.01, blue: 0.12),
            Color(red: 0.02, green: 0.00, blue: 0.06),
            Color(red: 0.00, green: 0.00, blue: 0.02)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldGradient = LinearGradient(
        colors: [goldLight, gold, Color(red: 0.65, green: 0.50, blue: 0.10)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Typography
    static let displayFont  = Font.system(size: 40, weight: .bold,    design: .rounded)
    static let titleFont    = Font.system(size: 24, weight: .bold,    design: .rounded)
    static let headlineFont = Font.system(size: 17, weight: .semibold,design: .rounded)
    static let bodyFont     = Font.system(size: 15, weight: .regular, design: .rounded)
    static let captionFont  = Font.system(size: 12, weight: .medium,  design: .rounded)
    static let monoFont     = Font.system(size: 13, weight: .regular, design: .monospaced)

    // MARK: - Layout
    static let cardPadding: CGFloat    = 20
    static let screenPadding: CGFloat  = 24
    static let cornerRadius: CGFloat   = 20
}

// MARK: - Glass card modifier
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: EquitasTheme.cornerRadius)
                    .fill(EquitasTheme.cardGradient)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: EquitasTheme.cornerRadius)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: EquitasTheme.cornerRadius)
                    .strokeBorder(EquitasTheme.glassStroke, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCard()) }
    func goldGlow(radius: CGFloat = 20) -> some View {
        shadow(color: EquitasTheme.gold.opacity(0.5), radius: radius)
    }
    func purpleGlow(radius: CGFloat = 20) -> some View {
        shadow(color: EquitasTheme.purple.opacity(0.6), radius: radius)
    }
}

// MARK: - Animated star field
struct StarFieldView: View {
    private struct Star: Identifiable {
        let id = UUID()
        let x, y, size, baseOpacity: CGFloat
        let speed: Double
    }
    private let stars: [Star] = (0..<140).map { _ in
        Star(
            x: .random(in: 0...1),
            y: .random(in: 0...1),
            size: .random(in: 0.5...2.5),
            baseOpacity: .random(in: 0.15...0.85),
            speed: .random(in: 0.4...1.4)
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for star in stars {
                    let twinkle = (sin(t * star.speed + star.x * 10) + 1) / 2
                    let op = star.baseOpacity * (0.4 + 0.6 * twinkle)
                    let r = CGRect(
                        x: star.x * size.width  - star.size / 2,
                        y: star.y * size.height - star.size / 2,
                        width: star.size, height: star.size
                    )
                    ctx.fill(Path(ellipseIn: r), with: .color(.white.opacity(op)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Cosmic background (reusable)
struct CosmicBackground: View {
    var body: some View {
        ZStack {
            EquitasTheme.backgroundGradient.ignoresSafeArea()
            Circle()
                .fill(EquitasTheme.purple.opacity(0.14))
                .blur(radius: 90)
                .frame(width: 320)
                .offset(x: -90, y: -220)
            Circle()
                .fill(EquitasTheme.gold.opacity(0.06))
                .blur(radius: 110)
                .frame(width: 280)
                .offset(x: 110, y: 220)
            Circle()
                .fill(EquitasTheme.purple.opacity(0.09))
                .blur(radius: 70)
                .frame(width: 200)
                .offset(x: 130, y: -80)
            StarFieldView()
        }
    }
}
