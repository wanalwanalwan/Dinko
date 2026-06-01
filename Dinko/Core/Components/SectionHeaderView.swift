import SwiftUI

struct SectionHeaderView: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.primaryLight)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        SectionHeaderView(title: "Recommended Drills", actionTitle: "See All") {}
        SectionHeaderView(title: "Completed Skills")
    }
    .padding()
}
