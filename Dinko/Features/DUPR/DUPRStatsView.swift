import SwiftUI
import Charts

struct DUPRStatsView: View {
    @State private var duprService = DUPRService.shared
    @State private var selectedSegment = 0  // 0 = Singles, 1 = Doubles
    @Environment(\.dismiss) private var dismiss

    private var profile: DUPRProfile? { duprService.profile }
    private var history: [DUPRRatingSnapshot] { duprService.ratingHistory }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    if let profile {
                        ratingHeader(profile)
                        if history.count >= 2 {
                            chartSection
                        } else {
                            noHistoryBanner
                        }
                        statsGrid(profile)
                        refreshFooter(profile)
                    } else {
                        notConnectedState
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.background)
            .navigationTitle("DUPR Rating")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.primary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if duprService.isRefreshing {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button {
                            Task { await duprService.refreshRating() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                }
            }
            .toolbarBackground(AppColors.background, for: .navigationBar)
        }
        .task {
            await duprService.refreshRating()
        }
    }

    // MARK: - Rating Header

    private func ratingHeader(_ profile: DUPRProfile) -> some View {
        VStack(spacing: AppSpacing.sm) {
            // Segment control
            HStack(spacing: 0) {
                segmentButton("Singles", index: 0)
                segmentButton("Doubles", index: 1)
            }
            .padding(3)
            .background(AppColors.separator.opacity(0.4))
            .clipShape(Capsule())

            // Big rating
            let rating = selectedSegment == 0 ? profile.singlesRating : profile.doublesRating
            let provisional = selectedSegment == 0 ? profile.singlesProvisional : profile.doublesProvisional
            let delta = selectedSegment == 0 ? duprService.singlesRatingDelta : duprService.doublesRatingDelta

            VStack(spacing: 4) {
                HStack(alignment: .top, spacing: 4) {
                    if let r = rating {
                        Text(String(format: "%.2f", r))
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .contentTransition(.numericText())
                    } else {
                        Text("—")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    if let delta, abs(delta) > 0.001 {
                        deltaTag(delta)
                            .padding(.top, 12)
                    }
                }

                if provisional {
                    Label("Provisional", systemImage: "clock")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.warningOrange)
                }

                Text("DUPR ID: \(profile.duprId)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }

    private func segmentButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedSegment = index
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: selectedSegment == index ? .semibold : .medium, design: .rounded))
                .foregroundStyle(selectedSegment == index ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 7)
                .background {
                    if selectedSegment == index {
                        Capsule().fill(AppColors.cardBackground)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func deltaTag(_ delta: Double) -> some View {
        let isPositive = delta > 0
        return HStack(spacing: 3) {
            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                .font(.system(size: 10, weight: .bold))
            Text(String(format: "%.2f", abs(delta)))
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(isPositive ? AppColors.successGreen : AppColors.coral)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isPositive ? AppColors.successGreen : AppColors.coral).opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("RATING HISTORY")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(AppColors.textSecondary)

            let data = chartData
            let minVal = (data.map(\.rating).compactMap { $0 }.min() ?? 0) - 0.3
            let maxVal = (data.map(\.rating).compactMap { $0 }.max() ?? 5) + 0.3

            Chart {
                ForEach(data) { point in
                    if let r = point.rating {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Rating", r)
                        )
                        .foregroundStyle(AppColors.coral.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Min", minVal),
                            yEnd: .value("Rating", r)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.coral.opacity(0.25), AppColors.coral.opacity(0.0)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Rating", r)
                        )
                        .foregroundStyle(AppColors.coral)
                        .symbolSize(data.count <= 5 ? 40 : 20)
                    }
                }
            }
            .chartYScale(domain: minVal...maxVal)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                    AxisGridLine().foregroundStyle(AppColors.separator.opacity(0.4))
                }
            }
            .frame(height: 160)
            .padding(.top, AppSpacing.xxs)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let rating: Double?
    }

    private var chartData: [ChartPoint] {
        history.map { snapshot in
            ChartPoint(
                date: snapshot.date,
                rating: selectedSegment == 0 ? snapshot.singlesRating : snapshot.doublesRating
            )
        }
    }

    private var noHistoryBanner: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18))
                .foregroundStyle(AppColors.primary.opacity(0.6))
            VStack(alignment: .leading, spacing: 2) {
                Text("Rating tracking active")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Your chart will appear as your DUPR rating changes.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(AppColors.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.primary.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Stats Grid

    private func statsGrid(_ profile: DUPRProfile) -> some View {
        let isSingles = selectedSegment == 0
        let current = isSingles ? profile.singlesRating : profile.doublesRating
        let delta = isSingles ? duprService.singlesRatingDelta : duprService.doublesRatingDelta
        let historyForSegment = history.compactMap { isSingles ? $0.singlesRating : $0.doublesRating }
        let highest = historyForSegment.max()
        let lowest = historyForSegment.min()

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                statCell(
                    title: "Current",
                    value: current.map { String(format: "%.2f", $0) } ?? "—",
                    color: AppColors.primary
                )
                statDivider
                statCell(
                    title: "Net Change",
                    value: deltaString(delta),
                    color: deltaColor(delta)
                )
            }
            Divider().padding(.horizontal, AppSpacing.sm)
            HStack(spacing: 0) {
                statCell(
                    title: "Peak",
                    value: highest.map { String(format: "%.2f", $0) } ?? "—",
                    color: AppColors.successGreen
                )
                statDivider
                statCell(
                    title: "Low",
                    value: lowest.map { String(format: "%.2f", $0) } ?? "—",
                    color: AppColors.textSecondary
                )
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private func statCell(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(AppColors.separator.opacity(0.5))
            .frame(width: 0.5)
            .padding(.vertical, 8)
    }

    private func deltaString(_ delta: Double?) -> String {
        guard let delta else { return "—" }
        if abs(delta) < 0.001 { return "—" }
        return (delta > 0 ? "+" : "") + String(format: "%.2f", delta)
    }

    private func deltaColor(_ delta: Double?) -> Color {
        guard let delta, abs(delta) > 0.001 else { return AppColors.textSecondary }
        return delta > 0 ? AppColors.successGreen : AppColors.coral
    }

    // MARK: - Footer

    private func refreshFooter(_ profile: DUPRProfile) -> some View {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let updated = formatter.localizedString(for: profile.lastRefreshed, relativeTo: Date())

        return HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 11))
            Text("Updated \(updated)")
                .font(.system(size: 12, design: .rounded))
        }
        .foregroundStyle(AppColors.textSecondary)
    }

    // MARK: - Not Connected

    private var notConnectedState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: "link.slash")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textSecondary.opacity(0.4))
            Text("DUPR Not Connected")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
            Text("Connect your DUPR account from your profile to track your rating here.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
            Spacer()
        }
    }
}

#Preview {
    DUPRStatsView()
}
