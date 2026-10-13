import Foundation

enum ScheduleParserError: LocalizedError {
    case invalidArchive
    case archiveContentNotFound
    case scheduleCellNotFound
    case noTemplatesFound

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "Не удалось прочитать webarchive."
        case .archiveContentNotFound:
            return "В webarchive не найдено содержимое страницы."
        case .scheduleCellNotFound:
            return "В webarchive не найдено поле ScheduleCell."
        case .noTemplatesFound:
            return "Не найдено ни одного шаблона расписания."
        }
    }
}

enum ScheduleParser {

    // MARK: - Public

    static func parse(
        webArchiveData data: Data
    ) throws -> UniversitySchedule {

        let pageText = try extractPageText(
            from: data
        )

        let templates = try extractTemplates(
            from: pageText
        )

        guard !templates.isEmpty else {
            throw ScheduleParserError.noTemplatesFound
        }

        let days = buildCalendarDays(
            from: templates
        )

        guard !days.isEmpty else {
            throw ScheduleParserError.noTemplatesFound
        }

        return UniversitySchedule(
            days: days
        )
    }

    // MARK: - WebArchive

    private static func extractPageText(
        from data: Data
    ) throws -> String {

        // webarchive — это binary plist.
        guard
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
        else {
            print("❌ PropertyListSerialization не смог прочитать archive")

            throw ScheduleParserError.invalidArchive
        }

        var strings: [String] = []

        collectStrings(
            from: plist,
            into: &strings
        )

        // Ищем именно тот ресурс, в котором находится ScheduleCell.
        if let scheduleString = strings.first(
            where: {
                $0.contains("ScheduleCell") ||
                $0.contains("days[1]")
            }
        ) {

            return scheduleString
        }

        // Иногда HTML разбит на несколько строк.
        // Объединяем все строки и пробуем снова.
        let combined = strings.joined(
            separator: "\n"
        )

        if combined.contains("ScheduleCell") ||
            combined.contains("days[1]")
        {

            return combined
        }

        throw ScheduleParserError.archiveContentNotFound
    }

    private static func collectStrings(
        from value: Any,
        into result: inout [String]
    ) {

        if let string = value as? String {

            if !string.isEmpty {
                result.append(string)
            }

            return
        }

        if let data = value as? Data {

            // В webarchive некоторые куски могут
            // дополнительно лежать как Data.
            if let string = String(
                data: data,
                encoding: .utf8
            ) {
                result.append(string)
            }

            return
        }

        if let dictionary = value as? [String: Any] {

            for (_, child) in dictionary {
                collectStrings(
                    from: child,
                    into: &result
                )
            }

            return
        }

        if let dictionary = value as? NSDictionary {

            for (_, child) in dictionary {
                collectStrings(
                    from: child,
                    into: &result
                )
            }

            return
        }

        if let array = value as? [Any] {

            for child in array {
                collectStrings(
                    from: child,
                    into: &result
                )
            }

            return
        }

        if let array = value as? NSArray {

            for child in array {
                collectStrings(
                    from: child,
                    into: &result
                )
            }

            return
        }
    }

    // MARK: - Templates

    private static func extractTemplates(
        from archiveString: String
    ) throws -> [[String: Any]] {

        var templates: [[String: Any]] = []

        for index in 1...14 {

            let marker = "days[\(index)]"

            guard
                let markerRange = archiveString.range(
                    of: marker
                )
            else {
                continue
            }

            let afterMarker = archiveString[
                markerRange.upperBound...
            ]

            guard
                let equalsIndex = afterMarker.firstIndex(
                    of: "="
                )
            else {
                continue
            }

            var value = afterMarker[
                afterMarker.index(
                    after: equalsIndex
                )...
            ]

            value = value.drop(
                while: { $0.isWhitespace }
            )

            guard value.first == "'" else {
                
                continue
            }

            let characters = Array(value)

            var escaped = false
            var endIndex: Int?

            if characters.count > 1 {

                for i in 1..<characters.count {

                    let character = characters[i]

                    if escaped {
                        escaped = false
                        continue
                    }

                    if character == "\\" {
                        escaped = true
                        continue
                    }

                    if character == "'" {
                        endIndex = i
                        break
                    }
                }
            }

            guard let endIndex else {
                continue
            }

            let rawValue = String(
                characters[1..<endIndex]
            )

            let decodedString =
                decodeJavaScriptString(
                    rawValue
                )

            guard
                let jsonData = decodedString.data(
                    using: .utf8
                )
            else {
                continue
            }

            do {

                let object =
                    try JSONSerialization.jsonObject(
                        with: jsonData,
                        options: [.fragmentsAllowed]
                    )

                guard
                    let dictionary =
                        object as? [String: Any]
                else {
                    continue
                }

                guard
                    dictionary["ScheduleCell"] != nil
                else {
                    continue
                }

                templates.append(
                    dictionary
                )

            } catch {
                let message = error.localizedDescription

                print(
                    "❌ Ошибка JSON days[\(index)]: \(message)"
                )
            }
        }

        return templates
    }

    // MARK: - Calendar

    private static func buildCalendarDays(
        from templates: [[String: Any]]
    ) -> [ScheduleDay] {

        var result: [ScheduleDay] = []

        let calendar =
            ScheduleDateHelper.calendar

        let currentDate = Date()

        let currentYear =
            calendar.component(
                .year,
                from: currentDate
            )

        let currentMonth =
            calendar.component(
                .month,
                from: currentDate
            )

        let academicYear =
            currentMonth >= 9
            ? currentYear
            : currentYear - 1

        guard
            let academicStart =
                calendar.date(
                    from: DateComponents(
                        year: academicYear,
                        month: 9,
                        day: 1,
                        hour: 12
                    )
                ),
            let academicEnd =
                calendar.date(
                    from: DateComponents(
                        year: academicYear + 1,
                        month: 8,
                        day: 31,
                        hour: 23,
                        minute: 59
                    )
                )
        else {
            return []
        }

        var date = academicStart

        while date <= academicEnd {

            let weekday =
                ScheduleDateHelper.dayOfWeek(
                    for: date
                )

            if weekday == .sunday {

                date =
                    calendar.date(
                        byAdding: .day,
                        value: 1,
                        to: date
                    )!

                continue
            }

            let index =
                templateIndex(
                    for: date
                )

            guard
                index >= 0,
                index < templates.count
            else {

                date =
                    calendar.date(
                        byAdding: .day,
                        value: 1,
                        to: date
                    )!

                continue
            }

            let template =
                templates[index]

            let scheduleDay =
                parseTemplate(
                    template,
                    date: date
                )

            result.append(
                scheduleDay
            )

            date =
                calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: date
                )!
        }

        return result
    }

    private static func templateIndex(
        for date: Date
    ) -> Int {

        let calendar =
            ScheduleDateHelper.calendar

        let academicStart =
            ScheduleDateHelper.academicStartDate(
                for: date
            )

        let monday =
            ScheduleDateHelper.monday(
                of: date
            )

        let firstMonday =
            ScheduleDateHelper.monday(
                of: academicStart
            )

        let components =
            calendar.dateComponents(
                [.day],
                from: firstMonday,
                to: monday
            )

        let daysPassed =
            components.day ?? 0

        let weekNumber =
            max(
                0,
                daysPassed / 7
            )

        let weekday =
            ScheduleDateHelper.dayOfWeek(
                for: date
            )

        let weekdayIndex =
            weekday.rawValue - 1

        let weekOffset =
            (weekNumber % 2) * 7

        return weekOffset + weekdayIndex
    }

    // MARK: - Parse template

    private static func parseTemplate(
        _ template: [String: Any],
        date: Date
    ) -> ScheduleDay {

        guard
            let rawCells =
                template["ScheduleCell"]
        else {
            return ScheduleDay(
                date: date,
                lessons: []
            )
        }

        let cells =
            normalizeArray(rawCells)

        var lessons: [Lesson] = []

        for rawCell in cells {

            guard
                let cell =
                    rawDictionary(rawCell)
            else {
                continue
            }

            guard
                let startTime =
                    extractTime(
                        from: cell["DateBegin"]
                    ),
                let endTime =
                    extractTime(
                        from: cell["DateEnd"]
                    )
            else {

                continue
            }

            let number =
                lessonNumber(
                    startTime: startTime
                )

            guard
                let rawSubgroups =
                    cell["Subgroup"]
            else {
                continue
            }

            let subgroupArray =
                normalizeArray(
                    rawSubgroups
                )

            guard
                !subgroupArray.isEmpty
            else {
                continue
            }

            for rawSubgroup in subgroupArray {

                guard
                    let subgroupData =
                        rawDictionary(
                            rawSubgroup
                        )
                else {
                    continue
                }

                let discipline =
                    extractString(
                        subgroupData["DISCIPLINE"]
                    ) ?? "Без названия"

                let teacher =
                    extractString(
                        subgroupData["TEACHER"]
                    ) ?? ""

                let room =
                    extractString(
                        subgroupData["CLASSROOM"]
                    ) ?? ""

                let group =
                    extractString(
                        subgroupData["GROUP"]
                    )

                let subgroup =
                    extractSubgroupNumber(
                        subgroupData["SUBGROUP"]
                    )

                let kind =
                    lessonKind(
                        from:
                            subgroupData[
                                "TYPE_LESSON"
                            ]
                    )

                let lesson =
                    Lesson(
                        number: number,
                        name: discipline,
                        teacher: teacher,
                        room: room,
                        startTime: startTime,
                        endTime: endTime,
                        subgroup: subgroup,
                        group: group,
                        kind: kind
                    )

                lessons.append(
                    lesson
                )

            }
        }

        var unique: [
            String: Lesson
        ] = [:]

        for lesson in lessons {
            unique[lesson.id] =
                lesson
        }

        let finalLessons =
            unique.values.sorted {

                if $0.number != $1.number {
                    return $0.number < $1.number
                }

                if $0.startTime != $1.startTime {
                    return $0.startTime < $1.startTime
                }

                return $0.name < $1.name
            }

        return ScheduleDay(
            date: date,
            lessons: finalLessons
        )
    }

    // MARK: - Time

    private static func extractTime(
        from value: Any?
    ) -> String? {

        guard let value else {
            return nil
        }

        if let date =
            value as? Date
        {
            return formatTime(
                date
            )
        }

        if let date =
            value as? NSDate
        {
            return formatTime(
                date as Date
            )
        }

        if let string =
            value as? String
        {
            return extractTime(
                fromString: string
            )
        }

        let description =
            String(
                describing: value
            )

        return extractTime(
            fromString: description
        )
    }

    private static func extractTime(
        fromString string: String
    ) -> String? {

        let pattern =
            #"(\d{1,2}):(\d{2})(?::\d{2})?"#

        guard
            let regex =
                try? NSRegularExpression(
                    pattern: pattern
                )
        else {
            return nil
        }

        let range =
            NSRange(
                string.startIndex..<string.endIndex,
                in: string
            )

        guard
            let match =
                regex.firstMatch(
                    in: string,
                    range: range
                )
        else {
            return nil
        }

        guard
            let matchRange =
                Range(
                    match.range,
                    in: string
                )
        else {
            return nil
        }

        let value =
            String(
                string[matchRange]
            )

        let components =
            value.split(
                separator: ":"
            )

        guard
            components.count >= 2,
            let hour =
                Int(components[0]),
            let minute =
                Int(components[1]),
            hour >= 0,
            hour <= 23,
            minute >= 0,
            minute <= 59
        else {
            return nil
        }

        return String(
            format: "%02d:%02d",
            hour,
            minute
        )
    }

    private static func formatTime(
        _ date: Date
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier: "ru_RU"
            )

        formatter.timeZone =
            TimeZone.current

        formatter.dateFormat =
            "HH:mm"

        return formatter.string(
            from: date
        )
    }

    // MARK: - Lesson number

    private static func lessonNumber(
        startTime: String
    ) -> Int {

        switch startTime {

        case "08:00":
            return 1

        case "09:50":
            return 2

        case "11:40":
            return 3

        case "13:45":
            return 4

        case "15:35":
            return 5

        case "17:25":
            return 6

        case "19:15":
            return 7

        default:
            return 0
        }
    }

    // MARK: - Lesson kind

    private static func lessonKind(
        from value: Any?
    ) -> LessonKind {

        let raw =
            extractString(
                value
            )?
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .lowercased()
            ?? ""

        if raw.contains("лек") {
            return .lecture
        }

        if raw.contains("лаб") {
            return .laboratory
        }

        if raw.contains("практ") ||
            raw.contains("семинар")
        {
            return .practice
        }

        return .other
    }

    // MARK: - Subgroup

    private static func extractSubgroupNumber(
        _ value: Any?
    ) -> Int? {

        guard
            let string =
                extractString(value)
        else {
            return nil
        }

        let pattern =
            #"\d+"#

        guard
            let regex =
                try? NSRegularExpression(
                    pattern: pattern
                )
        else {
            return nil
        }

        let range =
            NSRange(
                string.startIndex..<string.endIndex,
                in: string
            )

        guard
            let match =
                regex.firstMatch(
                    in: string,
                    range: range
                ),
            let matchRange =
                Range(
                    match.range,
                    in: string
                )
        else {
            return nil
        }

        return Int(
            string[matchRange]
        )
    }

    // MARK: - Foundation helpers

    private static func normalizeArray(
        _ value: Any
    ) -> [Any] {

        if let array =
            value as? [Any]
        {
            return array
        }

        if let array =
            value as? NSArray
        {
            return array.map {
                $0
            }
        }

        return []
    }

    private static func rawDictionary(
        _ value: Any
    ) -> [String: Any]? {

        if let dictionary =
            value as? [String: Any]
        {
            return dictionary
        }

        if let dictionary =
            value as? NSDictionary
        {
            var result:
                [String: Any] = [:]

            for (
                key,
                value
            ) in dictionary {

                guard
                    let key =
                        key as? String
                else {
                    continue
                }

                result[key] =
                    value
            }

            return result
        }

        return nil
    }

    private static func extractString(
        _ value: Any?
    ) -> String? {

        guard let value else {
            return nil
        }

        if let string =
            value as? String
        {
            return string
        }

        if let array =
            value as? [String]
        {
            return array.first
        }

        if let array =
            value as? NSArray
        {
            if let first =
                array.firstObject
            {
                return extractString(
                    first
                )
            }
        }

        if let dictionary =
            value as? NSDictionary
        {
            if let value =
                dictionary["value"]
            {
                return extractString(
                    value
                )
            }
        }

        return String(
            describing: value
        )
    }

    // MARK: - JS escaping

    private static func decodeJavaScriptString(
        _ value: String
    ) -> String {

        let characters =
            Array(value)

        var result = ""

        result.reserveCapacity(
            value.count
        )

        var index = 0

        while index < characters.count {

            let character =
                characters[index]

            guard
                character == "\\"
            else {
                result.append(
                    character
                )

                index += 1
                continue
            }

            index += 1

            guard
                index < characters.count
            else {
                break
            }

            let escaped =
                characters[index]

            switch escaped {

            case "\\":
                result.append("\\")

            case "'":
                result.append("'")

            case "\"":
                result.append("\"")

            case "n":
                result.append("\n")

            case "r":
                result.append("\r")

            case "t":
                result.append("\t")

            case "/":
                result.append("/")

            case "u":

                if index + 4 <
                    characters.count
                {

                    let hexCharacters =
                        characters[
                            (index + 1)...(index + 4)
                        ]

                    let hex =
                        String(
                            hexCharacters
                        )

                    if let scalarValue =
                        UInt32(
                            hex,
                            radix: 16
                        ),
                        let scalar =
                            UnicodeScalar(
                                scalarValue
                            )
                    {
                        result.append(
                            Character(
                                scalar
                            )
                        )

                        index += 4
                    }
                }

            default:
                result.append(
                    escaped
                )
            }

            index += 1
        }

        return result
    }
}
