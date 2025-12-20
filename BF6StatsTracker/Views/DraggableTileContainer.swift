//
//  DraggableTileContainer.swift
//  BF6StatsTracker
//
//  Container for moveable class tiles
//

import SwiftUI

struct DraggableTileContainer: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @State private var containerSize: CGSize = .zero
    
    private let tileWidth: CGFloat = 280
    private let tileHeight: CGFloat = 200
    private let padding: CGFloat = 20
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.classStats.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 500)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20)
                    ],
                    spacing: 20
                ) {
                    ForEach(viewModel.classStats) { classStats in
                        ClassTileView(
                            classStats: classStats,
                            position: TilePosition(x: 0, y: 0), // Not used in new layout
                            onPositionChange: { _ in } // Not used in new layout
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Class Data Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Search for a player to see their class statistics")
                .foregroundColor(.secondary)
            
            Button {
                Task {
                    await viewModel.forceRefreshStats()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Position Management
    
    private func getPosition(for className: String, in size: CGSize) -> TilePosition {
        if let position = viewModel.tilePositions[className] {
            // Clamp to bounds
            return TilePosition(
                x: max(tileWidth/2 + padding, min(size.width - tileWidth/2 - padding, position.x)),
                y: max(tileHeight/2 + padding, min(size.height - tileHeight/2 - padding, position.y))
            )
        }
        return calculateDefaultPosition(for: className, in: size)
    }
    
    private func calculateDefaultPosition(for className: String, in size: CGSize) -> TilePosition {
        let classes = viewModel.classStats.map { $0.className }
        guard let index = classes.firstIndex(of: className) else {
            return TilePosition(x: size.width / 2, y: size.height / 2)
        }
        
        // 2x2 grid layout
        let columns = 2
        let row = index / columns
        let col = index % columns
        
        let horizontalSpacing = (size.width - tileWidth * 2 - padding * 3) / 2 + tileWidth / 2 + padding
        let verticalSpacing = tileHeight + padding * 2
        
        let x = CGFloat(col) * (tileWidth + padding) + horizontalSpacing
        let y = CGFloat(row) * verticalSpacing + tileHeight / 2 + padding * 2
        
        return TilePosition(x: x, y: y)
    }
    
    private func initializePositions(in size: CGSize) {
        for classStats in viewModel.classStats {
            if viewModel.tilePositions[classStats.className] == nil {
                let position = calculateDefaultPosition(for: classStats.className, in: size)
                viewModel.updateTilePosition(classStats.className, position: position)
            }
        }
    }
    
    private func updatePosition(for className: String, to position: TilePosition, in size: CGSize) {
        // Clamp to bounds
        let clampedPosition = TilePosition(
            x: max(tileWidth/2 + padding, min(size.width - tileWidth/2 - padding, position.x)),
            y: max(tileHeight/2 + padding, min(size.height - tileHeight/2 - padding, position.y))
        )
        viewModel.updateTilePosition(className, position: clampedPosition)
    }
}

// MARK: - Grid Pattern View

struct GridPatternView: View {
    let gridSize: CGFloat = 40
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Vertical lines
                for x in stride(from: 0, through: geometry.size.width, by: gridSize) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                
                // Horizontal lines
                for y in stride(from: 0, through: geometry.size.height, by: gridSize) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Theme.borderColor, lineWidth: 0.5)
        }
    }
}

// MARK: - Reset Layout Button

struct ResetLayoutButton: View {
    @EnvironmentObject var viewModel: StatsViewModel
    
    var body: some View {
        Button {
            withAnimation(.spring()) {
                viewModel.tilePositions.removeAll()
            }
        } label: {
            Label("Reset Layout", systemImage: "arrow.counterclockwise")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    DraggableTileContainer()
        .environmentObject(StatsViewModel())
        .frame(width: 800, height: 600)
        .background(Theme.backgroundPrimary)
}
