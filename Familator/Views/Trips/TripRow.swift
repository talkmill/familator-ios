import SwiftUI

struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.destination)
                    .font(.body)
                if let dateRange = formattedDateRange {
                    Text(dateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            StatusBadge(status: trip.status)
        }
    }

    private var formattedDateRange: String? {
        guard let start = trip.startDate else { return nil }
        if let end = trip.endDate {
            return "\(formatDate(start)) – \(formatDate(end))"
        }
        return formatDate(start)
    }

    private static let isoParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private func formatDate(_ isoDate: String) -> String {
        guard let date = Self.isoParser.date(from: isoDate) else { return isoDate }
        return Self.displayFormatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: TripStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor.opacity(0.15))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .inProgress: return .green
        case .upcoming: return .blue
        case .planning: return .orange
        case .past: return .gray
        }
    }
}
