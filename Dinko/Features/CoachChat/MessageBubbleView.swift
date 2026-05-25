import SwiftUI

struct MessageBubbleView: View {
    let message: CoachChatMessage
    let isFromCurrentUser: Bool

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }

            Text(message.content)
                .font(.system(size: 16, design: .rounded))
                .lineSpacing(3)
                .foregroundStyle(isFromCurrentUser ? .white : AppColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isFromCurrentUser ? AppColors.primary : AppColors.agentBubble)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
    }
}

struct DateSeparatorView: View {
    let date: Date

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        Text(Self.formatter.string(from: date))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(AppColors.textSecondary)
            .padding(.vertical, AppSpacing.xs)
    }
}

struct TimestampView: View {
    let date: Date

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Text(Self.formatter.string(from: date))
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(AppColors.textSecondary.opacity(0.7))
    }
}
