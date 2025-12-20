//
//  Extensions.swift
//  BF6StatsTracker
//
//  Utility extensions and helpers
//

import SwiftUI

// MARK: - Theme Colors (Light/Dark Mode Support)

// Theme provides convenient access to Asset Catalog colors without name collisions.
// Usage: Theme.backgroundPrimary, Theme.textPrimary, Theme.bf6Red, etc.
enum Theme {
    // Background Colors - automatically adapt to light/dark mode
    static let backgroundPrimary = Color("BackgroundPrimary")
    static let backgroundSecondary = Color("BackgroundSecondary")
    static let backgroundTertiary = Color("BackgroundTertiary")
    static let cardBackground = Color("CardBackground")

    // Text Colors
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")

    // UI Element Colors
    static let borderColor = Color("BorderColor")
    static let overlayColor = Color("OverlayColor")

    // Brand Colors (BF6 Theme)
    static let bf6Blue = Color("BF6Blue")
    static let bf6Green = Color("BF6Green")
    static let bf6Orange = Color("BF6Orange")
    static let bf6Purple = Color("BF6Purple")
    static let bf6Red = Color("BF6Red")

    // Semantic Convenience Colors
    static var adaptiveWhite: Color { textPrimary }
    static var adaptiveGray: Color { textSecondary }

    // Button/Selection Colors - for pills, toggles etc.
    // In dark mode, selected items show white text. In light mode, also white text on colored bg.
    static let selectedText = Color.white

    // Subtle overlay for hover states and backgrounds (adapts to mode)
    // Use this for Color.white.opacity(0.05) replacements
    static var subtleOverlay: Color { overlayColor }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.borderColor, lineWidth: 1)
            )
    }
    
    func glassStyle() -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(16)
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Number Formatting

extension Int {
    var abbreviated: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        }
        return String(self)
    }
}

extension Double {
    var percentString: String {
        return String(format: "%.1f%%", self)
    }
    
    var ratioString: String {
        return String(format: "%.2f", self)
    }
}

// MARK: - Time Formatting

extension Int {
    var timeString: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var shortTimeString: String {
        let hours = self / 3600
        
        if hours > 0 {
            return "\(hours)h"
        } else {
            let minutes = (self % 3600) / 60
            return "\(minutes)m"
        }
    }
}

// MARK: - Date Extensions

extension Date {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - String Extensions

extension String {
    var sanitizedForURL: String {
        return self
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}

// MARK: - Gradient Presets

struct GradientPresets {
    static let fire = LinearGradient(
        colors: [Theme.bf6Orange, Theme.bf6Red],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ocean = LinearGradient(
        colors: [Theme.bf6Blue, Theme.bf6Purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let forest = LinearGradient(
        colors: [Theme.bf6Green, .teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sunset = LinearGradient(
        colors: [.yellow, Theme.bf6Orange, Theme.bf6Red],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Adaptive background gradient that works in both light and dark mode
    static let background = LinearGradient(
        colors: [Theme.backgroundPrimary, Theme.backgroundSecondary],
        startPoint: .top,
        endPoint: .bottom
    )

    // For legacy support - maps to adaptive background
    static let night = LinearGradient(
        colors: [Theme.backgroundSecondary, Theme.backgroundPrimary],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Animation Extensions

extension Animation {
    static let smoothSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let gentleEase = Animation.easeInOut(duration: 0.3)
}

// MARK: - Platform Extension

extension Platform: Codable {
    enum CodingKeys: String, CodingKey {
        case rawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Platform(rawValue: rawValue) ?? .pc
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Keyboard Shortcuts

extension KeyboardShortcut {
    static let refresh = KeyboardShortcut("r", modifiers: .command)
    static let search = KeyboardShortcut("f", modifiers: .command)
    static let settings = KeyboardShortcut(",", modifiers: .command)
    static let quit = KeyboardShortcut("q", modifiers: .command)
}

// MARK: - Loading Indicator

struct LoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Theme.bf6Orange, lineWidth: 3)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)

            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)?
    var actionTitle: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(Theme.textSecondary)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            Text(message)
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)

            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Theme.bf6Blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(40)
    }
}

// MARK: - Stat Bar View

struct StatBarView: View {
    let value: Double
    let maxValue: Double
    let color: Color
    let height: CGFloat

    init(value: Double, maxValue: Double = 100, color: Color = Theme.bf6Blue, height: CGFloat = 6) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Theme.overlayColor)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(min(value / maxValue, 1.0)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Tooltip Modifier

struct TooltipModifier: ViewModifier {
    let text: String
    
    func body(content: Content) -> some View {
        content
            .help(text)
    }
}

extension View {
    func tooltip(_ text: String) -> some View {
        modifier(TooltipModifier(text: text))
    }
}
