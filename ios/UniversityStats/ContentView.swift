import SwiftUI

struct ContentView: View {
    @StateObject private var scheduleStore: ScheduleStore
    @StateObject private var attendanceStore: AttendanceStore
    @StateObject private var pointsStore: PointsStore
    @StateObject private var academicStore: AcademicStore
    @StateObject private var importer: ScheduleImporter

    @State private var showingImporter = false

    init() {
        let schedule = ScheduleStore()

        _scheduleStore = StateObject(wrappedValue: schedule)
        _attendanceStore = StateObject(wrappedValue: AttendanceStore())
        _pointsStore = StateObject(wrappedValue: PointsStore())
        _academicStore = StateObject(wrappedValue: AcademicStore())
        _importer = StateObject(
            wrappedValue: ScheduleImporter(store: schedule)
        )
    }

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(
                    schedule: scheduleStore.schedule,
                    attendanceStore: attendanceStore
                )
                .navigationTitle("Главная")
            }
            .tabItem {
                Label("Главная", systemImage: "house")
            }

            NavigationStack {
                AttendanceView(
                    schedule: scheduleStore.schedule,
                    attendanceStore: attendanceStore
                )
                .navigationTitle("Посещаемость")
            }
            .tabItem {
                Label("Посещаемость", systemImage: "chart.pie")
            }

            NavigationStack {
                PointsView(
                    schedule: scheduleStore.schedule,
                    pointsStore: pointsStore
                )
                .navigationTitle("Баллы")
            }
            .tabItem {
                Label("Баллы", systemImage: "star")
            }

            NavigationStack {
                AcademicPerformanceView(
                    schedule:
                        scheduleStore.schedule,
                    academicStore:
                        academicStore
                )
                .navigationTitle("Успеваемость")
            }
            .tabItem {
                Label(
                    "Успеваемость",
                    systemImage: "chart.bar.xaxis"
                )
            }

            NavigationStack {
                SettingsView(
                    schedule: scheduleStore.schedule,
                    attendanceStore: attendanceStore,
                    onImport: {
                        showingImporter = true
                    },
                    onDelete: {
                        scheduleStore.deleteSchedule()
                    }
                )
                .navigationTitle("Настройки")
            }
            .tabItem {
                Label("Настройки", systemImage: "gearshape")
            }
        }
        .sheet(isPresented: $showingImporter) {
            ScheduleFileImporter { urls in
                importer.importSchedules(from: urls)
            }
        }
        .alert(
            "Ошибка импорта",
            isPresented: Binding(
                get: {
                    importer.errorMessage != nil
                },
                set: { value in
                    if !value {
                        importer.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                importer.errorMessage = nil
            }
        } message: {
            Text(importer.errorMessage ?? "")
        }
    }
}

// MARK: - Home

private struct HomeView: View {
    let schedule: UniversitySchedule

    @ObservedObject
    var attendanceStore: AttendanceStore

    @State private var selectedWeek: Date

    init(
        schedule: UniversitySchedule,
        attendanceStore: AttendanceStore
    ) {
        self.schedule = schedule
        self.attendanceStore = attendanceStore

        _selectedWeek = State(
            initialValue:
                ScheduleDateHelper.currentWeekMonday()
        )
    }

    private var weeks: [Date] {
        ScheduleDateHelper.availableWeekStarts(
            through: schedule.latestDate
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            WeekPicker(
                weeks: weeks,
                selectedWeek: $selectedWeek
            )

            Divider()

            WeekScheduleView(
                schedule: schedule,
                monday: selectedWeek,
                attendanceStore: attendanceStore
            )
        }
    }
}

// MARK: - Week Picker

private struct WeekPicker: View {
    let weeks: [Date]

    @Binding
    var selectedWeek: Date

    var body: some View {
        Menu {
            ForEach(weeks, id: \.self) { week in
                Button {
                    selectedWeek = week
                } label: {
                    HStack {
                        Text(
                            ScheduleDateHelper.weekRange(
                                starting: week
                            )
                        )

                        if ScheduleDateHelper.dateKey(week) ==
                            ScheduleDateHelper.dateKey(selectedWeek) {
                            Spacer()

                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(
                        ScheduleDateHelper.weekRange(
                            starting: selectedWeek
                        )
                    )
                    .font(.headline)

                    Text(
                        ScheduleDateHelper
                            .weekType(for: selectedWeek)
                            .title
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(
                    systemName:
                        "chevron.up.chevron.down"
                )
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Color.secondary.opacity(0.08),
                in:
                    RoundedRectangle(
                        cornerRadius: 14
                    )
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Week Schedule

private struct WeekScheduleView: View {
    let schedule: UniversitySchedule
    let monday: Date

    @ObservedObject
    var attendanceStore: AttendanceStore

    var body: some View {
        List {
            ForEach(DayOfWeek.allCases) { weekday in
                let date = ScheduleDateHelper.date(
                    for: weekday,
                    inWeekStarting: monday
                )

                let day = schedule.day(on: date)

                Section {
                    if let day {
                        if day.lessons.isEmpty {
                            Text("Пар нет")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(day.lessons) { lesson in
                                LessonRow(
                                    lesson: lesson,
                                    date: date,
                                    attendanceStore: attendanceStore
                                )
                            }
                        }
                    } else {
                        Text(
                            "Расписание за этот день не загружено"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text(weekday.title)
                            .font(.headline)

                        Text(
                            ScheduleDateHelper.dayAndMonth(date)
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Lesson

private struct LessonRow: View {
    let lesson: Lesson
    let date: Date

    @ObservedObject
    var attendanceStore: AttendanceStore

    @State private var timerEnabled = false

    private var status: AttendanceStatus? {
        attendanceStore.status(
            for: lesson,
            on: date
        )
    }

    private func isCurrentLesson(at now: Date) -> Bool {
        guard
            let start = ScheduleDateHelper.lessonDate(
                day: date,
                time: lesson.startTime
            ),
            let end = ScheduleDateHelper.lessonDate(
                day: date,
                time: lesson.endTime
            )
        else {
            return false
        }

        return now >= start && now < end
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack(alignment: .top) {
                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    Text(
                        "\(lesson.startTime) – \(lesson.endTime)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(lesson.name)
                        .font(.headline)
                }

                Spacer()

                Text("\(lesson.number)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(
                        width: 28,
                        height: 28
                    )
                    .background(
                        Color.secondary.opacity(0.12),
                        in: Circle()
                    )
            }

            HStack(spacing: 8) {
                Text(lesson.kind.displayTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Color.secondary.opacity(0.12),
                        in: Capsule()
                    )

                if let subgroup = lesson.subgroup {
                    Text("гр.\(subgroup)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Color.secondary.opacity(0.12),
                            in: Capsule()
                        )
                }
            }

            if lesson.teacher != "—" {
                Label(
                    lesson.teacher,
                    systemImage: "person"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if lesson.room != "—" {
                Label(
                    lesson.room,
                    systemImage:
                        "door.left.hand.open"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    timerEnabled = true

                    attendanceStore.setStatus(
                        .attended,
                        for: lesson,
                        on: date
                    )
                } label: {
                    Label(
                        "Я на паре",
                        systemImage:
                            status == .attended
                            ? "checkmark.circle.fill"
                            : "person.fill"
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(
                    status == .attended
                    ? Color.green
                    : Color.blue
                )

                Button {
                    timerEnabled = false

                    attendanceStore.setStatus(
                        .absent,
                        for: lesson,
                        on: date
                    )
                } label: {
                    Label(
                        "Не был",
                        systemImage:
                            status == .absent
                            ? "xmark.circle.fill"
                            : "person.fill.xmark"
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(.bordered)
                .tint(
                    status == .absent
                    ? Color.red
                    : Color.secondary
                )
            }

            if timerEnabled && status == .attended {
                CurrentLessonTimer(
                    lesson: lesson,
                    date: date
                )
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Current Lesson Timer

private struct CurrentLessonTimer: View {
    let lesson: Lesson
    let date: Date

    private enum TimerPhase {
        case beforeStart(TimeInterval)
        case beforeBreak(TimeInterval)
        case breakTime(TimeInterval)
        case afterBreak(TimeInterval)
    }

    var body: some View {
        TimelineView(
            .periodic(
                from: .now,
                by: 1
            )
        ) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if
            let start =
                ScheduleDateHelper.lessonDate(
                    day: date,
                    time: lesson.startTime
                ),
            let end =
                ScheduleDateHelper.lessonDate(
                    day: date,
                    time: lesson.endTime
                ),
            let phase =
                Self.phase(
                    now: now,
                    start: start,
                    end: end
                )
        {
            switch phase {
            case .beforeStart(let remaining):
                timerCard(
                    title: "До начала пары",
                    remaining: remaining
                )

            case .beforeBreak(let remaining):
                timerCard(
                    title: "До перерыва",
                    remaining: remaining
                )

            case .breakTime(let remaining):
                timerCard(
                    title: "Перерыв",
                    remaining: remaining
                )

            case .afterBreak(let remaining):
                timerCard(
                    title: "До конца пары",
                    remaining: remaining
                )
            }
        }
    }

    private func timerCard(
        title: String,
        remaining: TimeInterval
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                Self.countdownString(
                    remaining
                )
            )
            .font(
                .system(
                    size: 24,
                    weight: .semibold,
                    design: .rounded
                )
            )
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            Color.secondary.opacity(0.08),
            in:
                RoundedRectangle(
                    cornerRadius: 14
                )
        )
    }

    private static func phase(
        now: Date,
        start: Date,
        end: Date
    ) -> TimerPhase? {
        guard now < end else {
            return nil
        }

        // Пара ещё не началась.
        if now < start {
            return .beforeStart(
                start.timeIntervalSince(now)
            )
        }

        let elapsed = now.timeIntervalSince(start)

        let firstPart = 45.0 * 60.0
        let breakPart = 5.0 * 60.0

        let firstPartEnd = firstPart
        let breakEnd = firstPart + breakPart

        // Первая часть пары.
        if elapsed < firstPartEnd {
            return .beforeBreak(
                min(
                    firstPartEnd - elapsed,
                    end.timeIntervalSince(now)
                )
            )
        }

        // Пятиминутный перерыв.
        if elapsed < breakEnd {
            return .breakTime(
                min(
                    breakEnd - elapsed,
                    end.timeIntervalSince(now)
                )
            )
        }

        // Вторая часть пары.
        let remaining = end.timeIntervalSince(now)

        guard remaining > 0 else {
            return nil
        }

        return .afterBreak(remaining)
    }

    private static func countdownString(
        _ interval: TimeInterval
    ) -> String {
        let totalSeconds =
            max(
                0,
                Int(
                    interval.rounded(.up)
                )
            )

        let minutes =
            totalSeconds / 60

        let seconds =
            totalSeconds % 60

        return String(
            format: "%02d:%02d",
            minutes,
            seconds
        )
    }
}

// MARK: - Attendance

private struct AttendanceView: View {
    let schedule: UniversitySchedule

    @ObservedObject
    var attendanceStore: AttendanceStore

    @State private var selectedSubject: String

    init(
        schedule: UniversitySchedule,
        attendanceStore: AttendanceStore
    ) {
        self.schedule = schedule
        self.attendanceStore = attendanceStore

        _selectedSubject = State(
            initialValue:
                schedule.subjects().first ?? ""
        )
    }

    private var subjects: [String] {
        schedule.subjects()
    }

    private var overall: AttendanceStatistics {
        attendanceStore.statistics(
            for: selectedSubject
        )
    }

    private var lectures: AttendanceStatistics {
        attendanceStore.statistics(
            for: selectedSubject,
            kind: .lecture
        )
    }

    private var practices: AttendanceStatistics {
        attendanceStore.statistics(
            for: selectedSubject,
            kind: .practice
        )
    }

    private var laboratories: AttendanceStatistics {
        attendanceStore.statistics(
            for: selectedSubject,
            kind: .laboratory
        )
    }

    var body: some View {
        if subjects.isEmpty {
            ContentUnavailableView(
                "Нет предметов",
                systemImage: "chart.pie",
                description:
                    Text("Загрузите расписание.")
            )
        } else {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 20
                ) {
                    Picker(
                        "Предмет",
                        selection: $selectedSubject
                    ) {
                        ForEach(
                            subjects,
                            id: \.self
                        ) { subject in
                            Text(subject)
                                .tag(subject)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(
                        Color.secondary.opacity(0.08),
                        in:
                            RoundedRectangle(
                                cornerRadius: 14
                            )
                    )

                    AttendanceCard(
                        title: "Общая",
                        statistics: overall,
                        icon: "chart.pie"
                    )

                    AttendanceCard(
                        title: "Лекции",
                        statistics: lectures,
                        icon: "book"
                    )

                    AttendanceCard(
                        title: "Практики",
                        statistics: practices,
                        icon: "person.2"
                    )

                    if laboratories.total > 0 {
                        AttendanceCard(
                            title: "Лабораторные",
                            statistics: laboratories,
                            icon: "flask"
                        )
                    }
                }
                .padding()
            }
        }
    }
}

private struct AttendanceCard: View {
    let title: String
    let statistics: AttendanceStatistics
    let icon: String

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Label(
                    title,
                    systemImage: icon
                )
                .font(.headline)

                Spacer()

                Text(
                    statistics.total > 0
                    ? "\(statistics.percentage)%"
                    : "—"
                )
                .font(
                    .system(
                        size: 20,
                        weight: .bold,
                        design: .rounded
                    )
                )
            }

            if statistics.total == 0 {
                Text("Пока нет отметок")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                GeometryReader { geometry in
                    let progress =
                        CGFloat(statistics.attended) /
                        CGFloat(statistics.total)

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(
                                Color.secondary.opacity(0.12)
                            )

                        Capsule()
                            .fill(Color.green)
                            .frame(
                                width:
                                    geometry.size.width *
                                    progress
                            )
                    }
                }
                .frame(height: 9)

                HStack {
                    Text(
                        "Был: \(statistics.attended)"
                    )

                    Spacer()

                    Text(
                        "Не был: \(statistics.absent)"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            Color.secondary.opacity(0.06),
            in:
                RoundedRectangle(
                    cornerRadius: 18
                )
        )
    }
}

// MARK: - Points

private struct PointsView: View {
    let schedule: UniversitySchedule

    @ObservedObject
    var pointsStore: PointsStore

    @State private var selectedSubject: String
    @State private var showingAdd = false
    @State private var autoThresholdText = ""

    init(
        schedule: UniversitySchedule,
        pointsStore: PointsStore
    ) {
        self.schedule = schedule
        self.pointsStore = pointsStore

        _selectedSubject = State(
            initialValue:
                schedule.subjects().first ?? ""
        )
    }

    private var subjects: [String] {
        schedule.subjects()
    }

    private var records: [PointRecord] {
        pointsStore.records(
            for: selectedSubject
        )
    }

    private var total: Double {
        pointsStore.total(
            for: selectedSubject
        )
    }

    var body: some View {
        if subjects.isEmpty {
            ContentUnavailableView(
                "Нет предметов",
                systemImage: "star",
                description:
                    Text("Загрузите расписание.")
            )
        } else {
            List {
                Section("Предмет") {
                    Picker(
                        "Предмет",
                        selection: $selectedSubject
                    ) {
                        ForEach(
                            subjects,
                            id: \.self
                        ) { subject in
                            Text(subject)
                                .tag(subject)
                        }
                    }
                    .onChange(
                        of: selectedSubject
                    ) { _, newValue in
                        autoThresholdText =
                            thresholdText(
                                for: newValue
                            )
                    }
                }

                Section {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text("Всего баллов")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(
                            PointsFormatter.string(
                                total
                            )
                        )
                        .font(
                            .system(
                                size: 38,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                    }
                    .padding(.vertical, 8)

                    Button {
                        showingAdd = true
                    } label: {
                        Label(
                            "Добавить баллы",
                            systemImage: "plus"
                        )
                    }
                }

                Section("Автомат") {
                    HStack {
                        Text(
                            "Количество баллов для автомата"
                        )

                        Spacer()

                        TextField(
                            "Не задано",
                            text: $autoThresholdText
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .onSubmit {
                            saveThreshold()
                        }
                    }

                    Button(
                        "Сохранить количество"
                    ) {
                        saveThreshold()
                    }
                    .disabled(!thresholdIsValid)

                    if let threshold =
                        pointsStore.autoThreshold(
                            for: selectedSubject
                        ) {
                        let remaining =
                            max(
                                0,
                                threshold - total
                            )

                        HStack {
                            Text(
                                remaining > 0
                                ? "Осталось набрать"
                                : "Автомат набран"
                            )

                            Spacer()

                            Text(
                                PointsFormatter.string(
                                    remaining
                                )
                            )
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                remaining > 0
                                ? Color.secondary
                                : Color.green
                            )
                        }
                    }
                }

                Section("История") {
                    if records.isEmpty {
                        Text("Баллов пока нет")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(records) { record in
                            HStack {
                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {
                                    Text(
                                        record.kind.title
                                    )
                                    .font(.headline)

                                    Text(
                                        record.comment.isEmpty
                                        ? "Без комментария"
                                        : record.comment
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                }

                                Spacer()

                                Text(
                                    "+\(PointsFormatter.string(record.points))"
                                )
                                .font(.headline)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                pointsStore.deleteRecord(
                                    records[index]
                                )
                            }
                        }
                    }
                }
            }
            .onAppear {
                autoThresholdText =
                    thresholdText(
                        for: selectedSubject
                    )
            }
            .sheet(
                isPresented: $showingAdd
            ) {
                AddPointView(
                    subject: selectedSubject,
                    pointsStore: pointsStore
                )
            }
        }
    }

    private var thresholdIsValid: Bool {
        let normalized =
            autoThresholdText
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if normalized.isEmpty {
            return true
        }

        guard let value = Double(normalized) else {
            return false
        }

        return value >= 0
    }

    private func thresholdText(
        for subject: String
    ) -> String {
        guard let value =
                pointsStore.autoThreshold(
                    for: subject
                )
        else {
            return ""
        }

        return PointsFormatter.string(value)
    }

    private func saveThreshold() {
        let normalized =
            autoThresholdText
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if normalized.isEmpty {
            pointsStore.setAutoThreshold(
                nil,
                for: selectedSubject
            )
            return
        }

        guard
            let value = Double(normalized),
            value >= 0
        else {
            return
        }

        pointsStore.setAutoThreshold(
            value,
            for: selectedSubject
        )

        autoThresholdText =
            PointsFormatter.string(value)
    }
}

// MARK: - Add Point

private struct AddPointView: View {
    @Environment(\.dismiss)
    private var dismiss

    let subject: String

    @ObservedObject
    var pointsStore: PointsStore

    @State private var kind: LessonKind = .practice
    @State private var pointsText = ""
    @State private var date = Date()
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Тип") {
                    Picker(
                        "Тип",
                        selection: $kind
                    ) {
                        Text("Лекция")
                            .tag(LessonKind.lecture)

                        Text("Практика")
                            .tag(LessonKind.practice)

                        Text("Лабораторная")
                            .tag(LessonKind.laboratory)
                    }
                }

                Section("Баллы") {
                    TextField(
                        "Количество",
                        text: $pointsText
                    )
                    .keyboardType(.decimalPad)

                    DatePicker(
                        "Дата",
                        selection: $date,
                        displayedComponents: .date
                    )
                }

                Section("Комментарий") {
                    TextField(
                        "Комментарий",
                        text: $comment,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
            }
            .navigationTitle("Добавить баллы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button("Добавить") {
                        guard
                            let points =
                                Double(
                                    pointsText
                                        .replacingOccurrences(
                                            of: ",",
                                            with: "."
                                        )
                                ),
                            points >= 0
                        else {
                            return
                        }

                        pointsStore.addRecord(
                            subject: subject,
                            kind: kind,
                            points: points,
                            date: date,
                            comment: comment
                        )

                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings

private struct SettingsView: View {
    let schedule: UniversitySchedule

    @ObservedObject
    var attendanceStore: AttendanceStore

    let onImport: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteSchedule = false
    @State private var showingDeleteAttendance = false

    var body: some View {
        List {
            Section("Расписание") {
                Button {
                    onImport()
                } label: {
                    Label(
                        "Импортировать .webarchive",
                        systemImage: "arrow.down.doc"
                    )
                }

                HStack {
                    Text("Загружено дней")

                    Spacer()

                    Text(
                        "\(schedule.days.count)"
                    )
                    .foregroundStyle(.secondary)
                }

                if let earliest =
                    schedule.earliestDate {
                    HStack {
                        Text("Первый день")

                        Spacer()

                        Text(
                            ScheduleDateHelper.dayAndMonth(
                                earliest
                            )
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                if let latest =
                    schedule.latestDate {
                    HStack {
                        Text("Последний день")

                        Spacer()

                        Text(
                            ScheduleDateHelper.dayAndMonth(
                                latest
                            )
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Посещаемость") {
                Button {
                    showingDeleteAttendance = true
                } label: {
                    Label(
                        "Удалить присутствие",
                        systemImage:
                            "person.fill.xmark"
                    )
                }
            }

            Section("Данные") {
                Button(
                    role: .destructive
                ) {
                    showingDeleteSchedule = true
                } label: {
                    Label(
                        "Удалить всё расписание",
                        systemImage: "trash"
                    )
                }
            }

            Section("Приложение") {
                HStack {
                    Text("UniversityStats")

                    Spacer()

                    Text("1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(
            isPresented:
                $showingDeleteAttendance
        ) {
            DeleteAttendanceView(
                schedule: schedule,
                attendanceStore: attendanceStore
            )
        }
        .confirmationDialog(
            "Удалить расписание?",
            isPresented:
                $showingDeleteSchedule,
            titleVisibility:
                .visible
        ) {
            Button(
                "Удалить",
                role: .destructive
            ) {
                onDelete()
            }

            Button(
                "Отмена",
                role: .cancel
            ) {}
        }
    }
}

// MARK: - Delete Attendance

private struct DeleteAttendanceView: View {
    @Environment(\.dismiss)
    private var dismiss

    let schedule: UniversitySchedule

    @ObservedObject
    var attendanceStore: AttendanceStore

    @State private var selectedDate = Date()
    @State private var selectedLessonID = ""
    @State private var showingConfirmation = false

    private var lessons: [Lesson] {
        schedule.day(
            on: selectedDate
        )?.lessons ?? []
    }

    private var selectedLesson: Lesson? {
        lessons.first {
            $0.id == selectedLessonID
        }
    }

    private var selectedStatus: AttendanceStatus? {
        guard
            let lesson = selectedLesson
        else {
            return nil
        }

        return attendanceStore.status(
            for: lesson,
            on: selectedDate
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Дата") {
                    DatePicker(
                        "Дата",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                }

                Section("Пара") {
                    if lessons.isEmpty {
                        Text(
                            "На эту дату пар нет"
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        Picker(
                            "Пара",
                            selection: $selectedLessonID
                        ) {
                            ForEach(lessons) { lesson in
                                Text(
                                    "\(lesson.number). \(lesson.startTime) — \(lesson.name)"
                                )
                                .tag(lesson.id)
                            }
                        }

                        if let status =
                            selectedStatus {
                            HStack {
                                Text(
                                    "Текущая отметка"
                                )

                                Spacer()

                                Text(
                                    status == .attended
                                    ? "Был"
                                    : "Не был"
                                )
                                .foregroundStyle(
                                    status == .attended
                                    ? Color.green
                                    : Color.red
                                )
                            }
                        } else {
                            Text(
                                "Отметки нет"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button(
                        "Удалить отметку",
                        role: .destructive
                    ) {
                        showingConfirmation = true
                    }
                    .disabled(
                        selectedLesson == nil ||
                        selectedStatus == nil
                    )
                } footer: {
                    Text(
                        "Удаляется только отметка посещаемости выбранной пары. Расписание и баллы не затрагиваются."
                    )
                }
            }
            .navigationTitle(
                "Удалить присутствие"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectFirstLessonIfNeeded()
            }
            .onChange(
                of: selectedDate
            ) { _, _ in
                selectFirstLessonIfNeeded()
            }
            .onChange(
                of: lessons.map(\.id)
            ) { _, _ in
                selectFirstLessonIfNeeded()
            }
            .confirmationDialog(
                "Удалить отметку?",
                isPresented:
                    $showingConfirmation,
                titleVisibility:
                    .visible
            ) {
                Button(
                    "Удалить",
                    role: .destructive
                ) {
                    guard
                        let lesson =
                            selectedLesson
                    else {
                        return
                    }

                    attendanceStore.deleteStatus(
                        for: lesson,
                        on: selectedDate
                    )
                }

                Button(
                    "Отмена",
                    role: .cancel
                ) {}
            }
        }
    }

    private func selectFirstLessonIfNeeded() {
        if lessons.contains(
            where: {
                $0.id == selectedLessonID
            }
        ) {
            return
        }

        selectedLessonID =
            lessons.first?.id ?? ""
    }
}

// MARK: - Formatter

private enum PointsFormatter {
    static func string(
        _ value: Double
    ) -> String {
        if value.rounded() == value {
            return String(
                Int(value)
            )
        }

        return String(
            format: "%.2f",
            value
        )
        .replacingOccurrences(
            of: ".",
            with: ","
        )
    }
}
