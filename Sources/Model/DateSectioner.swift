import Foundation

enum HistorySection: Hashable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case month(Date) // start of month

    var title: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .month(let start): return start.formatted(.dateTime.month(.wide).year())
        }
    }
}

/// Classifies dates into history sections. Boundaries are computed once per
/// grouping pass so per-item classification is just Date comparisons.
struct DateSectioner {
    private let calendar: Calendar
    private let startOfToday: Date
    private let startOfYesterday: Date
    private let startOfWeek: Date
    private let startOfLastWeek: Date
    private let startOfMonth: Date

    init(now: Date = .now, calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        startOfToday = calendar.startOfDay(for: now)
        startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek) ?? startOfWeek
        startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
    }

    func section(for date: Date) -> HistorySection {
        // Yesterday must win over This Week (it is usually both).
        if date >= startOfToday { return .today }
        if date >= startOfYesterday { return .yesterday }
        if date >= startOfWeek { return .thisWeek }
        if date >= startOfLastWeek { return .lastWeek }
        if date >= startOfMonth { return .thisMonth }
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? date
        return .month(monthStart)
    }
}
