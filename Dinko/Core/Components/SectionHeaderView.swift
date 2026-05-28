import SwiftUI

struct SectionHeaderView: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
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
