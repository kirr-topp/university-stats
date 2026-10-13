import Foundation

// MARK: - Lesson kind

enum LessonKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case lecture
    case practice
    case laboratory
    case other

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .lecture:
            return "Лекция"

        case .practice:
            return "Практика"

        case .laboratory:
            return "Лабораторная"

        case .other:
            return "Занятие"
        }
    }

    var displayTitle: String {
        title
    }
}

// MARK: - Week type

enum WeekType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case first
    case second

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .first:
            return "Первая неделя"

        case .second:
            return "Вторая неделя"
        }
    }
}

// MARK: - Day of week

enum DayOfWeek: Int, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .monday:
            return "Понедельник"

        case .tuesday:
            return "Вторник"

        case .wednesday:
            return "Среда"

        case .thursday:
            return "Четверг"

        case .friday:
            return "Пятница"

        case .saturday:
            return "Суббота"

        case .sunday:
            return "Воскресенье"
        }
    }

    var shortTitle: String {
        switch self {
        case .monday:
            return "Пн"

        case .tuesday:
            return "Вт"

        case .wednesday:
            return "Ср"

        case .thursday:
            return "Чт"

        case .friday:
            return "Пт"

        case .saturday:
            return "Сб"

        case .sunday:
            return "Вс"
        }
    }
}

// MARK: - Lesson

struct Lesson: Identifiable, Codable, Hashable, Sendable {

    let id: String

    let number: Int

    let name: String

    let teacher: String

    let room: String

    let startTime: String

    let endTime: String

    let subgroup: Int?

    let group: String?

    let kind: LessonKind

    init(
        id: String? = nil,
        number: Int,
        name: String,
        teacher: String,
        room: String,
        startTime: String,
        endTime: String,
        subgroup: Int? = nil,
        group: String? = nil,
        kind: LessonKind = .other
    ) {
        self.number = number
        self.name = name
        self.teacher = teacher
        self.room = room
        self.startTime = startTime
        self.endTime = endTime
        self.subgroup = subgroup
        self.group = group
        self.kind = kind

        self.id =
            id
            ?? Lesson.makeID(
                name: name,
                number: number,
                startTime: startTime,
                endTime: endTime,
                subgroup: subgroup,
                group: group,
                kind: kind
            )
    }

    private static func makeID(
        name: String,
        number: Int,
        startTime: String,
        endTime: String,
        subgroup: Int?,
        group: String?,
        kind: LessonKind
    ) -> String {

        [
            name,
            "\(number)",
            startTime,
            endTime,
            "\(subgroup ?? 0)",
            group ?? "",
            kind.rawValue
        ]
        .joined(separator: "|")
    }
}

// MARK: - Schedule day

struct ScheduleDay: Identifiable, Codable, Hashable, Sendable {

    let date: Date

    var lessons: [Lesson]

    var id: String {
        ScheduleDateHelper.dateKey(date)
    }

    var dayOfWeek: DayOfWeek {
        ScheduleDateHelper.dayOfWeek(
            for: date
        )
    }

    init(
        date: Date,
        lessons: [Lesson]
    ) {
        self.date = date
        self.lessons = lessons
    }
}

// MARK: - Complete schedule

struct UniversitySchedule: Codable, Hashable, Sendable {

    var days: [ScheduleDay]

    init(
        days: [ScheduleDay] = []
    ) {
        self.days = days.sorted {
            $0.date < $1.date
        }
    }

    var latestDate: Date? {
        days.map(\.date).max()
    }

    var earliestDate: Date? {
        days.map(\.date).min()
    }

    func day(
        on date: Date
    ) -> ScheduleDay? {

        let key =
            ScheduleDateHelper.dateKey(
                date
            )

        return days.first {
            $0.id == key
        }
    }

    func days(
        from start: Date,
        to end: Date
    ) -> [ScheduleDay] {

        days.filter {
            $0.date >= start &&
            $0.date <= end
        }
    }

    func subjects() -> [String] {

        Set(
            days.flatMap { day in
                day.lessons.map(\.name)
            }
        )
        .sorted()
    }

    func merging(
        _ imported: UniversitySchedule
    ) -> UniversitySchedule {

        var byDate:
            [String: ScheduleDay] = [:]

        for day in days {
            byDate[day.id] = day
        }

        for day in imported.days {
            byDate[day.id] = day
        }

        return UniversitySchedule(
            days:
                byDate.values.sorted {
                    $0.date < $1.date
                }
        )
    }
}
