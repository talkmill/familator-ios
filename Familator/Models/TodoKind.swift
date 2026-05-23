import Foundation

enum TodoKind: String, CaseIterable, Identifiable {
    case task
    case flight
    case hotel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .task: return "Task"
        case .flight: return "Flight"
        case .hotel: return "Hotel"
        }
    }

    var systemImage: String {
        switch self {
        case .task: return "checkmark.square"
        case .flight: return "airplane"
        case .hotel: return "building.2"
        }
    }
}
