import SwiftUI
import Charts

struct HomeView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.authViewModel) private var authViewModel
    @Binding var selectedTab: Int
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
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                greetingHeader(viewModel)
                progressChart(viewModel)
                recommendedDrillsSection(viewModel)
                completedSkillsSection(viewModel)
                streakBanner(viewModel)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xxs)
            .padding(.bottom, AppSpacing.lg)
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }

    // MARK: - Greeting Header

    private func greetingHeader(_ viewModel: HomeViewModel) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
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

            Spacer()

            Button(role: .destructive) {
                Task { await authViewModel?.signOut() }
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.cardBackground)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Sign Out")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.xs)
    }

    // MARK: - Progress Chart

    private func progressChart(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
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

            let points = displayedChartPoints(viewModel)

            if viewModel.chartData.isEmpty || points.isEmpty {
                chartEmptyState
            } else if points.count == 1 {
                VStack(spacing: AppSpacing.sm) {
                    singlePointDisplay(points[0])
                    if viewModel.chartData.count > 1 {
                        skillFilterPills(viewModel)
                    }
                }
            } else {
                VStack(spacing: AppSpacing.sm) {
                    chartTrendHeader(points, viewModel: viewModel)
                    progressAreaChart(points, viewModel: viewModel)
                    if viewModel.chartData.count > 1 {
                        skillFilterPills(viewModel)
                    }
                }
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

    private func displayedChartPoints(_ viewModel: HomeViewModel) -> [HomeChartDataPoint] {
        if let selectedId = viewModel.selectedChartSkillId,
           let series = viewModel.chartData.first(where: { $0.id == selectedId }) {
            return series.dataPoints
        }
        return viewModel.overallAveragePoints
    }

    private func chartTrendHeader(_ points: [HomeChartDataPoint], viewModel: HomeViewModel) -> some View {
        let latest = points.last?.rating ?? 0
        let first = points.first?.rating ?? 0
        let change = latest - first
        let selectedName: String = {
            if let id = viewModel.selectedChartSkillId {
                return viewModel.chartData.first(where: { $0.id == id })?.skillName ?? "Skill"
            }
            return "Overall Average"
        }()

        return HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
            Text("\(latest)%")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            if change != 0 {
                HStack(spacing: 2) {
                    Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text(change > 0 ? "+\(change)%" : "\(change)%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(change > 0 ? AppColors.successGreen : AppColors.coral)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background((change > 0 ? AppColors.successGreen : AppColors.coral).opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()

            Text(selectedName)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func singlePointDisplay(_ point: HomeChartDataPoint) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text("\(point.rating)%")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.teal)

            Text("Recorded on \(point.date.formatted(.dateTime.month(.wide).day()))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            Text("Rate again to start tracking your trend")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(AppColors.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
    }

    private func progressAreaChart(_ points: [HomeChartDataPoint], viewModel: HomeViewModel) -> some View {
        let calendar = Calendar.current
        let allDates = points.map { $0.date }
        let cutoff = calendar.date(
            byAdding: .day,
            value: -viewModel.selectedTimeRange.daysBack,
            to: calendar.startOfDay(for: Date())
        ) ?? Date()
        let rangeStart = min(allDates.min() ?? cutoff, cutoff)
        let rangeEnd = max(allDates.max() ?? Date(), calendar.startOfDay(for: Date()))

        let snappedPoint: HomeChartDataPoint? = rawSelectedDate.flatMap { raw in
            points.min(by: {
                abs($0.date.timeIntervalSince(raw)) < abs($1.date.timeIntervalSince(raw))
            })
        }

        return Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Rating", point.rating)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.teal.opacity(0.25), AppColors.teal.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Rating", point.rating)
                )
                .foregroundStyle(AppColors.teal)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)
            }

            if let latest = points.last {
                PointMark(
                    x: .value("Date", latest.date),
                    y: .value("Rating", latest.rating)
                )
                .foregroundStyle(AppColors.teal)
                .symbolSize(60)
            }

            if let snapped = snappedPoint {
                RuleMark(x: .value("Selected", snapped.date))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .annotation(
                        position: .top,
                        spacing: 4,
                        overflowResolution: .init(
                            x: .fit(to: .chart),
                            y: .disabled
                        )
                    ) {
                        VStack(spacing: 2) {
                            Text("\(snapped.rating)%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.teal)
                            Text(snapped.date, format: .dateTime.month(.abbreviated).day())
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.cardBackground)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: rangeStart...rangeEnd)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(AppColors.separator.opacity(0.5))
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)%")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(
                values: .stride(by: .day, count: viewModel.selectedTimeRange == .weekly ? 2 : 7)
            ) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(AppColors.separator.opacity(0.3))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartLegend(.hidden)
        .chartXSelection(value: $rawSelectedDate)
        .frame(height: 180)
    }

    private func skillFilterPills(_ viewModel: HomeViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xxs) {
                chartFilterPill(
                    name: "All",
                    isSelected: viewModel.selectedChartSkillId == nil
                ) {
                    viewModel.selectChartSkill(nil)
                }

                ForEach(viewModel.chartData) { series in
                    chartFilterPill(
                        name: series.skillName,
                        isSelected: viewModel.selectedChartSkillId == series.id
                    ) {
                        viewModel.selectChartSkill(series.id)
                    }
                }
            }
        }
    }

    private func chartFilterPill(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, 6)
                .background(isSelected ? AppColors.teal : Color(.systemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recommended Drills

    private func recommendedDrillsSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(title: "Recommended Drills", actionTitle: "See All") {
                selectedTab = 3
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
                    NavigationLink {
                        DrillDetailView(drill: drill) {
                            await viewModel.markDrillDone(drill.id)
                        }
                    } label: {
                        DrillCardView(drill: drill)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Completed Skills

    private func completedSkillsSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(title: "Completed Skills")

            if viewModel.completedSkills.isEmpty {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.successGreen.opacity(0.4))

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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.completedSkills) { item in
                            CompletedSkillCardView(skill: item)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteCompletedSkill(item.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streak: \(viewModel.streakDays) days in a row. \(viewModel.daysToWeeklyGoal) more to hit your weekly goal.")
    }
}

#Preview {
    NavigationStack {
        HomeView(selectedTab: .constant(0))
    }
}
