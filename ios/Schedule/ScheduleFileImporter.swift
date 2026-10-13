import SwiftUI
import UniformTypeIdentifiers

struct ScheduleFileImporter: View {

    @Environment(\.dismiss)
    private var dismiss

    let onImport:
        ([URL]) -> Void

    @State private var showingPicker =
        false

    var body: some View {

        NavigationStack {

            VStack(
                spacing:
                    24
            ) {

                Image(
                    systemName:
                        "calendar.badge.plus"
                )
                .font(
                    .system(
                        size:
                            52
                    )
                )
                .foregroundStyle(
                    .blue
                )

                Text(
                    "Импорт расписания"
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )

                Text(
                    "Можно выбрать сразу несколько месячных .webarchive. Приложение объединит их в одно расписание."
                )
                .multilineTextAlignment(
                    .center
                )
                .foregroundStyle(
                    .secondary
                )

                Button {

                    showingPicker =
                        true

                } label: {

                    Label(
                        "Выбрать архивы",
                        systemImage:
                            "doc.badge.plus"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(
                    .large
                )
            }
            .padding(
                24
            )
            .navigationTitle(
                "Расписание"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button(
                        "Закрыть"
                    ) {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented:
                    $showingPicker,
                allowedContentTypes:
                    [
                        UTType(
                            filenameExtension:
                                "webarchive"
                        )
                        ?? .data
                    ],
                allowsMultipleSelection:
                    true
            ) { result in

                switch result {

                case .success(
                    let urls
                ):

                    guard
                        !urls.isEmpty
                    else {
                        return
                    }

                    onImport(
                        urls
                    )

                    dismiss()

                case .failure(
                    let error
                ):

                    print(
                        "Ошибка выбора файлов:",
                        error
                    )
                }
            }
        }
    }
}
