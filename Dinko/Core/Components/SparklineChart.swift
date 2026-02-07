import SwiftUI
import Charts

struct SparklineChart: View {
    let data: [Int]

    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Rating", value)
                )
                .foregroundStyle(AppColors.coral)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(width: 50, height: AppSpacing.sparklineHeight)
    }
}

#Preview {
    HStack(spacing: 24) {
        SparklineChart(data: [60, 63, 65, 68, 70, 72, 75])
        SparklineChart(data: [80, 78, 75, 74, 73, 72, 70])
        SparklineChart(data: [50, 50, 51, 50, 50, 51, 50])
    }
    .padding()
}
