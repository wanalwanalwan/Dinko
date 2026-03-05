import SwiftUI

struct SectionHeaderView: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle.uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.teal)
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
