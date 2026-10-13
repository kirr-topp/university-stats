import Foundation
import Combine

enum AttendanceStatus: String, Codable, Hashable, Sendable {
    case attended
    case absent
}

struct AttendanceStatistics: Codable, Hashable, Sendable {
    let total: Int
    let attended: Int
    let absent: Int

    var percentage: Int {
        guard total > 0 else { return 0 }
        return Int((Double(attended) / Double(total) * 100).rounded())
    }
}

private struct AttendanceRecord: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let lessonID: String
    let subject: String
    let kind: LessonKind
    let date: Date
    let status: AttendanceStatus
}

@MainActor
final class AttendanceStore: ObservableObject {
    @Published private var records: [String: AttendanceRecord] = [:]

    private let fileManager = FileManager.default

    private var fileURL: URL {
        let directory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        let appDirectory = directory.appendingPathComponent(
            "UniversityStats",
            isDirectory: true
        )

        try? fileManager.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true
        )

        return appDirectory.appendingPathComponent("attendance_v2.json")
    }

    init() {
        load()
    }

    private func key(lesson: Lesson, date: Date) -> String {
        "\(ScheduleDateHelper.dateKey(date))|\(lesson.id)"
    }

    func status(for lesson: Lesson, on date: Date) -> AttendanceStatus? {
        records[key(lesson: lesson, date: date)]?.status
    }

    func setStatus(
        _ status: AttendanceStatus,
        for lesson: Lesson,
        on date: Date
    ) {
        let record = AttendanceRecord(
            id: key(lesson: lesson, date: date),
            lessonID: lesson.id,
            subject: lesson.name,
            kind: lesson.kind,
            date: date,
            status: status
        )

        records[record.id] = record
        save()
    }

    // Удаляет именно отметку посещаемости, не трогая расписание.
    func deleteStatus(for lesson: Lesson, on date: Date) {
        records.removeValue(
            forKey: key(lesson: lesson, date: date)
        )
        save()
    }

    func statistics(for subject: String) -> AttendanceStatistics {
        let filtered = records.values.filter { $0.subject == subject }
        let attended = filtered.lazy.filter { $0.status == .attended }.count
        let absent = filtered.lazy.filter { $0.status == .absent }.count

        return AttendanceStatistics(
            total: filtered.count,
            attended: attended,
            absent: absent
        )
    }

    func statistics(
        for subject: String,
        kind: LessonKind
    ) -> AttendanceStatistics {
        let filtered = records.values.filter {
            $0.subject == subject && $0.kind == kind
        }

        let attended = filtered.lazy.filter { $0.status == .attended }.count
        let absent = filtered.lazy.filter { $0.status == .absent }.count

        return AttendanceStatistics(
            total: filtered.count,
            attended: attended,
            absent: absent
        )
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Array(records.values))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Ошибка сохранения посещаемости:", error)
        }
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(
                [AttendanceRecord].self,
                from: data
            )

            records = Dictionary(
                uniqueKeysWithValues: decoded.map {
                    ($0.id, $0)
                }
            )
        } catch {
            print("Ошибка загрузки посещаемости:", error)
            records = [:]
        }
    }
}
