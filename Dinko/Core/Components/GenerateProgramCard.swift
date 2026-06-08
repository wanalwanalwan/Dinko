import SwiftUI

struct GenerateProgramCard: View {
    var onGenerate: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.primary)
                .padding(.top, AppSpacing.xxs)

            Text("Your Training Program")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text("Get a personalized multi-week program tailored to your skills and goals. The AI coach will build a structured plan to level up your game.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.sm)

            Button(action: onGenerate) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Generate My Program")
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
            }
            .buttonStyle(.pressable)
            .padding(.top, AppSpacing.xxs)
        }
        .heroCard()
    }
}
