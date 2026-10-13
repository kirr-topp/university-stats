import Foundation

enum ScheduleDateHelper {

    // MARK: - Calendar

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.locale = Locale(identifier: "ru_RU")
        calendar.timeZone = .current
        calendar.firstWeekday = 2

        return calendar
    }()

    // MARK: - Academic year

    static func academicStartDate(
        for date: Date = Date()
    ) -> Date {

        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        let academicYear = month >= 9 ? year : year - 1

        return calendar.date(
            from: DateComponents(
                year: academicYear,
                month: 9,
                day: 2,
                hour: 12
            )
        )!
    }

    // MARK: - Monday

    static func monday(
        of date: Date
    ) -> Date {

        let start = calendar.startOfDay(for: date)

        let weekday = calendar.component(
            .weekday,
            from: start
        )

        let daysFromMonday = (weekday + 5) % 7

        return calendar.date(
            byAdding: .day,
            value: -daysFromMonday,
            to: start
        )!
    }

    static func currentWeekMonday(
        today: Date = Date()
    ) -> Date {
        monday(of: today)
    }

    // MARK: - Week type

    static func weekType(
        for date: Date
    ) -> WeekType {

        let firstMonday = monday(
            of: academicStartDate(
                for: date
            )
        )

        let currentMonday = monday(
            of: date
        )

        let difference =
            calendar.dateComponents(
                [.day],
                from: firstMonday,
                to: currentMonday
            ).day ?? 0

        let weekNumber = difference / 7

        return weekNumber % 2 == 0
            ? .first
            : .second
    }

    // MARK: - Available weeks

    static func availableWeekStarts(
        through latestDate: Date? = nil
    ) -> [Date] {

        let today = Date()

        let firstMonday = monday(
            of: academicStartDate(
                for: today
            )
        )

        let finalDate = max(
            today,
            latestDate ?? today
        )

        let lastMonday = monday(
            of: finalDate
        )

        let difference =
            calendar.dateComponents(
                [.day],
                from: firstMonday,
                to: lastMonday
            ).day ?? 0

        let numberOfWeeks =
            max(
                1,
                difference / 7 + 1
            )

        return (0..<numberOfWeeks).compactMap {
            calendar.date(
                byAdding: .day,
                value: $0 * 7,
                to: firstMonday
            )
        }
    }

    // MARK: - Week range

    static func weekRange(
        starting monday: Date
    ) -> String {

        let sunday = calendar.date(
            byAdding: .day,
            value: 6,
            to: monday
        )!

        let formatter = DateFormatter()

        formatter.locale =
            Locale(identifier: "ru_RU")

        formatter.dateFormat = "d MMMM"

        return "\(formatter.string(from: monday)) – \(formatter.string(from: sunday))"
    }

    // MARK: - Date in week

    static func date(
        for day: DayOfWeek,
        inWeekStarting monday: Date
    ) -> Date {

        calendar.date(
            byAdding: .day,
            value: day.rawValue - 1,
            to: monday
        )!
    }

    // MARK: - Day of week

    static func dayOfWeek(
        for date: Date
    ) -> DayOfWeek {

        switch calendar.component(
            .weekday,
            from: date
        ) {

        case 2:
            return .monday

        case 3:
            return .tuesday

        case 4:
            return .wednesday

        case 5:
            return .thursday

        case 6:
            return .friday

        case 7:
            return .saturday

        default:
            return .sunday
        }
    }

    // MARK: - Date key

    static func dateKey(
        _ date: Date
    ) -> String {

        let formatter = DateFormatter()

        formatter.locale =
            Locale(identifier: "en_US_POSIX")

        formatter.timeZone =
            calendar.timeZone

        formatter.dateFormat =
            "yyyy-MM-dd"

        return formatter.string(
            from: date
        )
    }

    // MARK: - Day and month

    static func dayAndMonth(
        _ date: Date
    ) -> String {

        let formatter = DateFormatter()

        formatter.locale =
            Locale(identifier: "ru_RU")

        formatter.dateFormat =
            "d MMMM"

        return formatter.string(
            from: date
        )
    }

    // MARK: - Lesson date

    static func lessonDate(
        day: Date,
        time: String
    ) -> Date? {

        let components =
            time.split(separator: ":")

        guard
            components.count == 2,
            let hour = Int(components[0]),
            let minute = Int(components[1])
        else {
            return nil
        }

        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day
        )
    }

    // MARK: - Compatibility methods

    static func lessonStartDate(
        day: Date,
        time: String
    ) -> Date? {

        lessonDate(
            day: day,
            time: time
        )
    }

    static func lessonEndDate(
        day: Date,
        time: String
    ) -> Date? {

        lessonDate(
            day: day,
            time: time
        )
    }

    // MARK: - Academic date

    static func isAcademicDate(
        _ date: Date
    ) -> Bool {

        calendar.compare(
            date,
            to: academicStartDate(
                for: date
            ),
            toGranularity: .day
        ) != .orderedAscending
    }

    // MARK: - Countdown

    static func countdownString(
        from seconds: TimeInterval
    ) -> String {

        let total =
            max(
                0,
                Int(seconds)
            )

        let minutes = total / 60
        let seconds = total % 60

        return String(
            format: "%02d:%02d",
            minutes,
            seconds
        )
    }
}
