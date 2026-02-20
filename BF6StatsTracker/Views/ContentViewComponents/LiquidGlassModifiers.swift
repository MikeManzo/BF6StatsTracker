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
//  LiquidGlassModifiers.swift
//  BF6StatsTracker
//
//  Liquid Glass effect modifiers for macOS 26+
//

import SwiftUI

// MARK: - Conditional Background Extension

extension View {
    /// Conditionally applies `.ultraThinMaterial` backdrop blur.
    func conditionalBackground(apply: Bool) -> AnyView {
        if apply {
            return AnyView(self.background(.ultraThinMaterial))
        }
        return AnyView(self)
    }
}

// MARK: - Tab Glass Modifier

/// Applies glassEffect to a main-tab pill on macOS 26+; no-op on older OS.
struct TabGlassModifier: ViewModifier {
    let isSelected: Bool
    let isExperimental: Bool
    let usesGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), usesGlass {
            content
                .glassEffect(
                    .regular.tint(isSelected ? (isExperimental ? Theme.bf6Purple : Theme.bf6Blue) : Color.white.opacity(0.12)),
                    in: .rect(cornerRadius: 8)
                )
        } else {
            content
        }
    }
}

// MARK: - Sub-Tab Glass Modifier

/// Applies glassEffect to a sub-tab pill on macOS 26+; no-op on older OS.
struct SubTabGlassModifier: ViewModifier {
    let isSelected: Bool
    let accentColor: Color
    let usesGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), usesGlass {
            content
                .glassEffect(
                    .regular.tint(isSelected ? accentColor : .clear),
                    in: .rect(cornerRadius: 8)
                )
        } else {
            content
        }
    }
}

// MARK: - Glass Container Wrapper

/// Wraps content in a GlassEffectContainer on macOS 26+ when glass is enabled; passthrough otherwise.
struct GlassContainerWrapper<Content: View>: View {
    let usesGlass: Bool
    let content: Content

    init(usesGlass: Bool, @ViewBuilder content: () -> Content) {
        self.usesGlass = usesGlass
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(macOS 26, *), usesGlass {
            GlassEffectContainer(spacing: 12) {
                content
            }
        } else {
            content
        }
    }
}
