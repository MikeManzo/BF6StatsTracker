//
// This file is part of BF6StatsTracker.
//
// BF6StatsTracker is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 or later.
//
// Copyright (c) 2026 CitizenCoder
//

//
//  VisualEffects.swift
//  BF6StatsTracker
//
//  Enhanced visual components and effects
//

import SwiftUI
import AppKit

// MARK: - Enhanced Stat Chip

struct EnhancedStatChip: View {
    let label: String
    let value: String
    let color: Color
    var trend: TrendDirection? = nil
    var showGlow: Bool = false

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(color)

                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.caption2)
                        .foregroundColor(trend.color)
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Subtle gradient background
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(isHovered ? 0.12 : 0.08))

                // Border highlight
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(color.opacity(isHovered ? 0.3 : 0.2), lineWidth: 1)
            }
        )
        .shadow(color: color.opacity(0.15), radius: isHovered ? 6 : 4, x: 0, y: 2)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .if(showGlow) { view in
            view.glow(color: color, radius: 6)
        }
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let value: Double // 0.0 to 1.0
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat

    init(value: Double, color: Color, lineWidth: CGFloat = 4, size: CGFloat = 40) {
        self.value = value
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: min(value, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: value)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Mini Bar Chart

struct MiniBarChart: View {
    let values: [Double]
    let color: Color
    let height: CGFloat

    init(values: [Double], color: Color, height: CGFloat = 20) {
        self.values = values
        self.color = color
        self.height = height
    }

    private var maxValue: Double {
        values.max() ?? 1.0
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(index == values.count - 1 ? 1.0 : 0.6),
                                color.opacity(index == values.count - 1 ? 0.8 : 0.4)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: CGFloat(value / maxValue) * height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Sparkline View

struct SparklineView: View {
    let data: [Double]
    let color: Color
    let showGradient: Bool
    let lineWidth: CGFloat

    init(data: [Double], color: Color, showGradient: Bool = true, lineWidth: CGFloat = 2) {
        self.data = data
        self.color = color
        self.showGradient = showGradient
        self.lineWidth = lineWidth
    }

    var body: some View {
        GeometryReader { geometry in
            let path = createPath(in: geometry.size)

            ZStack(alignment: .bottom) {
                // Gradient fill
                if showGradient {
                    path
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                // Line
                path
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func createPath(in size: CGSize) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }

        let maxValue = data.max() ?? 1
        let minValue = data.min() ?? 0
        let range = maxValue - minValue
        let stepX = size.width / CGFloat(data.count - 1)

        // Start path
        let startY = range > 0 ? size.height - (CGFloat(data[0] - minValue) / CGFloat(range)) * size.height : size.height / 2
        path.move(to: CGPoint(x: 0, y: startY))

        // Add lines
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let y = range > 0 ? size.height - (CGFloat(value - minValue) / CGFloat(range)) * size.height : size.height / 2
            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Close path for gradient fill
        if showGradient {
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - Performance Heatmap Background

struct PerformanceHeatmap: View {
    let performance: Double // 0.0 to 1.0

    var heatColor: Color {
        if performance > 0.7 { return .green }
        else if performance > 0.4 { return .orange }
        else { return .red }
    }

    var body: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    colors: [
                        heatColor.opacity(0.15),
                        heatColor.opacity(0.05),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
            )
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let icon: String
    let color: Color
    let size: CGFloat
    var glowEffect: Bool = true

    init(icon: String, color: Color, size: CGFloat = 32, glowEffect: Bool = true) {
        self.icon = icon
        self.color = color
        self.size = size
        self.glowEffect = glowEffect
    }

    var body: some View {
        ZStack {
            // Glow effect
            if glowEffect {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: size + 8, height: size + 8)
                    .blur(radius: 8)
            }

            // Badge background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Icon
            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(Theme.selectedText)
        }
    }
}

// MARK: - BF6 Loading Indicator

struct BF6LoadingIndicator: View {
    @State private var rotation: Double = 0
    let size: CGFloat

    init(size: CGFloat = 40) {
        self.size = size
    }

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .trim(from: 0.2, to: 1.0)
                .stroke(
                    AngularGradient(
                        colors: [Theme.bf6Orange, Theme.bf6Red, Theme.bf6Orange],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))

            // Inner icon
            Image(systemName: "chart.bar.fill")
                .font(.system(size: size * 0.4))
                .foregroundColor(Theme.bf6Orange)
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Rich Tooltip

struct RichTooltip: View {
    let title: String
    let details: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Divider()

            ForEach(details, id: \.0) { detail in
                HStack {
                    Text(detail.0)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(detail.1)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.overlayColor)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .frame(minWidth: 200)
    }
}

// MARK: - Vibrancy Effect (macOS)

struct VibrancyEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(material: NSVisualEffectView.Material = .hudWindow, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Pulsing Animation

struct PulsingView: View {
    let color: Color
    let size: CGFloat
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.3 : 0.8)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Gradient Border

struct GradientBorder: ViewModifier {
    let colors: [Color]
    let lineWidth: CGFloat
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
            )
    }
}

extension View {
    func gradientBorder(colors: [Color], lineWidth: CGFloat = 1, cornerRadius: CGFloat = 8) -> some View {
        modifier(GradientBorder(colors: colors, lineWidth: lineWidth, cornerRadius: cornerRadius))
    }
}

// MARK: - Animated Number

struct AnimatedNumber: View {
    let value: Double
    let format: String
    @State private var displayValue: Double = 0

    init(value: Double, format: String = "%.0f") {
        self.value = value
        self.format = format
    }

    var body: some View {
        Text(String(format: format, displayValue))
            .onChange(of: value) { oldValue, newValue in
                withAnimation(.spring(response: 0.6)) {
                    displayValue = newValue
                }
            }
            .onAppear {
                displayValue = value
            }
    }
}
