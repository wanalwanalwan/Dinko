import SwiftUI
import Charts

struct HomeView: View {
    @Environment(\.dependencies) private var dependencies
    @Binding var selectedTab: Int
    @State private var viewModel: HomeViewModel?
    @State private var rawSelectedDate: Date?
    @State private var expandedCompletedSkillId: UUID?

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
                    streakBanner(viewModel)
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

        // Compute the full date range for the x-axis
        let allDates = viewModel.chartData.flatMap { $0.dataPoints.map { $0.date } }
        let calendar = Calendar.current
        let cutoff = calendar.date(
            byAdding: .day,
            value: -viewModel.selectedTimeRange.daysBack,
            to: calendar.startOfDay(for: Date())
        ) ?? Date()
        let rangeStart = min(allDates.min() ?? cutoff, cutoff)
        let rangeEnd = max(allDates.max() ?? Date(), calendar.startOfDay(for: Date()))

        // Check if all series have only a single data point
        let isSinglePoint = allDates.count <= 1 || Set(allDates.map { calendar.startOfDay(for: $0) }).count <= 1

        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Chart {
                ForEach(viewModel.chartData) { series in
                    if series.dataPoints.count == 1 {
                        // Single data point: show as a large dot only
                        ForEach(series.dataPoints) { point in
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Rating", point.rating)
                            )
                            .foregroundStyle(by: .value("Skill", series.skillName))
                            .symbolSize(60)
                        }
                    } else {
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
            .chartXScale(domain: rangeStart...rangeEnd)
            .chartXAxis {
                if isSinglePoint {
                    // Single point: just show that one date label centered
                    AxisMarks(values: allDates) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                } else {
                    AxisMarks(values: .stride(by: .day, count: viewModel.selectedTimeRange == .weekly ? 2 : 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
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

                Button {
                    selectedTab = 3
                } label: {
                    Text("SEE ALL")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.teal)
                }
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
        NavigationLink {
            DrillDetailView(drill: drill) {
                await viewModel.markDrillDone(drill.id)
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "play.circle")
                    .font(.system(size: 34))
                    .foregroundStyle(AppColors.textPrimary)

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
        .buttonStyle(.plain)
    }

    // MARK: - Completed Skills

    private func completedSkillsSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("COMPLETED SKILLS")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            if viewModel.completedSkills.isEmpty {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.teal.opacity(0.4))

                    Text("Your Journey Starts Here")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Rate a skill to 100% to see it here.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Button {
                        selectedTab = 2
                    } label: {
                        Text("View all skills")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.teal)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            } else {
                ForEach(viewModel.completedSkills) { item in
                    completedSkillCard(item)
                }
            }
        }
    }

    private func completedSkillCard(_ item: CompletedSkillItem) -> some View {
        let isExpanded = expandedCompletedSkillId == item.id

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                expandedCompletedSkillId = isExpanded ? nil : item.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Header: completion time + name (Copilot style)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Completed in \(item.daysToComplete) day\(item.daysToComplete == 1 ? "" : "s")")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }

                // Expanded subskills
                if isExpanded && !item.subskills.isEmpty {
                    VStack(spacing: 0) {
                        Divider()
                            .padding(.vertical, AppSpacing.xs)

                        ForEach(Array(item.subskills.enumerated()), id: \.element.id) { index, sub in
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppColors.successGreen)

                                Text(sub.name)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)

                                Spacer()

                                Text("\(sub.rating)%")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppColors.teal)
                            }
                            .padding(.vertical, 6)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity
                                        .combined(with: .offset(y: -8))
                                        .animation(.spring(response: 0.35, dampingFraction: 0.8).delay(Double(index) * 0.05)),
                                    removal: .opacity.animation(.easeOut(duration: 0.15))
                                )
                            )
                        }
                    }
                }
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
        .buttonStyle(.plain)
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
        HomeView(selectedTab: .constant(0))
    }
}
