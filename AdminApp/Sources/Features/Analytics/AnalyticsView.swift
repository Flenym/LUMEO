// Lumeo Admin — Sources/Features/Analytics/AnalyticsView.swift
// Аналитика (Swift Charts): DAU / WAU / sessions / accept-rate / messages /
// squads / retention / widget / notification.

import SwiftUI
import Charts

// MARK: - AnalyticsView

struct AnalyticsView: View {
    private let dau = AdminPreviewData.dau
    private let wau = AdminPreviewData.wau
    private let acceptRate = AdminPreviewData.acceptRate
    private let messages: [Double] = [120, 140, 135, 160, 175, 182, 178]
    private let squads: [Double] = [1.2, 1.4, 1.5, 1.7, 1.9, 2.1, 2.0]
    private let retention: [Double] = [42, 44, 43, 46, 48, 51, 50]
    private let widget: [Double] = [8, 9, 11, 12, 14, 16, 15]
    private let notification: [Double] = [55, 57, 56, 59, 61, 63, 62]

    var body: some View {
        NavigationStack {
            List {
                Section("DAU (K, 7d)") {
                    SwiftBarChart(series: dau).frame(height: 140)
                }
                Section("WAU (K, 7d)") {
                    SwiftBarChart(series: wau).frame(height: 140)
                }
                Section("Sessions accept-rate (%, 7d)") {
                    SwiftBarChart(series: acceptRate).frame(height: 140)
                }
                Section("Messages (K, 7d)") {
                    SwiftBarChart(series: AnalyticsSeries(label: "Messages", values: messages)).frame(height: 120)
                }
                Section("Squads created (7d)") {
                    SwiftBarChart(series: AnalyticsSeries(label: "Squads", values: squads)).frame(height: 120)
                }
                Section("Retention D7 (%, 7d)") {
                    SwiftBarChart(series: AnalyticsSeries(label: "Retention", values: retention)).frame(height: 120)
                }
                Section("Widget usage (%, 7d)") {
                    SwiftBarChart(series: AnalyticsSeries(label: "Widget", values: widget)).frame(height: 120)
                }
                Section("Notification CTR (%, 7d)") {
                    SwiftBarChart(series: AnalyticsSeries(label: "CTR", values: notification)).frame(height: 120)
                }
                Section("Totals") {
                    MetricRow(title: "Streak ≥ 7d", value: "18%")
                    MetricRow(title: "Premium conversion", value: "3.1%")
                    MetricRow(title: "Median session", value: "42 min")
                    MetricRow(title: "Sessions today", value: "3 912")
                }
            }
            .navigationTitle("Analytics")
        }
    }
}

// MARK: - SwiftBarChart (Swift Charts)

struct SwiftBarChart: View {
    var series: AnalyticsSeries

    private struct Point: Identifiable {
        var id: Int
        var value: Double
    }

    private var points: [Point] {
        series.values.enumerated().map { Point(id: $0.offset, value: $0.element) }
    }

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Day", point.id),
                y: .value(series.label, point.value)
            )
            .foregroundStyle(.orange.gradient)
        }
        .chartXAxis(.hidden)
        .padding(.vertical, 4)
        .accessibilityLabel("\(series.label) chart")
    }
}

// MARK: - BarChart (legacy, без зависимостей — оставлен для совместимости)

struct BarChart: View {
    var values: [Double]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(values.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(.orange)
                    .frame(height: barHeight(i))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func barHeight(_ i: Int) -> CGFloat {
        guard let max = values.max(), max > 0 else { return 0 }
        return CGFloat(values[i] / max) * 110
    }
}

#Preview {
    AnalyticsView()
        .preferredColorScheme(.dark)
}
