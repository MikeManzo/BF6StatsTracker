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
//  ColorPickerDot.swift
//  BF6StatsTracker
//
//  Inline color picker displayed as a small colored dot
//

import SwiftUI

/// A small colored dot that opens a color picker popover when clicked
struct ColorPickerDot: View {
    @Binding var color: Color
    @State private var showPicker = false

    var dotSize: CGFloat = 10

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: dotSize, height: dotSize)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.3), lineWidth: 1)
            )
            .contentShape(Circle())
            .onTapGesture {
                showPicker.toggle()
            }
            .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                ColorPickerPopover(color: $color, isPresented: $showPicker)
            }
            .help("Click to change color")
    }
}

/// Popover content with preset colors and a custom color picker
struct ColorPickerPopover: View {
    @Environment(\.accentColor) private var accentColor
    @Binding var color: Color
    @Binding var isPresented: Bool

    // Local state to track changes before committing
    @State private var selectedColor: Color

    // Preset color options
    private let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown
    ]

    init(color: Binding<Color>, isPresented: Binding<Bool>) {
        self._color = color
        self._isPresented = isPresented
        self._selectedColor = State(initialValue: color.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Color")
                .font(.headline)
                .fontWeight(.semibold)

            // Preset colors grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 8), count: 6), spacing: 8) {
                ForEach(presetColors, id: \.self) { presetColor in
                    Circle()
                        .fill(presetColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(
                            // Checkmark for selected color
                            Group {
                                if colorsMatch(selectedColor, presetColor) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 1)
                                }
                            }
                        )
                        .contentShape(Circle())
                        .onTapGesture {
                            selectedColor = presetColor
                        }
                }
            }

            Divider()

            // Custom color picker
            HStack {
                Text("Custom:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                    .labelsHidden()
            }

            HStack {
                Spacer()
                Button {
                    color = selectedColor
                    isPresented = false
                } label: {
                    Text("Done")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(accentColor)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 220)
    }

    /// Compare two colors for approximate equality
    private func colorsMatch(_ c1: Color, _ c2: Color) -> Bool {
        guard let ns1 = NSColor(c1).usingColorSpace(.deviceRGB),
              let ns2 = NSColor(c2).usingColorSpace(.deviceRGB) else {
            return false
        }
        let threshold: CGFloat = 0.05
        return abs(ns1.redComponent - ns2.redComponent) < threshold &&
               abs(ns1.greenComponent - ns2.greenComponent) < threshold &&
               abs(ns1.blueComponent - ns2.blueComponent) < threshold
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var testColor: Color = .purple

        var body: some View {
            HStack {
                Text("Graph Label")
                ColorPickerDot(color: $testColor)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
