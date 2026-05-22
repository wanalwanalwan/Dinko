import SwiftUI

struct TimelineView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: TimelineViewModel?
    @State private var contentReady = false

    var body: some View {
        Group {
            if let viewModel {
                timelineContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel == nil {
                let vm = TimelineViewModel(
                    sessionRepository: dependencies.sessionRepository,
                    skillRepository: dependencies.skillRepository
                )
                viewModel = vm
                withAnimation { contentReady = true }
                await vm.loadSessions()
            }
        }
    }

    @ViewBuilder
    private func timelineContent(_ viewModel: TimelineViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.sm) {
                calendarSection(viewModel)
                    .staggeredAppearance(index: 0)

                sessionListSection(viewModel)
                    .staggeredAppearance(index: 1)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .contentLoadTransition(isLoaded: contentReady)
        }
        .refreshable {
            await viewModel.loadSessions()
        }
    }

    // MARK: - Calendar Section

    private func calendarSection(_ viewModel: TimelineViewModel) -> some View {
        VStack(spacing: AppSpacing.xs) {
            // Month header with navigation
            HStack {
                Button {
                    withAnimation(AppAnimations.springSmooth) {
                        viewModel.changeMonth(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.teal)
                        .frame(width: 32, height: 32)
                }

                Spacer()

                Text(viewModel.monthYearString())
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button {
                    withAnimation(AppAnimations.springSmooth) {
                        viewModel.changeMonth(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.teal)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, AppSpacing.xxs)

            // Weekday labels
            let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
            HStack(spacing: 0) {
                ForEach(weekdays.indices, id: \.self) { index in
                    Text(weekdays[index])
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, AppSpacing.xxs)

            // Calendar grid
            let days = viewModel.daysInMonthGrid()
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

            LazyVGrid(columns: columns, spacing: AppSpacing.xxs) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        calendarDayCell(date: date, viewModel: viewModel)
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xxs)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func calendarDayCell(date: Date, viewModel: TimelineViewModel) -> some View {
        let day = Calendar.current.component(.day, from: date)
        let selected = viewModel.isSelected(date)
        let today = viewModel.isToday(date)
        let hasSession = viewModel.hasSession(on: date)

        return Button {
            withAnimation(AppAnimations.springSnappy) {
                viewModel.selectDate(date)
            }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if selected {
                        Circle()
                            .fill(AppColors.teal)
                            .frame(width: 34, height: 34)
                    } else if today {
                        Circle()
                            .strokeBorder(AppColors.teal, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                    }

                    Text("\(day)")
                        .font(.system(size: 15, weight: selected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(selected ? .white : (today ? AppColors.teal : AppColors.textPrimary))
                }

                Circle()
                    .fill(hasSession ? (selected ? .white : AppColors.teal) : .clear)
                    .frame(width: 6, height: 6)
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session List Section

    private func sessionListSection(_ viewModel: TimelineViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(viewModel.selectedDateDisplayString().uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(0.5)
                .padding(.horizontal, AppSpacing.xxs)

            let sessionsForDay = viewModel.sessionsForSelectedDate

            if sessionsForDay.isEmpty {
                emptyDayState
            } else {
                ForEach(sessionsForDay) { session in
                    sessionCard(session: session, viewModel: viewModel)
                }
            }
        }
    }

    private var emptyDayState: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.textSecondary.opacity(0.5))

            Text("No sessions on this day")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, AppSpacing.lg)
        .padding(.horizontal, AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func sessionCard(session: Session, viewModel: TimelineViewModel) -> some View {
        let skillNames = viewModel.skillNames(for: session)
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f
        }()

        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Header: type icon + label + time + duration
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: session.sessionType.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.teal)

                Text(session.sessionType.displayName)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text(timeFormatter.string(from: session.date))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Duration pill
            if session.duration > 0 {
                Text("\(session.duration) min")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.xxs)
                    .padding(.vertical, 3)
                    .background(AppColors.background)
                    .clipShape(Capsule())
            }

            // Skill tags
            if !skillNames.isEmpty {
                FlowLayout(spacing: AppSpacing.xxxs) {
                    ForEach(skillNames, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.teal)
                            .padding(.horizontal, AppSpacing.xxs)
                            .padding(.vertical, 3)
                            .background(AppColors.primaryTint)
                            .clipShape(Capsule())
                    }
                }
            }

            // Notes
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive) {
                Task { await viewModel.deleteSession(session.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TimelineView()
    }
}
