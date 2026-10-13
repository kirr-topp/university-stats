import Foundation
import Combine

@MainActor
final class ScheduleStore: ObservableObject {

    @Published private(set) var schedule:
        UniversitySchedule

    private let fileManager =
        FileManager.default

    private var fileURL: URL {

        let directory =
            fileManager.urls(
                for:
                    .applicationSupportDirectory,
                in:
                    .userDomainMask
            )[0]

        let appDirectory =
            directory.appendingPathComponent(
                "UniversityStats",
                isDirectory:
                    true
            )

        try? fileManager.createDirectory(
            at:
                appDirectory,
            withIntermediateDirectories:
                true
        )

        return appDirectory
            .appendingPathComponent(
                "schedule_v2.json"
            )
    }

    init() {

        schedule =
            UniversitySchedule()

        load()
    }

    // MARK: - Save

    func save(
        _ schedule:
            UniversitySchedule
    ) {

        do {

            let encoder =
                JSONEncoder()

            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys
            ]

            let data =
                try encoder.encode(
                    schedule
                )

            try data.write(
                to:
                    fileURL,
                options:
                    .atomic
            )

            self.schedule =
                schedule

        } catch {

            print(
                "Ошибка сохранения расписания:",
                error
            )
        }
    }

    // MARK: - Merge

    func merge(
        _ imported:
            UniversitySchedule
    ) {

        let merged =
            schedule.merging(
                imported
            )

        save(
            merged
        )
    }

    // MARK: - Load

    func load() {

        guard
            fileManager.fileExists(
                atPath:
                    fileURL.path
            )
        else {
            return
        }

        do {

            let data =
                try Data(
                    contentsOf:
                        fileURL
                )

            let decoder =
                JSONDecoder()

            schedule =
                try decoder.decode(
                    UniversitySchedule.self,
                    from:
                        data
                )

        } catch {

            print(
                "Ошибка загрузки нового расписания:",
                error
            )

            schedule =
                UniversitySchedule()
        }
    }

    // MARK: - Delete

    func deleteSchedule() {

        do {

            if fileManager.fileExists(
                atPath:
                    fileURL.path
            ) {

                try fileManager.removeItem(
                    at:
                        fileURL
                )
            }

            schedule =
                UniversitySchedule()

        } catch {

            print(
                "Ошибка удаления расписания:",
                error
            )
        }
    }

    // MARK: - Information

    var dayCount: Int {
        schedule.days.count
    }

    var latestDate: Date? {
        schedule.latestDate
    }
}
