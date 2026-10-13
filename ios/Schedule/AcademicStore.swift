import Foundation
import Combine

// MARK: - Тип академической оценки

enum AcademicAssessmentType:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Sendable {

    case controlWeek
    case session
}

// MARK: - Контрольная точка

struct AcademicAssessment:
    Identifiable,
    Codable,
    Hashable,
    Sendable {

    let type:
        AcademicAssessmentType

    let number:
        Int

    let id:
        String

    let title:
        String

    let subtitle:
        String

    var allowedGrades:
        [Int] {

        switch type {

        case .controlWeek:
            return [0, 1, 2]

        case .session:
            return [2, 3, 4, 5]
        }
    }
}

// MARK: - Оценка по предмету

struct AcademicGrade:
    Identifiable,
    Codable,
    Hashable,
    Sendable {

    let id:
        String

    let assessmentID:
        String

    let subject:
        String

    let value:
        Int

    let date:
        Date
}

// MARK: - Store

@MainActor
final class AcademicStore:
    ObservableObject {

    @Published
    private(set) var grades:
        [String: AcademicGrade] = [:]

    private let fileManager =
        FileManager.default

    private var fileURL:
        URL {

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
                "academic_grades_v3.json"
            )
    }

    init() {
        load()
    }

    // MARK: - Контрольные точки

    var allAssessments:
        [AcademicAssessment] {

        [
            AcademicAssessment(
                type:
                    .controlWeek,
                number:
                    1,
                id:
                    "control-1",
                title:
                    "Контрольная неделя 1",
                subtitle:
                    "1 семестр · 7-я неделя"
            ),

            AcademicAssessment(
                type:
                    .controlWeek,
                number:
                    2,
                id:
                    "control-2",
                title:
                    "Контрольная неделя 2",
                subtitle:
                    "1 семестр · 14-я неделя"
            ),

            AcademicAssessment(
                type:
                    .controlWeek,
                number:
                    3,
                id:
                    "control-3",
                title:
                    "Контрольная неделя 3",
                subtitle:
                    "2 семестр · 7-я неделя"
            ),

            AcademicAssessment(
                type:
                    .controlWeek,
                number:
                    4,
                id:
                    "control-4",
                title:
                    "Контрольная неделя 4",
                subtitle:
                    "2 семестр · 14-я неделя"
            ),

            AcademicAssessment(
                type:
                    .session,
                number:
                    1,
                id:
                    "session-1",
                title:
                    "Сессия 1",
                subtitle:
                    "Декабрь — январь"
            ),

            AcademicAssessment(
                type:
                    .session,
                number:
                    2,
                id:
                    "session-2",
                title:
                    "Сессия 2",
                subtitle:
                    "Июнь"
            )
        ]
    }

    // MARK: - Получить оценку

    func grade(
        for assessment:
            AcademicAssessment,
        subject:
            String
    ) -> AcademicGrade? {

        let key =
            makeKey(
                assessment:
                    assessment,
                subject:
                    subject
            )

        return grades[key]
    }

    // MARK: - Сохранить оценку

    func setGrade(
        _ value:
            Int,
        for assessment:
            AcademicAssessment,
        subject:
            String
    ) {

        guard assessment.allowedGrades.contains(
            value
        ) else {
            return
        }

        let key =
            makeKey(
                assessment:
                    assessment,
                subject:
                    subject
            )

        let record =
            AcademicGrade(
                id:
                    key,
                assessmentID:
                    assessment.id,
                subject:
                    subject,
                value:
                    value,
                date:
                    Date()
            )

        grades[key] =
            record

        save()
    }

    // MARK: - Удалить оценку

    func deleteGrade(
        for assessment:
            AcademicAssessment,
        subject:
            String
    ) {

        let key =
            makeKey(
                assessment:
                    assessment,
                subject:
                    subject
            )

        grades.removeValue(
            forKey:
                key
        )

        save()
    }

    // MARK: - Оценки по предмету

    func grades(
        for subject:
            String
    ) -> [AcademicGrade] {

        grades.values
            .filter {
                $0.subject == subject
            }
            .sorted {
                $0.assessmentID <
                    $1.assessmentID
            }
    }

    // MARK: - Средний балл сессий

    func sessionAverage(
        for subject:
            String
    ) -> Double? {

        let sessionIDs =
            Set(
                [
                    "session-1",
                    "session-2"
                ]
            )

        let values =
            grades.values
                .filter {
                    $0.subject == subject
                    && sessionIDs.contains(
                        $0.assessmentID
                    )
                }
                .map {
                    $0.value
                }

        guard !values.isEmpty else {
            return nil
        }

        let sum =
            values.reduce(
                0,
                +
            )

        return Double(sum)
            / Double(values.count)
    }

    // MARK: - Количество заполненных оценок

    func completedCount(
        for assessment:
            AcademicAssessment,
        subjects:
            [String]
    ) -> Int {

        subjects.filter {
            grade(
                for:
                    assessment,
                subject:
                    $0
            ) != nil
        }
        .count
    }

    // MARK: - Всего оценок

    func totalCompleted(
        subjects:
            [String]
    ) -> Int {

        grades.values.filter {
            subjects.contains(
                $0.subject
            )
        }
        .count
    }

    // MARK: - Ключ

    private func makeKey(
        assessment:
            AcademicAssessment,
        subject:
            String
    ) -> String {

        "\(assessment.id)|\(subject)"
    }

    // MARK: - Сохранение

    private func save() {

        do {

            let encoder =
                JSONEncoder()

            encoder.outputFormatting =
                [
                    .prettyPrinted,
                    .sortedKeys
                ]

            let data =
                try encoder.encode(
                    Array(
                        grades.values
                    )
                )

            try data.write(
                to:
                    fileURL,
                options:
                    .atomic
            )

        } catch {

            print(
                "Ошибка сохранения успеваемости:",
                error
            )
        }
    }

    // MARK: - Загрузка

    private func load() {

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

            let decoded =
                try JSONDecoder()
                    .decode(
                        [AcademicGrade].self,
                        from:
                            data
                    )

            grades =
                Dictionary(
                    uniqueKeysWithValues:
                        decoded.map {
                            (
                                $0.id,
                                $0
                            )
                        }
                )

        } catch {

            print(
                "Ошибка загрузки успеваемости:",
                error
            )

            grades = [:]
        }
    }
}
