import SwiftUI
import Charts

struct HomeView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: HomeViewModel?
    @State private var rawSelectedDate: Date?

    var body: some View {
        Group {
            if let viewModel {
                homeContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel == nil {
                let vm = HomeViewModel(
                    skillRepository: dependencies.skillRepository,
                    skillRatingRepository: dependencies.skillRatingRepository,
                    drillRepository: dependencies.drillRepository,
                    sessionRepository: dependencies.sessionRepository
                )
                viewModel = vm
                await vm.loadDashboard()
            }
        }
        .onAppear {
            if let viewModel {
                Task { await viewModel.loadDashboard() }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.errorMessage != nil },
            set: { if !$0 { viewModel?.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func homeContent(_ viewModel: HomeViewModel) -> some View {
        if viewModel.totalActiveSkills == 0 && viewModel.isLoaded {
            ContentUnavailableView(
                "Welcome to Dinko",
                systemImage: "figure.pickleball",
                description: Text("Add your first skill in the Progress tab to start tracking your game.")
            )
        } else {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    greetingHeader(viewModel)
                    progressChart(viewModel)
                    recommendedDrillsSection(viewModel)
                    completedSkillsSection(viewModel)
                    if viewModel.streakDays > 0 {
                        streakBanner(viewModel)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xxs)
                .padding(.bottom, AppSpacing.lg)
            }
            .refreshable {
                await viewModel.loadDashboard()
            }
        }
    }

    // MARK: - Greeting Header

    private func greetingHeader(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
            Text(viewModel.todayDateText.uppercased())
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(viewModel.greetingText),")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text(viewModel.playerName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.teal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.xs)
    }

    // MARK: - Progress Chart

    private func progressChart(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("SKILL PROGRESS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                Picker("Time Range", selection: Binding(
                    get: { viewModel.selectedTimeRange },
                    set: { viewModel.updateTimeRange($0) }
                )) {
                    ForEach(HomeTimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            if viewModel.chartData.isEmpty {
                chartEmptyState
            } else {
                chartView(viewModel)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private var chartEmptyState: some View {
        VStack(spacing: AppSpacing.xxs) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.textSecondary.opacity(0.5))

            Text("Rate your skills to see progress")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }

    private func chartView(_ viewModel: HomeViewModel) -> some View {
        let skillNames = viewModel.chartData.map { $0.skillName }
        let skillColors = viewModel.chartData.map { $0.color }

        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Chart {
                ForEach(viewModel.chartData) { series in
                    ForEach(series.dataPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Rating", point.rating),
                            series: .value("Skill", series.skillName)
                        )
                        .foregroundStyle(by: .value("Skill", series.skillName))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Rating", point.rating)
                        )
                        .foregroundStyle(by: .value("Skill", series.skillName))
                        .symbolSize(30)
                    }
                }

                if let snappedDate = snappedSelectedDate(viewModel) {
                    RuleMark(x: .value("Selected", snappedDate))
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(
                            position: .top,
                            spacing: 4,
                            overflowResolution: .init(
                                x: .fit(to: .chart),
                                y: .disabled
                            )
                        ) {
                            chartTooltip(for: snappedDate, viewModel: viewModel)
                        }
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text("\(intVal)%")
                                .font(.system(size: 10, design: .rounded))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartForegroundStyleScale(
                domain: skillNames,
                range: skillColors
            )
            .chartLegend(position: .bottom, alignment: .leading, spacing: AppSpacing.xxxs)
            .chartXSelection(value: $rawSelectedDate)
            .frame(height: 200)
        }
    }

    private func snappedSelectedDate(_ viewModel: HomeViewModel) -> Date? {
        guard let raw = rawSelectedDate else { return nil }
        let allDates = viewModel.chartData.flatMap { $0.dataPoints.map { $0.date } }
        return allDates.min(by: {
            abs($0.timeIntervalSince(raw)) < abs($1.timeIntervalSince(raw))
        })
    }

    private func chartTooltip(for date: Date, viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(date, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            ForEach(viewModel.chartData) { series in
                if let point = series.dataPoints.first(where: {
                    Calendar.current.isDate($0.date, inSameDayAs: date)
                }) {
                    Text("\(series.skillName.lowercased()) : \(point.rating)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(series.color)
                }
            }
        }
        .padding(AppSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Recommended Drills

    private func recommendedDrillsSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("RECOMMENDED DRILLS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                Text("SEE ALL")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.teal)
            }

            if viewModel.recommendedDrills.isEmpty {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))

                    Text("No drills yet \u{2014} Log a session with the Coach to get personalized drills.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            } else {
                ForEach(viewModel.recommendedDrills) { drill in
                    drillCard(drill, viewModel: viewModel)
                }
            }
        }
    }

    private func drillCard(_ drill: HomeRecommendedDrill, viewModel: HomeViewModel) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Button {
                Task { await viewModel.markDrillDone(drill.id) }
            } label: {
                Image(systemName: "play.circle")
                    .font(.system(size: 34))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(drill.drillName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: AppSpacing.xxxs) {
                    Text("\(drill.durationMinutes) min")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Text("\u{00B7}")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Text(drill.skillName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.teal)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Completed Skills

    private static let completedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private func completedSkillsSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("COMPLETED SKILLS")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.bottom, AppSpacing.xs)

            if viewModel.completedSkills.isEmpty {
                VStack(spacing: AppSpacing.xs) {
                    Circle()
                        .stroke(AppColors.teal.opacity(0.25), lineWidth: 3)
                        .frame(width: 50, height: 50)

                    Text("Your Journey Starts Here")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Rate a skill to 100% to see it here.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Text("View all skills")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.teal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
            } else {
                ForEach(Array(viewModel.completedSkills.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                    }

                    HStack(spacing: AppSpacing.xs) {
                        Text(item.iconName)
                            .font(.system(size: 20))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.textPrimary)

                            if let date = item.completedDate {
                                Text(Self.completedDateFormatter.string(from: date))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        Spacer()

                        Text("\(item.rating)%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.teal)
                            .padding(.horizontal, AppSpacing.xxs)
                            .padding(.vertical, AppSpacing.xxxs)
                            .background(AppColors.teal.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, AppSpacing.xxs)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Streak Banner

    private func streakBanner(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Keep the streak alive!")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            (Text("You\u{2019}ve practiced for ")
                .foregroundColor(.white.opacity(0.85))
            + Text("\(viewModel.streakDays) days")
                .foregroundColor(.white)
                .bold()
            + Text(" in a row. \(viewModel.daysToWeeklyGoal) more to hit your weekly goal.")
                .foregroundColor(.white.opacity(0.85)))
                .font(.system(size: 14, design: .rounded))

            Button {
                // Navigate to progress stats
            } label: {
                Text("View Stats")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(AppColors.teal)
                    .clipShape(Capsule())
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color(hex: "1C1C2E"))
        )
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
