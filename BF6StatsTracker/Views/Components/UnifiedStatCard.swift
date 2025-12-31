//
//  UnifiedStatCard.swift
//  BF6StatsTracker
//
//  Unified stat card component with consistent styling and configuration options
//

import SwiftUI

// MARK: - Unified Stat Card

struct UnifiedStatCard: View {
    let config: StatCardConfig
    @State private var displayValue: Double = 0
    @State private var isHovered = false

    var body: some View {
        cardContent
            .padding(config.size.padding)
            .background(cardBackground)
            .overlay(cardBorder)
            .scaleEffect(config.enableHover && isHovered ? 1.02 : 1.0)
            .animation(.smoothSpring, value: isHovered)
            .onHover { hovering in
                if config.enableHover {
                    isHovered = hovering
                }
            }
            .onAppear {
                if config.isAnimated, let numericValue = config.numericValue {
                    displayValue = numericValue
                }
            }
            .onChange(of: config.numericValue ?? 0) { oldValue, newValue in
                if config.isAnimated {
                    withAnimation(.easeOut(duration: 0.8)) {
                        displayValue = newValue
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(config.title): \(config.valueText)")
            .accessibilityHint(config.subtitle ?? "")
            .help("\(config.title): \(config.valueText)")
    }
    
    // MARK: - View Components
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            valueView
            
            if let subtitle = config.subtitle {
                subtitleView(subtitle)
            }
            
            if let progress = config.progress {
                progressView(progress)
            }
            
            if let trend = config.trend {
                trendView(trend)
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 6) {
            Image(systemName: config.icon)
                .font(.caption)
                .foregroundStyle(config.color)

            Text(config.title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            if let badge = config.badge {
                badgeView(badge)
            }
        }
    }
    
    private func badgeView(_ badge: String) -> some View {
        Text(badge)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(Theme.selectedText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(config.color.opacity(0.8))
            .cornerRadius(4)
    }
    
    private var valueView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            valueText
                .font(config.size.valueFont)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(Theme.textPrimary)

            if let suffix = config.suffix {
                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
    }
    
    @ViewBuilder
    private var valueText: some View {
        if config.isAnimated {
            Text(formatValue(displayValue))
                .contentTransition(.numericText(value: displayValue))
        } else {
            Text(config.valueText)
        }
    }
    
    private func subtitleView(_ subtitle: String) -> some View {
        Text(subtitle)
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
    }
    
    private func progressView(_ progress: ProgressInfo) -> some View {
        let normalizedValue = progress.max > 0 ? min(progress.current / progress.max, 1.0) : 0.0
        return ProgressBarView(
            value: normalizedValue,
            color: config.color,
            height: 6,
            showShimmer: config.showProgressShimmer
        )
        .frame(height: 6)
    }
    
    private func trendView(_ trend: TrendInfo) -> some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
                .font(.caption2)
                .foregroundStyle(trend.color)

            Text(trend.text)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(trend.color)

            if let secondaryText = trend.secondaryText {
                Text(secondaryText)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(config.backgroundStyle == .card ? Theme.cardBackground : Color(NSColor.controlBackgroundColor))
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                config.showBorder ? config.color.opacity(isHovered ? 0.4 : 0.2) : Color.clear,
                lineWidth: config.showBorder ? (isHovered ? 2 : 1) : 0
            )
    }

    private func formatValue(_ value: Double) -> String {
        if let formatter = config.valueFormatter {
            return formatter(value)
        }

        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Configuration

struct StatCardConfig {
    let title: String
    let valueText: String
    let icon: String
    let color: Color

    // Optional properties
    var subtitle: String? = nil
    var badge: String? = nil
    var suffix: String? = nil
    var trend: TrendInfo? = nil
    var progress: ProgressInfo? = nil
    var size: CardSize = .medium
    var backgroundStyle: BackgroundStyle = .card
    var showBorder: Bool = true
    var enableHover: Bool = true
    var showProgressShimmer: Bool = true
    var isAnimated: Bool = false
    var numericValue: Double? = nil
    var valueFormatter: ((Double) -> String)? = nil

    // Convenience initializers
    init(
        title: String,
        value: String,
        icon: String,
        color: Color,
        subtitle: String? = nil,
        trend: TrendInfo? = nil,
        badge: String? = nil
    ) {
        self.title = title
        self.valueText = value
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
        self.trend = trend
        self.badge = badge
    }

    init(
        title: String,
        numericValue: Double,
        icon: String,
        color: Color,
        subtitle: String? = nil,
        trend: TrendInfo? = nil,
        formatter: ((Double) -> String)? = nil
    ) {
        self.title = title
        self.numericValue = numericValue
        self.valueText = formatter?(numericValue) ?? String(format: "%.0f", numericValue)
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
        self.trend = trend
        self.isAnimated = true
        self.valueFormatter = formatter
    }
}

// MARK: - Supporting Types

struct TrendInfo {
    let value: Double
    let text: String
    var secondaryText: String? = nil

    var icon: String {
        if abs(value) < 0.01 {
            return "minus"
        }
        return value > 0 ? "arrow.up" : "arrow.down"
    }

    var color: Color {
        if abs(value) < 0.01 {
            return Theme.textSecondary
        }
        return value > 0 ? .green : .red
    }

    init(value: Double, text: String? = nil, secondaryText: String? = nil) {
        self.value = value
        self.text = text ?? (value > 0 ? "+\(String(format: "%.1f", abs(value)))%" : "\(String(format: "%.1f", value))%")
        self.secondaryText = secondaryText
    }

    init(delta: Int, vsText: String = "vs last session") {
        self.value = Double(delta)
        self.text = delta > 0 ? "+\(delta)" : "\(delta)"
        self.secondaryText = vsText
    }
}

struct ProgressInfo {
    let current: Double
    let max: Double

    var percentage: Double {
        guard max > 0 else { return 0 }
        return min(current / max, 1.0) * 100
    }
}

enum CardSize {
    case small
    case medium
    case large

    var padding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        }
    }

    var valueFont: Font {
        switch self {
        case .small: return .system(size: 20, weight: .bold, design: .rounded)
        case .medium: return .system(size: 28, weight: .bold, design: .rounded)
        case .large: return .system(size: 32, weight: .bold, design: .rounded)
        }
    }
}

enum BackgroundStyle {
    case card
    case control
}

// MARK: - Legacy Support Wrapper

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    var trend: TrendInfo? = nil
    var badge: String? = nil

    var body: some View {
        UnifiedStatCard(config: StatCardConfig(
            title: title,
            value: value,
            icon: icon,
            color: color,
            subtitle: subtitle,
            trend: trend,
            badge: badge
        ))
    }
}

// MARK: - Comparison Card Variant

struct ComparisonStatCard: View {
    let title: String
    let todayValue: Double
    let yesterdayValue: Double
    let icon: String
    let accentColor: Color
    let isLowerBetter: Bool
    let formatter: (Double) -> String

    init(
        title: String,
        todayValue: Double,
        yesterdayValue: Double,
        icon: String,
        accentColor: Color,
        isLowerBetter: Bool = false,
        formatter: @escaping (Double) -> String = { String(format: "%.0f", $0) }
    ) {
        self.title = title
        self.todayValue = todayValue
        self.yesterdayValue = yesterdayValue
        self.icon = icon
        self.accentColor = accentColor
        self.isLowerBetter = isLowerBetter
        self.formatter = formatter
    }

    private var delta: Double {
        todayValue - yesterdayValue
    }

    private var isImprovement: Bool {
        isLowerBetter ? delta < 0 : delta > 0
    }

    var body: some View {
        var config = StatCardConfig(
            title: title,
            numericValue: todayValue,
            icon: icon,
            color: accentColor,
            subtitle: "vs \(formatter(yesterdayValue))",
            formatter: formatter
        )

        if abs(delta) > 0.01 {
            config.trend = TrendInfo(
                value: delta,
                text: delta > 0 ? "+\(formatter(abs(delta)))" : formatter(delta),
                secondaryText: yesterdayValue > 0 ? String(format: "(%.0f%%)", abs(delta / yesterdayValue * 100)) : nil
            )
        }

        config.progress = ProgressInfo(current: todayValue, max: max(todayValue, yesterdayValue))
        config.backgroundStyle = .control

        return UnifiedStatCard(config: config)
    }
}

// MARK: - Preview

#Preview("Stat Card Variants") {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            UnifiedStatCard(config: StatCardConfig(
                title: "Kills",
                value: "1,234",
                icon: "target",
                color: Theme.bf6Red,
                subtitle: "2.4 per min",
                trend: TrendInfo(value: 12.5)
            ))

            UnifiedStatCard(config: StatCardConfig(
                title: "K/D Ratio",
                numericValue: 1.67,
                icon: "chart.line.uptrend.xyaxis",
                color: Theme.bf6Orange,
                subtitle: "All-time best",
                trend: TrendInfo(value: 5.2),
                formatter: { String(format: "%.2f", $0) }
            ))
        }

        ComparisonStatCard(
            title: "Kills",
            todayValue: 45,
            yesterdayValue: 33,
            icon: "target",
            accentColor: .green
        )
    }
    .padding()
    .frame(width: 800)
    .background(Theme.backgroundPrimary)
}
