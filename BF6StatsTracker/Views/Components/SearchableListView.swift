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
//  SearchableListView.swift
//  BF6StatsTracker
//
//  Reusable search and filter wrapper for list views
//

import SwiftUI

// MARK: - Searchable List View

struct SearchableListView<Item: Identifiable, FilterType: Hashable, Content: View>: View {
    @Environment(\.accentColor) private var accentColor

    let items: [Item]
    let searchPlaceholder: String
    let filters: [FilterOption<FilterType>]?
    let sortOptions: [SortOption<Item>]
    @Binding var searchText: String
    @Binding var selectedFilter: FilterType?
    @Binding var selectedSort: SortOption<Item>
    let content: ([Item]) -> Content

    @FocusState private var isSearchFocused: Bool
    @State private var showSortMenu = false

    init(
        items: [Item],
        searchText: Binding<String>,
        searchPlaceholder: String = "Search...",
        filters: [FilterOption<FilterType>]? = nil,
        selectedFilter: Binding<FilterType?> = .constant(nil),
        sortOptions: [SortOption<Item>],
        selectedSort: Binding<SortOption<Item>>,
        @ViewBuilder content: @escaping ([Item]) -> Content
    ) {
        self.items = items
        self._searchText = searchText
        self.searchPlaceholder = searchPlaceholder
        self.filters = filters
        self._selectedFilter = selectedFilter
        self.sortOptions = sortOptions
        self._selectedSort = selectedSort
        self.content = content
    }

    private var filteredAndSortedItems: [Item] {
        items.sorted(by: selectedSort.comparator)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Search and controls bar
            HStack(spacing: 16) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondary)
                        .font(.body)

                    TextField(searchPlaceholder, text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.textPrimary)
                        .focused($isSearchFocused)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear search")
                    }
                }
                .padding(10)
                .background(Theme.overlayColor)
                .cornerRadius(10)
                .frame(maxWidth: 300)

                Spacer()

                // Sort picker
                HStack(spacing: 8) {
                    Text("Sort:")
                        .foregroundColor(Theme.textSecondary)
                        .font(.subheadline)

                    Picker("Sort", selection: $selectedSort) {
                        ForEach(sortOptions) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                    .help("Sort items")
                }

                // Results count
                Text("\(filteredAndSortedItems.count) \(filteredAndSortedItems.count == 1 ? "item" : "items")")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.overlayColor)
                    .cornerRadius(6)
            }
            .accessibilityElement(children: .contain)

            // Filter pills (if provided)
            if let filterOptions = filters, !filterOptions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // "All" filter
                        FilterPill(
                            title: "All",
                            icon: "square.grid.2x2.fill",
                            isSelected: selectedFilter == nil,
                            color: accentColor
                        ) {
                            selectedFilter = nil
                        }

                        ForEach(filterOptions) { filter in
                            FilterPill(
                                title: filter.label,
                                icon: filter.icon,
                                isSelected: selectedFilter == filter.value,
                                color: filter.color
                            ) {
                                selectedFilter = filter.value
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Content
            content(filteredAndSortedItems)
        }
        .onAppear {
            // Keyboard shortcut handler is set up in parent view
        }
    }
}

// MARK: - Filter Option

struct FilterOption<T: Hashable>: Identifiable {
    let id = UUID()
    let value: T
    let label: String
    let icon: String
    let color: Color

    init(value: T, label: String, icon: String, color: Color = Theme.bf6Blue) {
        self.value = value
        self.label = label
        self.icon = icon
        self.color = color
    }
}

// MARK: - Sort Option

struct SortOption<Item>: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let comparator: (Item, Item) -> Bool

    init(label: String, comparator: @escaping (Item, Item) -> Bool) {
        self.label = label
        self.comparator = comparator
    }

    static func == (lhs: SortOption<Item>, rhs: SortOption<Item>) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? Theme.selectedText : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Theme.overlayColor)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .help("\(isSelected ? "Showing" : "Show") \(title.lowercased())")
        .accessibilityLabel("\(title) filter")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Preview

#Preview {
    struct PreviewItem: Identifiable {
        let id = UUID()
        let name: String
        let category: String
        let value: Int
    }

    enum Category: String, CaseIterable {
        case weapons = "Weapons"
        case vehicles = "Vehicles"
        case gadgets = "Gadgets"
    }

    struct PreviewWrapper: View {
        @State private var searchText = ""
        @State private var selectedFilter: Category? = nil
        @State private var selectedSort: SortOption<PreviewItem>

        let items = [
            PreviewItem(name: "M5A3", category: "Weapons", value: 1234),
            PreviewItem(name: "AK-24", category: "Weapons", value: 987),
            PreviewItem(name: "M1A1", category: "Vehicles", value: 456),
            PreviewItem(name: "C5", category: "Gadgets", value: 789)
        ]

        let sortOptions: [SortOption<PreviewItem>]

        init() {
            let sorts = [
                SortOption<PreviewItem>(label: "Value", comparator: { $0.value > $1.value }),
                SortOption<PreviewItem>(label: "Name", comparator: { $0.name < $1.name })
            ]
            self.sortOptions = sorts
            self._selectedSort = State(initialValue: sorts[0])
        }

        var filteredItems: [PreviewItem] {
            var result = items

            if let filter = selectedFilter {
                result = result.filter { $0.category == filter.rawValue }
            }

            if !searchText.isEmpty {
                result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }

            return result
        }

        var body: some View {
            SearchableListView(
                items: filteredItems,
                searchText: $searchText,
                searchPlaceholder: "Search items...",
                filters: Category.allCases.map { category in
                    FilterOption(
                        value: category,
                        label: category.rawValue,
                        icon: "star.fill",
                        color: .blue
                    )
                },
                selectedFilter: $selectedFilter,
                sortOptions: sortOptions,
                selectedSort: $selectedSort
            ) { items in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            HStack {
                                Text(item.name)
                                    .font(.headline)
                                Spacer()
                                Text("\(item.value)")
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .padding()
            .frame(width: 800, height: 600)
            .background(Theme.backgroundPrimary)
        }
    }

    return PreviewWrapper()
}
