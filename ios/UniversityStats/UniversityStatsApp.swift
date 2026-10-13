import SwiftUI

@main
struct UniversityStatsApp: App {

    var body: some Scene {

        WindowGroup {
            ContentView()
                .task {
                    await AcademicNotificationManager
                        .shared
                        .requestPermissionAndSchedule()
                }
        }
    }
}
