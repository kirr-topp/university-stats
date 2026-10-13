import Foundation
import Combine

@MainActor
final class ScheduleImporter: ObservableObject {

    @Published private(set) var isImporting = false

    @Published var errorMessage: String?

    private let store: ScheduleStore

    init(
        store: ScheduleStore
    ) {
        self.store = store
    }

    func importSchedules(
        from urls: [URL]
    ) {

        guard
            !urls.isEmpty,
            !isImporting
        else {
            return
        }

        isImporting = true
        errorMessage = nil

        var accessedURLs: [URL] = []

        for url in urls {

            if url.startAccessingSecurityScopedResource() {
                accessedURLs.append(url)
            }
        }

        defer {

            for url in accessedURLs {
                url.stopAccessingSecurityScopedResource()
            }

            isImporting = false
        }

        var importedCount = 0
        var errors: [String] = []

        for url in urls {

            do {

                let data =
                    try Data(
                        contentsOf:
                            url
                    )

                let parsed =
                    try ScheduleParser.parse(
                        webArchiveData:
                            data
                    )

                store.merge(
                    parsed
                )

                importedCount += 1

            } catch {

                let message =
                    "\(url.lastPathComponent): \(error.localizedDescription)"

                errors.append(
                    message
                )

                print(
                    "Ошибка импорта:",
                    message
                )
            }
        }

        if importedCount == 0 {

            errorMessage =
                errors.isEmpty
                ? "Не удалось импортировать расписание."
                : errors.joined(
                    separator:
                        "\n"
                )

        } else if !errors.isEmpty {

            errorMessage =
                """
                Импортировано файлов: \(importedCount).

                Не удалось импортировать:

                \(errors.joined(separator: "\n"))
                """
        }
    }
}
