//
//  ContentView.swift
//  OptimalPath
//
//  Created by Michael Wheeler on 2025-10-13.
//

import SwiftUI
import Combine
import Foundation

@MainActor
class GridViewModel: ObservableObject {
    @Published var grid: Grid
    @Published var start: Cell? = nil
    @Published var goal: Cell? = nil
    @Published var path: [Cell] = []
    
    init(width: Int, height: Int) {
        self.grid = Grid(width: width, height: height)
    }
    
    func toggleWall(at cell: Cell) {
        if grid.walls.contains(cell) {
            grid.walls.remove(cell)
        } else {
            grid.walls.insert(cell)
        }
    }
    
    func runAStar() {
        guard let start = start, let goal = goal else { return }
        if let newPath = AStar(grid: grid, start: start, goal: goal) {
            self.path = newPath
        } else {
            self.path = []
        }
    }
    
    func clearCanvas() {
        self.grid.walls.removeAll()
        self.start = nil
        self.goal = nil
        self.path.removeAll()
    }
}


struct Cell: Hashable {
    let x: Int, y: Int
    var isWalkable: Bool = true
}

struct Grid {
    let width: Int, height: Int
    
    var walls: Set<Cell> = []
    
    func isValid(_ cell: Cell) -> Bool {
        return cell.x >= 0 && cell.x < width && cell.y >= 0 && cell.y < height && !walls.contains(cell) && (!walls.contains(Cell(x: cell.x, y: cell.y - 1)) || !walls.contains(Cell(x: cell.x - 1, y: cell.y)))
    }
    func getNeighbours(of cell: Cell) -> [Cell]? {
        var neighbours: [Cell] = []
        let directions: [(Int, Int)] = [(-1, 0),
                                        (1, 0),
                                        (0, -1),
                                        (0, 1),
                                        (-1, 1),
                                        (1, -1),
                                        (-1, -1),
                                        (1, 1)]
        for direction in directions {
            if isValid(Cell(x: cell.x + direction.0, y: cell.y + direction.1)) {
                neighbours.append(Cell(x: cell.x + direction.0, y: cell.y + direction.1))
            }
        }
        if neighbours.isEmpty {
            return nil
        }
        return neighbours
    }
}

func heuristic (from: Cell, to: Cell) -> Double {
    let dx = Double(from.x - to.x)
    let dy = Double(from.y - to.y)
    // sqrt(2) - diagonal cost, 1 - horizontal/vertical cost
    return dx + dy + (sqrt(2) - 2) * min(dx, dy)
}
func reconstructPath(cameFrom: [Cell: Cell], start: Cell, goal: Cell) -> [Cell] {
    var path: [Cell] = []
    var current = goal
    
    // Step backward from goal to start
    while current != start {
        path.append(current)
        guard let parent = cameFrom[current] else {
            // No path found
            return []
        }
        current = parent
    }
    
    // Finally add the start cell
    path.append(start)
    
    // Reverse to get path from start → goal
    return path.reversed()
}

func AStar (grid: Grid, start: Cell, goal: Cell) -> [Cell]? {
    var openSet: [Cell] = []
    openSet.append(start)
    
    var cameFrom: [Cell: Cell] = [:]
    
    var gScore: [Cell: Double] = [:]
    gScore[start] = 0.0
    
    var fScore: [Cell: Double] = [:]
    fScore[start] = heuristic(from: start, to: goal)
    
    
    let D1: Double = 1.0
    let D2: Double = sqrt(2.0)
    while !openSet.isEmpty {
        guard let current = openSet.min(by: { (a, b) in
                (fScore[a] ?? Double.infinity) < (fScore[b] ?? Double.infinity)
            }) else {
                break
            }
        if current == goal {
            return reconstructPath(cameFrom: cameFrom, start: start, goal: goal)
        }
        openSet.remove(at: openSet.firstIndex(of: current)!)
        
        guard let neighbors = grid.getNeighbours(of: current) else { continue }
        
        for neighbour in neighbors {
            let moveScore: Double
            
            if current.x != neighbour.x && current.y != neighbour.y {
                moveScore = D2
            } else {
                moveScore = D1
            }
            
            let tentativeG = (gScore[current] ?? Double.infinity) + moveScore
            
            if tentativeG < (gScore[neighbour] ?? Double.infinity) {
                cameFrom[neighbour] = current
                gScore[neighbour] = tentativeG
                fScore[neighbour] = tentativeG + heuristic(from: neighbour, to: goal)
                if !openSet.contains(neighbour) {
                    openSet.append(neighbour)
                }
            }
        }
    }
    return nil
}

struct ContentView: View {
    @StateObject private var viewModel = GridViewModel(width: 10, height: 10)
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach((0..<viewModel.grid.height).reversed(), id: \.self) { y in
                HStack(spacing: 2) {
                    ForEach(0..<viewModel.grid.width, id: \.self) { x in
                        let cell = Cell(x: x, y: y)
                        Rectangle()
                            .fill(color(for: cell))
                            .frame(width: 30, height: 30)
                            .onTapGesture {
                                handleTap(on: cell)
                            }
                            .animation(.easeInOut(duration: 0.3), value: viewModel.path)

                    }
                }
            }
            .padding(.bottom, 2)
            
            Button("Run A*") {
                viewModel.runAStar()
            }
            .padding()
            Button("Clear") {
                viewModel.clearCanvas()
            }
            .padding()
        }
    }
    
    private func handleTap(on cell: Cell) {
        // Tap order: set start, then goal, then toggle walls
        if viewModel.start == nil {
            viewModel.start = cell
        } else if viewModel.goal == nil {
            viewModel.goal = cell
        } else {
            viewModel.toggleWall(at: cell)
        }
    }
    
    private func color(for cell: Cell) -> Color {
        if cell == viewModel.start {
            return .blue
        } else if cell == viewModel.goal {
            return .red
        } else if viewModel.path.contains(cell) {
            return .green
        } else if viewModel.grid.walls.contains(cell) {
            return .black
        } else {
            return .gray.opacity(0.3)
        }
    }
}


#Preview {
    ContentView()
}
