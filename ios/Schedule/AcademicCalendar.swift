import Foundation

enum AcademicCalendar {

    // MARK: - Settings

    /// Контрольная проводится каждую 7-ю неделю.
    /// При стандартном семестре получаем КН-1 и КН-2.
    static let controlWeekNumbers = [7, 14]

    /// Время уведомлений.
    static let notificationHour = 9
    static let notificationMinute = 0

    // MARK: - Academic year

    /// Возвращает год начала учебного года.
    ///
    /// Например:
    /// октябрь 2026 -> 2026
    /// январь 2027 -> 2026
    /// март 2027 -> 2026
    static func academicYearStart(
        for date: Date = Date()
    ) -> Int {

        let calendar = ScheduleDateHelper.calendar

        let year =
            calendar.component(
                .year,
                from: date
            )

        let month =
            calendar.component(
                .month,
                from: date
            )

        return month >= 8
            ? year
            : year - 1
    }

    // MARK: - Semester

    /// Первый день первого семестра.
    static func firstSemesterStart(
        academicYear: Int
    ) -> Date {

        makeDate(
            year: academicYear,
            month: 9,
            day: 1
        )
    }

    /// Первый день второго семестра.
    static func secondSemesterStart(
        academicYear: Int
    ) -> Date {

        makeDate(
            year: academicYear + 1,
            month: 2,
            day: 1
        )
    }

    /// Понедельник недели, в которую попадает дата.
    static func monday(
        containing date: Date
    ) -> Date {

        ScheduleDateHelper.monday(
            of: date
        )
    }

    // MARK: - Control weeks

    /// Возвращает все контрольные недели
    /// за один учебный год.
    static func controlWeeks(
        academicYear: Int
    ) -> [ControlWeek] {

        let semesters: [
            (
                semester: Int,
                start: Date
            )
        ] = [
            (
                1,
                firstSemesterStart(
                    academicYear:
                        academicYear
                )
            ),
            (
                2,
                secondSemesterStart(
                    academicYear:
                        academicYear
                )
            )
        ]

        var result: [ControlWeek] = []

        for semester in semesters {

            let firstMonday =
                monday(
                    containing:
                        semester.start
                )

            for weekNumber
                in controlWeekNumbers {

                let offset =
                    (weekNumber - 1) * 7

                guard
                    let date =
                        ScheduleDateHelper
                            .calendar
                            .date(
                                byAdding:
                                    .day,
                                value:
                                    offset,
                                to:
                                    firstMonday
                            )
                else {
                    continue
                }

                result.append(
                    ControlWeek(
                        semester:
                            semester.semester,
                        number:
                            controlWeekNumber(
                                semester:
                                    semester.semester,
                                weekNumber:
                                    weekNumber
                            ),
                        semesterWeek:
                            weekNumber,
                        startDate:
                            date
                    )
                )
            }
        }

        return result.sorted {
            $0.startDate < $1.startDate
        }
    }

    private static func controlWeekNumber(
        semester: Int,
        weekNumber: Int
    ) -> Int {

        if semester == 1 {
            return weekNumber == 7
                ? 1
                : 2
        }

        return weekNumber == 7
            ? 3
            : 4
    }

    // MARK: - Sessions

    static var sessions:
        [AcademicSession] {

        [
            AcademicSession(
                number: 1,
                title: "Сессия 1",
                period: "Декабрь — январь"
            ),

            AcademicSession(
                number: 2,
                title: "Сессия 2",
                period: "Июнь"
            )
        ]
    }

    // MARK: - Helpers

    private static func makeDate(
        year: Int,
        month: Int,
        day: Int
    ) -> Date {

        var components =
            DateComponents()

        components.calendar =
            ScheduleDateHelper.calendar

        components.year =
            year

        components.month =
            month

        components.day =
            day

        components.hour =
            12

        return
            ScheduleDateHelper
                .calendar
                .date(
                    from:
                        components
                )
            ?? Date()
    }
}

// MARK: - Control Week

struct ControlWeek:
    Identifiable,
    Hashable,
    Sendable {

    let semester: Int
    let number: Int
    let semesterWeek: Int
    let startDate: Date

    var id: String {
        "control-\(number)"
    }

    var title: String {
        "Контрольная неделя \(number)"
    }

    var shortTitle: String {
        "КН-\(number)"
    }
}

// MARK: - Session

struct AcademicSession:
    Identifiable,
    Hashable,
    Sendable {

    let number: Int
    let title: String
    let period: String

    var id: Int {
        number
    }
}
