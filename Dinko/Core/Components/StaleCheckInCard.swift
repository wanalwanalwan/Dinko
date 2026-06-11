import SwiftUI

/// Compact card prompting the user to update confidence for skills
/// that haven't been checked in for 14+ days.
struct StaleCheckInCard: View {
    let skillName: String
    let lastConfidence: Int
    let onResponse: (CheckInResponse) -> Void

    enum CheckInResponse: String {
        case struggling = "Still struggling"
        case improving = "Improving"
        case comfortable = "Comfortable"
        case confident = "Confident"
        case skip = "Skip"

        var confidenceAdjustment: Int {
            switch self {
            case .struggling: return -1
            case .improving: return 0
            case .comfortable: return 1
            case .confident: return 2
            case .skip: return 0
            }
        }
    }

    var body: some View {
        VStack(spacing: AppSpacing.xxs) {
            HStack {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.warningOrange)

                Text("How's your **\(skillName)**?")
                    .font(AppTypography.cardBody)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button(action: { onResponse(.skip) }) {
                    Text("Skip")
                        .font(AppTypography.buttonLabelSmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            HStack(spacing: AppSpacing.xxs) {
                responseButton(.struggling)
                responseButton(.improving)
                responseButton(.comfortable)
                responseButton(.confident)
            }
        }
        .padding(AppSpacing.sm)
        .neumorphicRaised(intensity: .subtle, cornerRadius: AppSpacing.cornerRadiusMd)
    }

    private func responseButton(_ response: CheckInResponse) -> some View {
        Button(action: { onResponse(response) }) {
            Text(response.rawValue)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xxs)
                .background(AppColors.backgroundGray)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm))
        }
        .buttonStyle(.plain)
    }
}
