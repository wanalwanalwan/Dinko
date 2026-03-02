import SwiftUI
import Charts

struct HomeView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: HomeViewModel?

    var body: some View {
        Group {
            if let viewModel {
                homeContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = HomeViewModel(
                    skillRepository: dependencies.skillRepository,
                    skillRatingRepository: dependencies.skillRatingRepository,
                    drillRepository: dependencies.drillRepository
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
                VStack(spacing: AppSpacing.sm) {
                    greetingHeader(viewModel)
                    quickStatsRow(viewModel)
                    progressChart(viewModel)
                    topMoversSection(viewModel)
                    recommendedDrillsSection(viewModel)
                    completedSkillsSection(viewModel)
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
            Text("\(viewModel.greetingText), \(viewModel.playerName)")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.textPrimary)

            Text(viewModel.todayDateText)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.xxs)
    }

    // MARK: - Quick Stats Row

    private func quickStatsRow(_ viewModel: HomeViewModel) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            statCard(
                icon: "figure.pickleball",
                value: "\(viewModel.totalActiveSkills)",
                label: "Skills",
                color: AppColors.teal
            )

            statCard(
                icon: "chart.bar.fill",
                value: "\(viewModel.averageRating)%",
                label: "Avg Rating",
                color: AppColors.coral
            )

            if let skillName = viewModel.mostImprovedSkillName {
                statCard(
                    icon: "arrow.up.right",
                    value: "+\(viewModel.mostImprovedDelta)%",
                    label: skillName,
                    color: AppColors.successGreen
                )
            } else {
                statCard(
                    icon: "arrow.up.right",
                    value: "--",
                    label: "Top Gain",
                    color: AppColors.successGreen
                )
            }
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xxxs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Progress Chart

    private func progressChart(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("PROGRESS")
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
                        .symbolSize(20)
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
            .frame(height: 200)
        }
    }

    // MARK: - Top Movers

    @ViewBuilder
    private func topMoversSection(_ viewModel: HomeViewModel) -> some View {
        if !viewModel.topMovers.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("TOP MOVERS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.bottom, AppSpacing.xs)

                ForEach(Array(viewModel.topMovers.enumerated()), id: \.element.id) { index, mover in
                    if index > 0 {
                        Divider()
                    }

                    HStack(spacing: AppSpacing.xs) {
                        Text(mover.iconName)
                            .font(.system(size: 20))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mover.skillName)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.textPrimary)

                            Text(mover.tier.displayName)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(mover.tier.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(mover.tier.color.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(mover.currentRating)%")
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            HStack(spacing: 2) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                                Text("+\(mover.delta)%")
                                    .font(AppTypography.trendValue)
                            }
                            .foregroundStyle(AppColors.successGreen)
                        }
                    }
                    .padding(.vertical, AppSpacing.xxs)
                }
            }
            .padding(AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
    }

    // MARK: - Recommended Drills

    private func recommendedDrillsSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECOMMENDED DRILLS")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.bottom, AppSpacing.xs)

            if viewModel.recommendedDrills.isEmpty {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))

                    Text("No drills yet \u{2014} Log a session with the Coach to get personalized drills.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.vertical, AppSpacing.xxs)
            } else {
                ForEach(Array(viewModel.recommendedDrills.enumerated()), id: \.element.id) { index, drill in
                    if index > 0 {
                        Divider()
                    }

                    HStack(spacing: AppSpacing.xxs) {
                        Button {
                            Task { await viewModel.markDrillDone(drill.id) }
                        } label: {
                            Image(systemName: "circle")
                                .foregroundStyle(AppColors.teal)
                                .font(.system(size: 18))
                                .frame(width: 24)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(drill.drillName)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.textPrimary)

                            HStack(spacing: AppSpacing.xxxs) {
                                Text("\(drill.durationMinutes) min")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)

                                Text("\u{2022}")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)

                                Text(drill.skillName)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.teal)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.vertical, AppSpacing.xxs)
                }
            }
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
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "trophy")
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))

                    Text("Rate a skill to 100% to complete it.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.vertical, AppSpacing.xxs)
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
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
