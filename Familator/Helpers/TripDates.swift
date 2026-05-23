import Foundation

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

private func parseLocalDate(_ dateStr: String) -> Date? {
    dateFormatter.date(from: dateStr)
}

private func formatSingleDate(_ dateStr: String) -> String {
    guard let date = parseLocalDate(dateStr) else { return dateStr }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US")
    f.dateFormat = "MMM d, yyyy"
    return f.string(from: date)
}

/// Formats a trip date range for display.
/// - Same day: "May 5, 2026"
/// - Same month: "May 5 – 15, 2026"
/// - Different months/years: "May 25, 2026 – Jun 5, 2026"
/// - Only start: "May 5, 2026 –"
/// - Only end: "– May 5, 2026"
/// - Neither: ""
func formatTripDateRange(startDate: String?, endDate: String?) -> String {
    if startDate == nil && endDate == nil { return "" }
    if let startDate, endDate == nil { return "\(formatSingleDate(startDate)) –" }
    if startDate == nil, let endDate { return "– \(formatSingleDate(endDate))" }

    let startStr = startDate!
    let endStr = endDate!
    guard let start = parseLocalDate(startStr), let end = parseLocalDate(endStr) else {
        return "\(formatSingleDate(startStr)) – \(formatSingleDate(endStr))"
    }

    let cal = Calendar(identifier: .gregorian)
    let startComps = cal.dateComponents([.year, .month, .day], from: start)
    let endComps = cal.dateComponents([.year, .month, .day], from: end)

    if startComps.year == endComps.year && startComps.month == endComps.month && startComps.day == endComps.day {
        return formatSingleDate(startStr)
    }

    if startComps.year == endComps.year && startComps.month == endComps.month {
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_US")
        monthFormatter.dateFormat = "MMM"
        let monthName = monthFormatter.string(from: start)
        return "\(monthName) \(startComps.day!) – \(endComps.day!), \(endComps.year!)"
    }

    return "\(formatSingleDate(startStr)) – \(formatSingleDate(endStr))"
}

/// Returns the number of nights between two dates, or nil if either is missing.
func computeNights(startDate: String?, endDate: String?) -> Int? {
    guard let startDate, let endDate,
          let start = parseLocalDate(startDate),
          let end = parseLocalDate(endDate) else { return nil }
    let seconds = end.timeIntervalSince(start)
    return max(0, Int(round(seconds / 86_400)))
}
