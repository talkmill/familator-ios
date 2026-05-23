import Foundation

/// Stored JSON for `todos.recurrence` (v1), aligned with `lib/recurrence.ts`.
struct TodoRecurrenceJSON: Equatable {
    var v: Int
    var mode: String
    var wait: Wait?
    var calendar: CalendarBody?

    struct Wait: Codable, Equatable {
        var value: Int
        var unit: String
    }

    struct CalendarBody: Codable, Equatable {
        var kind: String
        var granularity: String?
        var every: Int?
        var weekday: Int?
        var day: Int?
    }
}

extension TodoRecurrenceJSON: Codable {
    enum CodingKeys: String, CodingKey {
        case v, mode, wait, calendar
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        v = try c.decodeIfPresent(Int.self, forKey: .v) ?? 0
        mode = try c.decodeIfPresent(String.self, forKey: .mode) ?? ""
        wait = try c.decodeIfPresent(Wait.self, forKey: .wait)
        calendar = try c.decodeIfPresent(CalendarBody.self, forKey: .calendar)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(v, forKey: .v)
        try c.encode(mode, forKey: .mode)
        if mode == "after_completion", let wait {
            try c.encode(wait, forKey: .wait)
        } else if mode == "calendar", let calendar {
            try c.encode(calendar, forKey: .calendar)
        }
    }
}

extension TodoRecurrenceJSON {
    /// Mirrors `parseRecurrence` validity (enough for UI and filters).
    var isValidRule: Bool {
        guard v == 1 else { return false }
        if mode == "after_completion" {
            guard let w = wait else { return false }
            guard w.value >= 1, ["days", "weeks", "months"].contains(w.unit) else { return false }
            return true
        }
        if mode == "calendar", let cal = calendar {
            return Self.isValidCalendar(cal)
        }
        return false
    }

    private static func isValidCalendar(_ cal: CalendarBody) -> Bool {
        switch cal.kind {
        case "fixed_interval":
            guard let g = cal.granularity, let e = cal.every, e >= 1 else { return false }
            return ["day", "week", "month", "year"].contains(g)
        case "weekly_on_weekday":
            guard let w = cal.weekday, let e = cal.every, e >= 1 else { return false }
            return w >= 0 && w <= 6
        case "monthly_on_day":
            guard let d = cal.day, let e = cal.every, d >= 1, d <= 31, e >= 1 else { return false }
            return true
        default:
            return false
        }
    }

    /// Mirrors `formatRecurrenceSummary` from `lib/recurrence.ts`.
    func summaryLabel() -> String? {
        guard isValidRule else { return nil }
        if mode == "after_completion", let w = wait {
            let u = w.unit == "days" ? "day" : w.unit == "weeks" ? "week" : "month"
            let plural = w.value > 1 ? "s" : ""
            return "Again in \(w.value) \(u)\(plural) after done"
        }
        guard mode == "calendar", let c = calendar else { return "Repeats" }
        switch c.kind {
        case "fixed_interval":
            let g: String
            switch c.granularity {
            case "day": g = "day"
            case "week": g = "week"
            case "month": g = "month"
            case "year": g = "year"
            default: g = "week"
            }
            let n = c.every ?? 1
            return "Every \(n) \(g)\(n > 1 ? "s" : "")"
        case "weekly_on_weekday":
            let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let w = c.weekday.flatMap { names.indices.contains($0) ? names[$0] : nil } ?? "?"
            let ev = c.every ?? 1
            return ev == 1 ? "Every \(w)" : "Every \(ev) wk on \(w)"
        case "monthly_on_day":
            let d = c.day ?? 1
            let ev = c.every ?? 1
            return ev == 1 ? "Monthly on day \(d)" : "Every \(ev) mo on day \(d)"
        default:
            return "Repeats"
        }
    }
}

/// Form state for editing recurrence (aligned with `recurrenceFormDefaults` / `buildRecurrencePayload` on web).
struct RecurrenceEditForm: Equatable {
    var repeatEnabled: Bool
    /// `true` = after completion, `false` = calendar schedule.
    var scheduleAfterCompletion: Bool
    var waitValue: Int
    var waitUnit: String
    var calEvery: Int
    var calGranularity: String
    /// When granularity is week: `false` = fixed interval week(s), `true` = weekly on weekday.
    var useSpecificWeekday: Bool
    var weekday: Int
    var monthlyDay: Int
    var monthlyEvery: Int
    var recPaused: Bool

    init(todo: Todo) {
        let r = todo.recurrence
        recPaused = todo.recurrencePaused ?? false
        if let r, r.isValidRule {
            repeatEnabled = true
            if r.mode == "after_completion", let w = r.wait {
                scheduleAfterCompletion = true
                waitValue = max(1, w.value)
                waitUnit = w.unit
                calEvery = 1
                calGranularity = "week"
                useSpecificWeekday = false
                weekday = 0
                monthlyDay = 1
                monthlyEvery = 1
                return
            }
            if r.mode == "calendar", let c = r.calendar {
                scheduleAfterCompletion = false
                waitValue = 1
                waitUnit = "weeks"
                switch c.kind {
                case "fixed_interval":
                    calEvery = max(1, c.every ?? 1)
                    calGranularity = c.granularity ?? "week"
                    useSpecificWeekday = false
                    weekday = 0
                    monthlyDay = 1
                    monthlyEvery = 1
                case "weekly_on_weekday":
                    calEvery = max(1, c.every ?? 1)
                    calGranularity = "week"
                    useSpecificWeekday = true
                    weekday = min(6, max(0, c.weekday ?? 0))
                    monthlyDay = 1
                    monthlyEvery = 1
                case "monthly_on_day":
                    calEvery = 1
                    calGranularity = "month"
                    useSpecificWeekday = false
                    weekday = 0
                    monthlyDay = min(31, max(1, c.day ?? 1))
                    monthlyEvery = max(1, c.every ?? 1)
                default:
                    calEvery = 1
                    calGranularity = "week"
                    useSpecificWeekday = false
                    weekday = 0
                    monthlyDay = 1
                    monthlyEvery = 1
                }
                return
            }
        }
        repeatEnabled = false
        scheduleAfterCompletion = false
        waitValue = 1
        waitUnit = "weeks"
        calEvery = 1
        calGranularity = "week"
        useSpecificWeekday = false
        weekday = 0
        monthlyDay = 1
        monthlyEvery = 1
    }

    func buildRecurrenceJSON() -> TodoRecurrenceJSON? {
        guard repeatEnabled else { return nil }
        if scheduleAfterCompletion {
            let value = max(1, waitValue)
            let unit = ["days", "weeks", "months"].contains(waitUnit) ? waitUnit : "weeks"
            return TodoRecurrenceJSON(
                v: 1,
                mode: "after_completion",
                wait: .init(value: value, unit: unit),
                calendar: nil
            )
        }
        let every = max(1, calEvery)
        if calGranularity == "week", useSpecificWeekday {
            let wd = min(6, max(0, weekday))
            return TodoRecurrenceJSON(
                v: 1,
                mode: "calendar",
                wait: nil,
                calendar: .init(kind: "weekly_on_weekday", granularity: nil, every: every, weekday: wd, day: nil)
            )
        }
        if calGranularity == "month" {
            let day = min(31, max(1, monthlyDay))
            let me = max(1, monthlyEvery)
            return TodoRecurrenceJSON(
                v: 1,
                mode: "calendar",
                wait: nil,
                calendar: .init(kind: "monthly_on_day", granularity: nil, every: me, weekday: nil, day: day)
            )
        }
        let g = ["day", "week", "month", "year"].contains(calGranularity) ? calGranularity : "week"
        return TodoRecurrenceJSON(
            v: 1,
            mode: "calendar",
            wait: nil,
            calendar: .init(kind: "fixed_interval", granularity: g, every: every, weekday: nil, day: nil)
        )
    }
}
