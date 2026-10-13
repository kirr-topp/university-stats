import Foundation
import Combine

struct PointRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let subject: String
    let kind: LessonKind
    let points: Double
    let date: Date
    let comment: String

    init(
        id: UUID = UUID(),
        subject: String,
        kind: LessonKind,
        points: Double,
        date: Date,
        comment: String
    ) {
        self.id = id
        self.subject = subject
        self.kind = kind
        self.points = points
        self.date = date
        self.comment = comment
    }
}

@MainActor
final class PointsStore: ObservableObject {
    @Published private(set) var records: [PointRecord] = []
    @Published private(set) var autoConditions: [String: String] = [:]
    @Published private(set) var autoThresholds: [String: Double] = [:]

    private let fileManager = FileManager.default

    private var directoryURL: URL {
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

        return appDirectory
    }

    private var recordsURL: URL {
        directoryURL.appendingPathComponent("points.json")
    }

    private var conditionsURL: URL {
        directoryURL.appendingPathComponent("auto_conditions.json")
    }

    private var thresholdsURL: URL {
        directoryURL.appendingPathComponent("auto_thresholds.json")
    }

    init() {
        load()
    }

    func addRecord(
        subject: String,
        kind: LessonKind,
        points: Double,
        date: Date,
        comment: String
    ) {
        let cleanedComment = comment.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        records.append(
            PointRecord(
                subject: subject,
                kind: kind,
                points: points,
                date: date,
                comment: cleanedComment
            )
        )

        records.sort { $0.date > $1.date }
        saveRecords()
    }

    func deleteRecord(_ record: PointRecord) {
        records.removeAll { $0.id == record.id }
        saveRecords()
    }

    func records(for subject: String) -> [PointRecord] {
        records
            .filter { $0.subject == subject }
            .sorted { $0.date > $1.date }
    }

    func total(for subject: String) -> Double {
        records.lazy
            .filter { $0.subject == subject }
            .reduce(0) { $0 + $1.points }
    }

    func total(for subject: String, kind: LessonKind) -> Double {
        records.lazy
            .filter {
                $0.subject == subject && $0.kind == kind
            }
            .reduce(0) { $0 + $1.points }
    }

    func condition(for subject: String) -> String {
        autoConditions[subject] ?? ""
    }

    func setCondition(_ condition: String, for subject: String) {
        let cleaned = condition.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if cleaned.isEmpty {
            autoConditions.removeValue(forKey: subject)
        } else {
            autoConditions[subject] = cleaned
        }

        saveConditions()
    }

    func autoThreshold(for subject: String) -> Double? {
        autoThresholds[subject]
    }

    func setAutoThreshold(_ value: Double?, for subject: String) {
        if let value, value >= 0 {
            autoThresholds[subject] = value
        } else {
            autoThresholds.removeValue(forKey: subject)
        }

        saveThresholds()
    }

    private func saveRecords() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(records)
            try data.write(to: recordsURL, options: .atomic)
        } catch {
            print("Ошибка сохранения баллов:", error)
        }
    }

    private func saveConditions() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(autoConditions)
            try data.write(to: conditionsURL, options: .atomic)
        } catch {
            print("Ошибка сохранения условий автомата:", error)
        }
    }

    private func saveThresholds() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(autoThresholds)
            try data.write(to: thresholdsURL, options: .atomic)
        } catch {
            print("Ошибка сохранения количества баллов для автомата:", error)
        }
    }

    private func load() {
        loadRecords()
        loadConditions()
        loadThresholds()
    }

    private func loadRecords() {
        guard fileManager.fileExists(atPath: recordsURL.path) else { return }

        do {
            let data = try Data(contentsOf: recordsURL)
            records = try JSONDecoder().decode(
                [PointRecord].self,
                from: data
            )
            records.sort { $0.date > $1.date }
        } catch {
            print("Ошибка загрузки баллов:", error)
            records = []
        }
    }

    private func loadConditions() {
        guard fileManager.fileExists(atPath: conditionsURL.path) else { return }

        do {
            let data = try Data(contentsOf: conditionsURL)
            autoConditions = try JSONDecoder().decode(
                [String: String].self,
                from: data
            )
        } catch {
            print("Ошибка загрузки условий автомата:", error)
            autoConditions = [:]
        }
    }

    private func loadThresholds() {
        guard fileManager.fileExists(atPath: thresholdsURL.path) else { return }

        do {
            let data = try Data(contentsOf: thresholdsURL)
            autoThresholds = try JSONDecoder().decode(
                [String: Double].self,
                from: data
            )
        } catch {
            print("Ошибка загрузки количества баллов для автомата:", error)
            autoThresholds = [:]
        }
    }
}
