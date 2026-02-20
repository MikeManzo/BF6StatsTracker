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
//  NavigationComponents.swift
//  BF6StatsTracker
//
//  Navigation components: tab bar, sub-menu, and tab management
//

import SwiftUI

// MARK: - Tab Bar View

struct TabBarView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    let usesLiquidGlass: Bool
    
    var body: some View {
        GlassContainerWrapper(usesGlass: usesLiquidGlass) {
            HStack(spacing: 0) {
                ForEach(Array(viewModel.visibleMainTabs.enumerated()), id: \.element) { index, tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectedMainTab = tab
                            // Set default sub-tab if applicable
                            viewModel.selectedSubTab = tab.defaultSubTab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: tab.icon)
                                    .font(.title3)

                                // Experimental badge
                                if tab.isExperimental {
                                    Circle()
                                        .fill(Theme.bf6Purple)
                                        .frame(width: 6, height: 6)
                                        .offset(x: 2, y: -2)
                                }
                            }

                            Text(tab.rawValue)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(viewModel.selectedMainTab == tab ? Theme.textPrimary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            viewModel.selectedMainTab == tab && !usesLiquidGlass ?
                            (tab.isExperimental ? Theme.bf6Purple.opacity(0.3) : Theme.bf6Blue.opacity(0.3)) :
                            Color.clear
                        )
                        .modifier(TabGlassModifier(
                            isSelected: viewModel.selectedMainTab == tab,
                            isExperimental: tab.isExperimental,
                            usesGlass: usesLiquidGlass
                        ))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .if(index < 9) { view in
                        view
                            .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                            .help("\(tab.rawValue) (⌘\(index + 1))")
                    }
                    .if(index >= 9) { view in
                        view.help(tab.rawValue)
                    }
                    .accessibilityLabel("\(tab.rawValue) tab")
                    .accessibilityAddTraits(viewModel.selectedMainTab == tab ? [.isSelected] : [])
                    .contextMenu {
                        Button("Hide Tab") {
                            hideTab(tab)
                        }
                    }
                    .onDrag {
                        NSItemProvider(object: tab.rawValue as NSString)
                    }
                    .onDrop(of: [.text], delegate: TabDropDelegate(
                        tab: tab,
                        tabs: viewModel.visibleMainTabs,
                        onMove: { from, to in
                            moveTab(from: from, to: to)
                        }
                    ))
                }
            }
        }
        .conditionalBackground(apply: !usesLiquidGlass)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation tabs")
    }
    
    private func hideTab(_ tab: MainTab) {
        viewModel.settings.hiddenTabs.insert(tab.rawValue)
        Task {
            await viewModel.saveSettings()
        }
        
        // If the current tab is being hidden, switch to the first visible tab
        if viewModel.selectedMainTab == tab {
            if let firstVisible = viewModel.visibleMainTabs.first {
                withAnimation {
                    viewModel.selectedMainTab = firstVisible
                    viewModel.selectedSubTab = firstVisible.defaultSubTab
                }
            }
        }
    }
    
    private func moveTab(from source: MainTab, to destination: MainTab) {
        let allTabs = MainTab.allCases.map { $0.rawValue }
        
        // Initialize tabOrder if it's empty
        if viewModel.settings.tabOrder.isEmpty {
            viewModel.settings.tabOrder = allTabs
        }
        
        guard let sourceIndex = viewModel.settings.tabOrder.firstIndex(of: source.rawValue),
              let destIndex = viewModel.settings.tabOrder.firstIndex(of: destination.rawValue) else {
            return
        }
        
        withAnimation {
            viewModel.settings.tabOrder.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destIndex > sourceIndex ? destIndex + 1 : destIndex)
        }
        
        Task {
            await viewModel.saveSettings()
        }
    }
}

// MARK: - Sub-Menu View

struct SubMenuView: View {
    @Environment(\.accentColor) private var accentColor
    @EnvironmentObject var viewModel: StatsViewModel
    let subTabs: [StatTab]
    let usesLiquidGlass: Bool
    
    var body: some View {
        GlassContainerWrapper(usesGlass: usesLiquidGlass) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(subTabs, id: \.self) { subTab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedSubTab = subTab
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: subTab.icon)
                                    .font(.body)

                                Text(subTab.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(viewModel.selectedSubTab == subTab ? Theme.textPrimary : .secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                viewModel.selectedSubTab == subTab && !usesLiquidGlass ?
                                accentColor.opacity(0.3) :
                                Color.clear
                            )
                            .modifier(SubTabGlassModifier(
                                isSelected: viewModel.selectedSubTab == subTab,
                                accentColor: accentColor,
                                usesGlass: usesLiquidGlass
                            ))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(subTab.rawValue) sub-tab")
                        .accessibilityAddTraits(viewModel.selectedSubTab == subTab ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .conditionalBackground(apply: !usesLiquidGlass)
        .frame(height: 52)
    }
}

// MARK: - Tab Drop Delegate

struct TabDropDelegate: DropDelegate {
    let tab: MainTab
    let tabs: [MainTab]
    let onMove: (MainTab, MainTab) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let sourceTab = info.itemProviders(for: [.text]).first else { return }
        
        sourceTab.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let tabName = String(data: data, encoding: .utf8),
                  let sourceMainTab = MainTab.allCases.first(where: { $0.rawValue == tabName }),
                  sourceMainTab != tab else {
                return
            }
            
            DispatchQueue.main.async {
                onMove(sourceMainTab, tab)
            }
        }
    }
}
