import SwiftUI

// MARK: - Neumorphic Intensity

enum NeumorphicIntensity {
    case subtle, standard, prominent

    var lightOffset: CGFloat {
        switch self {
        case .subtle:    return 3
        case .standard:  return 5
        case .prominent: return 7
        }
    }

    var darkOffset: CGFloat {
        switch self {
        case .subtle:    return 3
        case .standard:  return 5
        case .prominent: return 7
        }
    }

    var lightRadius: CGFloat {
        switch self {
        case .subtle:    return 4
        case .standard:  return 8
        case .prominent: return 12
        }
    }

    var darkRadius: CGFloat {
        switch self {
        case .subtle:    return 4
        case .standard:  return 8
        case .prominent: return 12
        }
    }

    var lightOpacity: Double {
        switch self {
        case .subtle:    return 0.6
        case .standard:  return 0.8
        case .prominent: return 1.0
        }
    }

    var darkOpacity: Double {
        switch self {
        case .subtle:    return 0.3
        case .standard:  return 0.5
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
    var cornerRadius: CGFloat = AppSpacing.neumorphicCornerRadius

    func body(content: Content) -> some View {
        content
            .background(AppColors.background)
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

// MARK: - Neumorphic Inset Modifier

struct NeumorphicInsetModifier: ViewModifier {
    var depth: NeumorphicInsetDepth = .standard
    var cornerRadius: CGFloat = AppSpacing.neumorphicCornerRadius

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
    var cornerRadius: CGFloat = AppSpacing.neumorphicCornerRadius

    func body(content: Content) -> some View {
        content
            .background(AppColors.background)
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

// MARK: - Legacy Shadow Values (neumorphic-aligned for direct references)

let floatShadow1: (Color, CGFloat, CGFloat) = (AppColors.neumorphicDark.opacity(0.5), 8, 5)
let floatShadow2: (Color, CGFloat, CGFloat) = (AppColors.neumorphicLight.opacity(0.8), 8, -5)

// MARK: - View Extensions

extension View {
    func neumorphicRaised(
        intensity: NeumorphicIntensity = .standard,
        cornerRadius: CGFloat = AppSpacing.neumorphicCornerRadius
    ) -> some View {
        modifier(NeumorphicRaisedModifier(intensity: intensity, cornerRadius: cornerRadius))
    }

    func neumorphicInset(
        depth: NeumorphicInsetDepth = .standard,
        cornerRadius: CGFloat = AppSpacing.neumorphicCornerRadius
    ) -> some View {
        modifier(NeumorphicInsetModifier(depth: depth, cornerRadius: cornerRadius))
    }

    func neumorphicFlat(
        cornerRadius: CGFloat = AppSpacing.neumorphicCornerRadius
    ) -> some View {
        modifier(NeumorphicFlatModifier(cornerRadius: cornerRadius))
    }

    // MARK: - Backward-Compatible Wrappers

    func heroCard() -> some View {
        self
            .padding(AppSpacing.md)
            .neumorphicRaised(intensity: .prominent, cornerRadius: AppSpacing.heroCornerRadius)
    }

    func coachCard() -> some View {
        self
            .padding(AppSpacing.sm)
            .neumorphicRaised(intensity: .standard, cornerRadius: AppSpacing.cardCornerRadiusSmall)
    }

    func infoCard() -> some View {
        self
            .padding(AppSpacing.xs)
            .neumorphicRaised(intensity: .subtle, cornerRadius: AppSpacing.cardCornerRadiusSmall)
    }

    func achievementCard() -> some View {
        self
            .padding(AppSpacing.sm)
            .neumorphicRaised(intensity: .standard, cornerRadius: AppSpacing.cardCornerRadiusSmall)
    }

    func floatingCard(cornerRadius: CGFloat = AppSpacing.cardCornerRadiusSmall) -> some View {
        self
            .neumorphicRaised(intensity: .standard, cornerRadius: cornerRadius)
    }
}
