import Foundation
import UserNotifications

@MainActor
final class AcademicNotificationManager {

    static let shared =
        AcademicNotificationManager()

    private let center =
        UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Public

    func requestPermissionAndSchedule() async {

        do {

            let granted =
                try await center
                    .requestAuthorization(
                        options:
                            [
                                .alert,
                                .sound,
                                .badge
                            ]
                    )

            guard granted else {
                return
            }

            await scheduleControlWeekNotifications()

        } catch {

            print(
                "Ошибка разрешения уведомлений:",
                error
            )
        }
    }

    // MARK: - Schedule

    private func scheduleControlWeekNotifications()
        async {

        let academicYear =
            AcademicCalendar
                .academicYearStart()

        let controlWeeks =
            AcademicCalendar.controlWeeks(
                academicYear:
                    academicYear
            )

        let oldRequests =
            await center
                .pendingNotificationRequests()

        let oldIDs =
            oldRequests
                .map(\.identifier)
                .filter {
                    $0.hasPrefix(
                        "universitystats.controlweek."
                    )
                }

        if !oldIDs.isEmpty {

            center
                .removePendingNotificationRequests(
                    withIdentifiers:
                        oldIDs
                )
        }

        let now =
            Date()

        for week in controlWeeks {

            let startDate =
                notificationDate(
                    for:
                        week.startDate
                )

            let reminderDate =
                Calendar.current.date(
                    byAdding:
                        .day,
                    value:
                        -7,
                    to:
                        startDate
                )

            if let reminderDate,
               reminderDate > now {

                await addNotification(
                    id:
                        "universitystats.controlweek.\(week.number).weekbefore",
                    date:
                        reminderDate,
                    title:
                        "Контрольная неделя через неделю",
                    body:
                        "\(week.title) начнётся \(formattedDate(week.startDate))."
                )
            }

            if startDate > now {

                await addNotification(
                    id:
                        "universitystats.controlweek.\(week.number).start",
                    date:
                        startDate,
                    title:
                        "Началась контрольная неделя",
                    body:
                        "\(week.title). Это \(week.semesterWeek)-я неделя \(week.semester)-го семестра."
                )
            }
        }
    }

    // MARK: - Add notification

    private func addNotification(
        id:
            String,
        date:
            Date,
        title:
            String,
        body:
            String
    ) async {

        let content =
            UNMutableNotificationContent()

        content.title =
            title

        content.body =
            body

        content.sound =
            .default

        var components =
            Calendar.current
                .dateComponents(
                    [
                        .year,
                        .month,
                        .day,
                        .hour,
                        .minute
                    ],
                    from:
                        date
                )

        components.timeZone =
            TimeZone.current

        let trigger =
            UNCalendarNotificationTrigger(
                dateMatching:
                    components,
                repeats:
                    false
            )

        let request =
            UNNotificationRequest(
                identifier:
                    id,
                content:
                    content,
                trigger:
                    trigger
            )

        do {

            try await center.add(
                request
            )

        } catch {

            print(
                "Ошибка добавления уведомления:",
                error
            )
        }
    }

    // MARK: - Helpers

    private func notificationDate(
        for date:
            Date
    ) -> Date {

        var components =
            Calendar.current
                .dateComponents(
                    [
                        .year,
                        .month,
                        .day
                    ],
                    from:
                        date
                )

        components.hour =
            AcademicCalendar
                .notificationHour

        components.minute =
            AcademicCalendar
                .notificationMinute

        components.second =
            0

        return
            Calendar.current
                .date(
                    from:
                        components
                )
            ?? date
    }

    private func formattedDate(
        _ date:
            Date
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "ru_RU"
            )

        formatter.dateFormat =
            "d MMMM"

        return formatter.string(
            from:
                date
        )
    }
}
