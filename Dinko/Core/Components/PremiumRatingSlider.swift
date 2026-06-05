import SwiftUI

/// Premium custom slider for skill rating (0–100).
/// Replaces the default SwiftUI Slider with gradient fill, animated thumb,
/// haptic feedback at level boundaries, and a live level-name label.
struct PremiumRatingSlider: View {
    @Binding var value: Double   // 0–100

    /// When false the level-name label is hidden (use when the parent
    /// already shows a large percentage number, e.g. RateSkillView).
    var showLevelLabel: Bool = true

    /// When false the Beginner / Elite end labels are hidden (use when
    /// the parent renders its own tier milestone labels).
    var showRails: Bool = true

    /// Called with the committed value when the user lifts their finger.
    var onCommit: ((Double) -> Void)? = nil

    @State private var isDragging = false
    @State private var lastBand: Int = -1   // for milestone haptics

    private let trackH: CGFloat  = 6
    private let thumbD: CGFloat  = 26

    var body: some View {
        VStack(spacing: 8) {
            if showLevelLabel { labelSlot }
            track
            if showRails { rails }
        }
    }

    // MARK: - Label slot (level name ↔ live %-pill while dragging)

    private var labelSlot: some View {
        ZStack {
            if isDragging {
                Text("\(Int(value.rounded()))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: AppColors.primary.opacity(0.28), radius: 6, y: 2)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else {
                Text(levelName(value))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(levelColor(value))
                    .id(levelName(value))
                    .transition(.asymmetric(
                        insertion: .push(from: .trailing).combined(with: .opacity),
                        removal: .push(from: .leading).combined(with: .opacity)
                    ))
            }
        }
        .frame(height: 26)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isDragging)
        .animation(.spring(response: 0.3,  dampingFraction: 0.75), value: levelName(value))
    }

    // MARK: - Track

    private var track: some View {
        GeometryReader { geo in
            let w         = geo.size.width
            let half      = thumbD / 2
            let usable    = w - thumbD             // track spans [half … w-half]
            let progress  = CGFloat(value / 100)
            let thumbX    = half + progress * usable
            let fillW     = progress * usable
            let midY      = geo.size.height / 2

            ZStack {
                // ── Inset groove track ──────────────────────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: trackH / 2)
                        .fill(AppColors.background)
                        .frame(width: usable, height: trackH)
                    RoundedRectangle(cornerRadius: trackH / 2)
                        .stroke(AppColors.background, lineWidth: 0.5)
                        .frame(width: usable, height: trackH)
                        .shadow(
                            color: AppColors.neumorphicInnerDark.opacity(0.5),
                            radius: 2, x: 1, y: 1
                        )
                        .shadow(
                            color: AppColors.neumorphicInnerLight.opacity(0.5),
                            radius: 2, x: -1, y: -1
                        )
                        .clipShape(RoundedRectangle(cornerRadius: trackH / 2))
                        .frame(width: usable, height: trackH)
                }
                .position(x: w / 2, y: midY)

                // ── Gradient fill ────────────────────────────────────────
                if fillW > 0 {
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.highlight],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: fillW, height: trackH)
                    .clipShape(RoundedRectangle(cornerRadius: trackH / 2))
                    .position(x: half + fillW / 2, y: midY)
                }

                // ── Soft glow behind fill (dragging only) ────────────────
                if isDragging && fillW > 2 {
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.22), AppColors.highlight.opacity(0.22)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: fillW, height: trackH + 4)
                    .blur(radius: 5)
                    .clipShape(RoundedRectangle(cornerRadius: (trackH + 4) / 2))
                    .position(x: half + fillW / 2, y: midY)
                }

                // ── Thumb ────────────────────────────────────────────────
                thumbView
                    .scaleEffect(isDragging ? 1.13 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.62), value: isDragging)
                    .position(x: thumbX, y: midY)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(totalW: w, halfThumb: half, usableW: usable))
        }
        .frame(height: thumbD + 10)
    }

    // MARK: - Thumb

    private var thumbView: some View {
        ZStack {
            // Ambient glow disc
            Circle()
                .fill(AppColors.primary.opacity(isDragging ? 0.16 : 0))
                .frame(width: thumbD + 18, height: thumbD + 18)
                .blur(radius: 8)

            // Neumorphic raised body
            Circle()
                .fill(AppColors.background)
                .frame(width: thumbD, height: thumbD)
                .shadow(
                    color: AppColors.neumorphicLight.opacity(isDragging ? 0.5 : 0.8),
                    radius: isDragging ? 2 : 4,
                    x: isDragging ? -1 : -3,
                    y: isDragging ? -1 : -3
                )
                .shadow(
                    color: AppColors.neumorphicDark.opacity(isDragging ? 0.3 : 0.5),
                    radius: isDragging ? 2 : 4,
                    x: isDragging ? 1 : 3,
                    y: isDragging ? 1 : 3
                )
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                )
                .shadow(
                    color: AppColors.primary.opacity(isDragging ? 0.30 : 0.16),
                    radius: isDragging ? 10 : 4,
                    y: isDragging ? 3 : 1
                )
        }
    }

    // MARK: - End rails

    private var rails: some View {
        HStack {
            Text("Beginner")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text("Elite")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Drag gesture

    private func dragGesture(totalW: CGFloat, halfThumb: CGFloat, usableW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                let x      = max(halfThumb, min(totalW - halfThumb, g.location.x))
                let newVal = Double((x - halfThumb) / usableW) * 100
                let clamped = max(0, min(100, newVal))

                // Haptic at every 20 % band crossing
                let band = Int(clamped / 20)
                if band != lastBand {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    lastBand = band
                }

                value = clamped
                isDragging = true
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.60)) {
                    isDragging = false
                }
                onCommit?(value)
            }
    }

    // MARK: - Level helpers

    private func levelName(_ v: Double) -> String {
        switch v {
        case 0..<21:  return "Beginner"
        case 21..<41: return "Developing"
        case 41..<61: return "Consistent"
        case 61..<81: return "Advanced"
        default:      return "Elite"
        }
    }

    private func levelColor(_ v: Double) -> Color {
        switch v {
        case 0..<21:  return AppColors.textSecondary
        case 21..<41: return AppColors.warningOrange
        case 41..<61: return AppColors.primaryLight
        case 61..<81: return AppColors.primary
        default:      return AppColors.highlight
        }
    }
}

#Preview {
    struct P: View {
        @State var v: Double = 38
        var body: some View {
            VStack(spacing: 32) {
                PremiumRatingSlider(value: $v)
                PremiumRatingSlider(value: $v, showLevelLabel: false)
            }
            .padding(24)
            .background(AppColors.background)
        }
    }
    return P()
}
