//
//  AnimatedNumber.swift
//  BF6StatsTracker
//
//  Component for animating number values with count-up effect
//

import SwiftUI

/// A view that animates numeric values with a smooth count-up effect
struct AnimatedNumber: View, Animatable {
    var value: Double
    var format: String

    init(_ value: Double, format: String = "%.0f") {
        self.value = value
        self.format = format
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(String(format: format, value))
    }
}

/// Integer variant for cleaner API when dealing with Int values
struct AnimatedInteger: View, Animatable {
    var value: Double

    init(_ value: Int) {
        self.value = Double(value)
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value))")
    }
}

/// Formatted number variant that supports custom string formatting
struct AnimatedFormattedNumber: View, Animatable {
    var value: Double
    var formatter: (Double) -> String

    init(_ value: Double, formatter: @escaping (Double) -> String) {
        self.value = value
        self.formatter = formatter
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(formatter(value))
    }
}

#Preview {
    VStack(spacing: 20) {
        AnimatedNumber(1234.56, format: "%.2f")
            .font(.largeTitle)

        AnimatedInteger(42)
            .font(.largeTitle)

        AnimatedFormattedNumber(12345) { value in
            Int(value).formatted()
        }
        .font(.largeTitle)
    }
    .padding()
}
