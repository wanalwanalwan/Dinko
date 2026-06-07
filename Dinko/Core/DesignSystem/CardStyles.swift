import SwiftUI

// MARK: - Neumorphic Intensity

enum NeumorphicIntensity {
    case subtle, standard, prominent

    var lightOffset: CGFloat {
        switch self {
        case .subtle:    return 3
        case .standard:  return 4
        case .prominent: return 7
        }
    }

    var darkOffset: CGFloat {
        switch self {
        case .subtle:    return 3
        case .standard:  return 4
        case .prominent: return 7
        }
    }

    var lightRadius: CGFloat {
        switch self {
        case .subtle:    return 4
        case .standard:  return 6
        case .prominent: return 12
        }
    }

    var darkRadius: CGFloat {
        switch self {
        case .subtle:    return 4
        case .standard:  return 6
        case .prominent: return 12
        }
    }

    var lightOpacity: Double {
        switch self {
        case .subtle:    return 0.6
        case .standard:  return 0.9
        case .prominent: return 1.0
        }
    }

    var darkOpacity: Double {
        switch self {
        case .subtle:    return 0.3
        case .standard:  return 0.4
        case .prominent: return 0.7
        }
    }
}

// MARK: - Neumorphic Inset Depth

enum NeumorphicInsetDepth {
    case shallow, standard, deep

    var offset: CGFloat {
        switch self {
        case .shallow:  return 2
        case .standard: return 4
        case .deep:     return 6
        }
    }

    var radius: CGFloat {
        switch self {
        case .shallow:  return 3
        case .standard: return 5
        case .deep:     return 8
        }
    }

    var opacity: Double {
        switch self {
        case .shallow:  return 0.4
        case .standard: return 0.6
        case .deep:     return 0.8
        }
    }
}

// MARK: - Neumorphic Raised Modifier

struct NeumorphicRaisedModifier: ViewModifier {
    var intensity: NeumorphicIntensity = .standard
    var cornerRadius: CGFloat = AppSpacing.cornerRadiusLg
    var surfaceColor: Color = AppColors.cardBackground

    func body(content: Content) -> some View {
        content
            .background(surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: AppColors.neumorphicLight.opacity(intensity.lightOpacity),
                radius: intensity.lightRadius,
                x: -intensity.lightOffset,
                y: -intensity.lightOffset
            )
            .shadow(
                color: AppColors.neumorphicDark.opacity(intensity.darkOpacity),
                radius: intensity.darkRadius,
                x: intensity.darkOffset,
                y: intensity.darkOffset
            )
    }
}

// MARK: - Neumorphic Tinted Modifier

struct NeumorphicTintedModifier: ViewModifier {
    var tintColor: Color
    var tintOpacity: Double = 0.06
    var borderOpacity: Double = 0.18
    var intensity: NeumorphicIntensity = .standard
    var cornerRadius: CGFloat = AppSpacing.cornerRadiusLg

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    AppColors.cardBackground
                    tintColor.opacity(tintOpacity)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(tintColor.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(
                color: AppColors.neumorphicLight.opacity(intensity.lightOpacity),
                radius: intensity.lightRadius,
                x: -intensity.lightOffset,
                y: -intensity.lightOffset
            )
            .shadow(
                color: AppColors.neumorphicDark.opacity(intensity.darkOpacity),
                radius: intensity.darkRadius,
                x: intensity.darkOffset,
                y: intensity.darkOffset
            )
    }
}

// MARK: - Neumorphic Inset Modifier

struct NeumorphicInsetModifier: ViewModifier {
    var depth: NeumorphicInsetDepth = .standard
    var cornerRadius: CGFloat = AppSpacing.cornerRadiusMd

    func body(content: Content) -> some View {
        content
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.background, lineWidth: 0.5)
                    .shadow(
                        color: AppColors.neumorphicInnerDark.opacity(depth.opacity),
                        radius: depth.radius,
                        x: depth.offset,
                        y: depth.offset
                    )
                    .shadow(
                        color: AppColors.neumorphicInnerLight.opacity(depth.opacity),
                        radius: depth.radius,
                        x: -depth.offset,
                        y: -depth.offset
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
    }
}

// MARK: - Neumorphic Flat Modifier

struct NeumorphicFlatModifier: ViewModifier {
    var cornerRadius: CGFloat = AppSpacing.cornerRadiusMd

    func body(content: Content) -> some View {
        content
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: AppColors.neumorphicLight.opacity(0.4),
                radius: 3,
                x: -2,
                y: -2
            )
            .shadow(
                color: AppColors.neumorphicDark.opacity(0.2),
                radius: 3,
                x: 2,
                y: 2
            )
    }
}

// MARK: - Neumorphic Button Style

struct NeumorphicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .shadow(
                color: AppColors.neumorphicLight.opacity(configuration.isPressed ? 0.3 : 0.9),
                radius: configuration.isPressed ? 2 : 6,
                x: configuration.isPressed ? -1 : -4,
                y: configuration.isPressed ? -1 : -4
            )
            .shadow(
                color: AppColors.neumorphicDark.opacity(configuration.isPressed ? 0.15 : 0.4),
                radius: configuration.isPressed ? 2 : 6,
                x: configuration.isPressed ? 1 : 4,
                y: configuration.isPressed ? 1 : 4
            )
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func neumorphicRaised(
        intensity: NeumorphicIntensity = .standard,
        cornerRadius: CGFloat = AppSpacing.cornerRadiusLg,
        surfaceColor: Color = AppColors.cardBackground
    ) -> some View {
        modifier(NeumorphicRaisedModifier(intensity: intensity, cornerRadius: cornerRadius, surfaceColor: surfaceColor))
    }

    func neumorphicTinted(
        color tintColor: Color,
        tintOpacity: Double = 0.06,
        borderOpacity: Double = 0.18,
        intensity: NeumorphicIntensity = .standard,
        cornerRadius: CGFloat = AppSpacing.cornerRadiusLg
    ) -> some View {
        modifier(NeumorphicTintedModifier(
            tintColor: tintColor,
            tintOpacity: tintOpacity,
            borderOpacity: borderOpacity,
            intensity: intensity,
            cornerRadius: cornerRadius
        ))
    }

    func neumorphicInset(
        depth: NeumorphicInsetDepth = .standard,
        cornerRadius: CGFloat = AppSpacing.cornerRadiusMd
    ) -> some View {
        modifier(NeumorphicInsetModifier(depth: depth, cornerRadius: cornerRadius))
    }

    func neumorphicFlat(
        cornerRadius: CGFloat = AppSpacing.cornerRadiusMd
    ) -> some View {
        modifier(NeumorphicFlatModifier(cornerRadius: cornerRadius))
    }

    // MARK: - Backward-Compatible Wrappers

    func heroCard() -> some View {
        self
            .padding(AppSpacing.md)
            .neumorphicRaised(intensity: .prominent, cornerRadius: AppSpacing.cornerRadiusLg)
    }

    func coachCard() -> some View {
        self
            .padding(AppSpacing.sm)
            .neumorphicTinted(color: AppColors.successGreen)
    }

    func infoCard() -> some View {
        self
            .padding(AppSpacing.xs)
            .neumorphicRaised(intensity: .subtle, cornerRadius: AppSpacing.cornerRadiusMd)
    }

    func achievementCard() -> some View {
        self
            .padding(AppSpacing.sm)
            .neumorphicRaised(intensity: .standard, cornerRadius: AppSpacing.cornerRadiusMd)
    }

    func floatingCard(cornerRadius: CGFloat = AppSpacing.cornerRadiusMd) -> some View {
        self
            .neumorphicRaised(intensity: .standard, cornerRadius: cornerRadius)
    }
}
