import Foundation

/// The App Store screenshot mode.
///
/// Launched with the `-demo` argument, the app skips every network call and
/// shows one invented pupil's week instead: a fictional school, fictional
/// teachers, fictional homework. The only logged-in test device holds a real
/// child's account, and nothing from it may end up on the App Store page —
/// so the screenshots come from here, never from a real session.
///
/// Two ways in, both off by default: the launch argument
/// (`Tools/screenshots.sh`), and the review credentials below — App Review
/// needs a way past the login screen, and Hessen issues no test accounts,
/// so guideline 2.1's "fully featured demo mode" is the way to give them
/// one. The flag persists so the reviewer's session survives a relaunch;
/// „Abmelden“ clears it.
enum DemoMode {
    static let reviewUsername = "apple-review"
    static let reviewPassword = "Demo-Schulportal-2026"
    private static let flagKey = "demo.enabled"

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
            || UserDefaults.standard.bool(forKey: flagKey)
    }

    /// Whether these are the review credentials — compared exactly, no
    /// trimming, so a real account can never collide with them by accident.
    static func matches(username: String, password: String) -> Bool {
        username == reviewUsername && password == reviewPassword
    }

    static func enable() { UserDefaults.standard.set(true, forKey: flagKey) }
    static func disable() { UserDefaults.standard.removeObject(forKey: flagKey) }
}

/// The invented data. Everything is relative to "now", so the Heute tab,
/// the deadlines and the mensa week look current whenever the screenshots
/// are taken.
enum DemoData {
    static let schoolName = "Goethe-Gymnasium Musterstadt"
    static let className = "7c"

    private static var cal: Calendar { GermanDate.calendar }
    private static func time(_ h: Int, _ m: Int) -> TimeOfDay { TimeOfDay(hour: h, minute: m) }

    /// Noon on the day `offset` days from today — the same anchor the
    /// parsers use for a date without a time.
    private static func day(_ offset: Int, hour: Int = 12, minute: Int = 0) -> Date {
        let base = cal.startOfDay(for: Date())
        let date = cal.date(byAdding: .day, value: offset, to: base) ?? base
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    /// The most recent Monday, today included.
    private static var monday: Date {
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) // 1 = Sunday
        let back = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -back, to: today) ?? today
    }

    /// Days from today to the next `weekday`, always in the future.
    private static func offset(toNext weekday: Weekday) -> Int {
        let todayIndex = cal.component(.weekday, from: Date())
        var delta = weekday.calendarWeekday - todayIndex
        if delta <= 0 { delta += 7 }
        return delta
    }

    // MARK: - Timetable

    static let periods: [Period] = [
        Period(index: 1, start: TimeOfDay(hour: 8, minute: 0), end: TimeOfDay(hour: 8, minute: 45)),
        Period(index: 2, start: TimeOfDay(hour: 8, minute: 50), end: TimeOfDay(hour: 9, minute: 35)),
        Period(index: 3, start: TimeOfDay(hour: 9, minute: 55), end: TimeOfDay(hour: 10, minute: 40)),
        Period(index: 4, start: TimeOfDay(hour: 10, minute: 45), end: TimeOfDay(hour: 11, minute: 30)),
        Period(index: 5, start: TimeOfDay(hour: 11, minute: 50), end: TimeOfDay(hour: 12, minute: 35)),
        Period(index: 6, start: TimeOfDay(hour: 12, minute: 40), end: TimeOfDay(hour: 13, minute: 25)),
        Period(index: 7, start: TimeOfDay(hour: 13, minute: 55), end: TimeOfDay(hour: 14, minute: 40)),
        Period(index: 8, start: TimeOfDay(hour: 14, minute: 45), end: TimeOfDay(hour: 15, minute: 30))
    ]

    private static func lesson(_ weekday: Weekday, _ first: Int, _ last: Int, _ code: String, room: String, teacher: String) -> TimetableEntry {
        let start = periods[first - 1].start
        let end = periods[last - 1].end
        let title = "\(code) 07c GYM"
        return TimetableEntry(id: "demo:\(weekday.rawValue):\(first)",
                              weekday: weekday,
                              firstPeriod: first,
                              lastPeriod: last,
                              start: start,
                              end: end,
                              rawTitle: title,
                              subject: Subject.resolve(fromCourseTitle: title),
                              room: room,
                              teacher: teacher)
    }

    static var timetable: Timetable {
        var plan = Timetable()
        plan.periods = periods
        plan.validFrom = "Gültig ab \(GermanDate.dayMonthYear.string(from: day(-21)))"
        plan.fetchedAt = Date()
        plan.entries = [
            lesson(.monday, 1, 2, "M", room: "204", teacher: "Ber"),
            lesson(.monday, 3, 4, "D", room: "204", teacher: "Kln"),
            lesson(.monday, 5, 5, "E", room: "112", teacher: "Sch"),
            lesson(.monday, 6, 6, "MU", room: "Musik 1", teacher: "Hof"),
            lesson(.monday, 7, 8, "SPO", room: "Halle", teacher: "Wgn"),

            lesson(.tuesday, 1, 2, "E", room: "112", teacher: "Sch"),
            lesson(.tuesday, 3, 3, "BIO", room: "Bio 2", teacher: "Fis"),
            lesson(.tuesday, 4, 4, "GEO", room: "204", teacher: "Mai"),
            lesson(.tuesday, 5, 6, "KU", room: "Kunst 1", teacher: "Rot"),
            lesson(.tuesday, 7, 7, "ETHI", room: "308", teacher: "Nov"),

            lesson(.wednesday, 1, 1, "D", room: "204", teacher: "Kln"),
            lesson(.wednesday, 2, 2, "M", room: "204", teacher: "Ber"),
            lesson(.wednesday, 3, 4, "NAWI", room: "Physik", teacher: "Fis"),
            lesson(.wednesday, 5, 6, "F", room: "115", teacher: "Lam"),
            lesson(.wednesday, 7, 7, "KL", room: "204", teacher: "Kln"),

            lesson(.thursday, 1, 2, "G", room: "301", teacher: "Mai"),
            lesson(.thursday, 3, 4, "M", room: "204", teacher: "Ber"),
            lesson(.thursday, 5, 5, "E", room: "112", teacher: "Sch"),
            lesson(.thursday, 6, 6, "D", room: "204", teacher: "Kln"),
            lesson(.thursday, 7, 8, "DW", room: "PC 2", teacher: "Nov"),

            lesson(.friday, 1, 2, "F", room: "115", teacher: "Lam"),
            lesson(.friday, 3, 3, "MU", room: "Musik 1", teacher: "Hof"),
            lesson(.friday, 4, 4, "D", room: "204", teacher: "Kln"),
            lesson(.friday, 5, 6, "SPO", room: "Halle", teacher: "Wgn")
        ]
        return plan
    }

    static let activities: [SchoolActivity] = [
        SchoolActivity(id: "demo-theater",
                       title: "Theater-AG",
                       weekday: .tuesday,
                       start: TimeOfDay(hour: 14, minute: 45),
                       end: TimeOfDay(hour: 16, minute: 15),
                       room: "Aula",
                       leader: "Frau Rot")
    ]

    // MARK: - Courses and homework

    private struct CourseSpec {
        var code: String
        var teacher: String
    }

    private static let courseSpecs: [CourseSpec] = [
        CourseSpec(code: "M", teacher: "Ber"),
        CourseSpec(code: "D", teacher: "Kln"),
        CourseSpec(code: "E", teacher: "Sch"),
        CourseSpec(code: "BIO", teacher: "Fis"),
        CourseSpec(code: "GEO", teacher: "Mai"),
        CourseSpec(code: "F", teacher: "Lam"),
        CourseSpec(code: "G", teacher: "Mai"),
        CourseSpec(code: "MU", teacher: "Hof"),
        CourseSpec(code: "KU", teacher: "Rot"),
        CourseSpec(code: "NAWI", teacher: "Fis"),
        CourseSpec(code: "DW", teacher: "Nov")
    ]

    static var courses: [Course] {
        courseSpecs.map { spec in
            let title = "\(spec.code) 07c GYM"
            return Course(id: "demo-\(spec.code.lowercased())",
                          rawTitle: title,
                          subject: Subject.resolve(fromCourseTitle: title),
                          teacher: spec.teacher)
        }
    }

    private struct EntrySpec {
        var code: String
        /// Days ago the lesson took place.
        var daysAgo: Int
        var topic: String
        var homework: String?
        var done = false
    }

    private static var entrySpecs: [EntrySpec] {
        [
            EntrySpec(code: "M", daysAgo: 0, topic: "Brüche kürzen und erweitern",
                      homework: "Buch S. 42 Nr. 3–7. Wer mag: Knobelaufgabe Nr. 9."),
            EntrySpec(code: "D", daysAgo: 0, topic: "Lesetagebuch: „Rico, Oskar und die Tieferschatten“",
                      homework: "Kapitel 5 und 6 lesen und die Fragen im Heft beantworten bis zum \(GermanDate.dayMonth.string(from: day(4)))"),
            EntrySpec(code: "E", daysAgo: 1, topic: "Unit 2: My hometown",
                      homework: "Vocabulary Unit 2 (p. 178–179) lernen, Workbook p. 14 ex. 1–3"),
            EntrySpec(code: "BIO", daysAgo: 1, topic: "Der Aufbau der Zelle",
                      homework: "Arbeitsblatt „Zellaufbau“ fertig ausfüllen und beschriften"),
            EntrySpec(code: "F", daysAgo: 2, topic: "Leçon 1: Salut, c'est moi!",
                      homework: "Vokabeln Leçon 1 lernen, Cahier S. 8 Nr. 2"),
            EntrySpec(code: "G", daysAgo: 3, topic: "Leben auf der Burg",
                      homework: "Kurzreferat vorbereiten (5 Minuten): ein Beruf im Mittelalter. Abgabe: \(GermanDate.dayMonth.string(from: day(9)))"),
            EntrySpec(code: "GEO", daysAgo: 3, topic: "Flüsse und Gebirge Europas",
                      homework: "Atlas S. 12–13: die zehn längsten Flüsse Europas in die Karte eintragen"),
            EntrySpec(code: "MU", daysAgo: 4, topic: "Notenwerte und Pausen",
                      homework: "Notenwerte-Blatt fertig machen", done: true),
            EntrySpec(code: "KU", daysAgo: 5, topic: "Der Farbkreis nach Itten",
                      homework: "Farbkreis fertig ausmalen", done: true),
            EntrySpec(code: "NAWI", daysAgo: 6, topic: "Messen: Länge, Masse, Zeit",
                      homework: "Protokoll zum Versuch „Pendel“ abschreiben", done: true),
            EntrySpec(code: "DW", daysAgo: 7, topic: "Was ist ein Algorithmus?", homework: nil)
        ]
    }

    static var entries: [LessonEntry] {
        entrySpecs.enumerated().map { index, spec in
            let title = "\(spec.code) 07c GYM"
            let subject = Subject.resolve(fromCourseTitle: title)
            let courseID = "demo-\(spec.code.lowercased())"
            let date = day(-spec.daysAgo)
            let homework = spec.homework.map { text in
                Homework(id: Homework.makeID(courseID: courseID, entryID: "\(index + 1)", date: date, text: text),
                         courseID: courseID,
                         courseTitle: title,
                         subject: subject,
                         text: text,
                         assignedDate: date,
                         dueDate: GermanDate.dueDate(in: text),
                         isDoneOnPortal: spec.done,
                         portalEntryID: "\(index + 1)",
                         portalBookID: courseID)
            }
            return LessonEntry(id: "demo-entry-\(index)",
                               courseID: courseID,
                               courseTitle: title,
                               subject: subject,
                               date: date,
                               topic: spec.topic,
                               content: nil,
                               homework: homework,
                               attachments: [])
        }
    }

    // MARK: - Vertretungen

    static var substitutions: SubstitutionPlan {
        func entry(_ id: String, period: String, kind: String, subject: String, teacher: String, substitute: String? = nil, room: String? = nil, previousRoom: String? = nil, note: String? = nil) -> Substitution {
            Substitution(id: id, period: period, kind: kind, className: "07C", subject: subject,
                         previousSubject: nil, teacher: teacher, substitute: substitute,
                         room: room, previousRoom: previousRoom, note: note)
        }
        // Today and the next two days: whichever of them the Heute tab is
        // about has something to show.
        let days = (0...2).map { offset -> SubstitutionDay in
            switch offset {
            case 0:
                return SubstitutionDay(date: day(0), entries: [
                    entry("d0-1", period: "3 - 4", kind: "Vertretung", subject: "D", teacher: "Kln", substitute: "Mai", room: "204"),
                    entry("d0-2", period: "7", kind: "Entfall", subject: "ETHI", teacher: "Nov")
                ], infos: nil)
            case 1:
                return SubstitutionDay(date: day(1), entries: [
                    entry("d1-1", period: "1 - 2", kind: "Raumvertretung", subject: "E", teacher: "Sch", room: "115", previousRoom: "112"),
                    entry("d1-2", period: "5 - 6", kind: "Vertretung", subject: "KU", teacher: "Rot", substitute: "Hof", room: "Kunst 1", note: "Material mitbringen")
                ], infos: [SubstitutionInfo(header: "Hinweis", values: ["Die Bibliothek bleibt wegen Inventur bis Freitag geschlossen."])])
            default:
                return SubstitutionDay(date: day(2), entries: [
                    entry("d2-1", period: "7", kind: "Entfall", subject: "KL", teacher: "Kln")
                ], infos: nil)
            }
        }
        return SubstitutionPlan(days: days, fetchedAt: Date())
    }

    // MARK: - Termine

    static var events: [SchoolEvent] {
        func event(_ id: String, _ title: String, _ description: String, category: String, color: String, start: Date, end: Date, allDay: Bool = true, place: String? = nil) -> SchoolEvent {
            SchoolEvent(id: id, title: title, description: description, place: place,
                        categoryName: category, colorHex: color, start: start, end: end, isAllDay: allDay)
        }
        let exam = "#d70015"
        let school = "#0a6cc4"
        let holiday = "#248a3d"
        return [
            event("e1", "M 07c Arbeit", "Arbeit in M 07c: Brüche", category: "Klassenarbeiten", color: exam,
                  start: day(8), end: day(9, hour: 0)),
            event("e2", "E 07c Test", "Vocabulary test Unit 2", category: "Klassenarbeiten", color: exam,
                  start: day(3), end: day(4, hour: 0)),
            event("e3", "Elternabend 7c", "Klassenelternabend im Raum 204", category: "Schule", color: school,
                  start: day(5, hour: 19, minute: 0), end: day(5, hour: 20, minute: 30), allDay: false, place: "Raum 204"),
            event("e4", "Wandertag", "Wandertag aller Klassen — Treffpunkt 8:00 Uhr am Haupteingang", category: "Schule", color: school,
                  start: day(offset(toNext: .friday) + 7), end: day(offset(toNext: .friday) + 8, hour: 0)),
            event("e5", "Herbstferien", "Herbstferien in Hessen", category: "Ferien", color: holiday,
                  start: day(28), end: day(42, hour: 0)),
            event("e6", "Tag der offenen Tür", "Für die neuen Fünftklässler und ihre Eltern", category: "Schule", color: school,
                  start: day(19, hour: 10, minute: 0), end: day(19, hour: 13, minute: 0), allDay: false, place: "Aula")
        ]
    }

    // MARK: - Fehlzeiten

    static var attendance: [CourseAttendance] {
        func row(_ code: String, absent: Int, excused: Int, unexcused: Int = 0) -> CourseAttendance {
            CourseAttendance(courseID: "demo-\(code.lowercased())",
                             courseTitle: "\(code) 07c GYM",
                             counts: [AttendanceCount(category: "fehlend", value: "\(absent)"),
                                      AttendanceCount(category: "entschuldigt", value: "\(excused)"),
                                      AttendanceCount(category: "unentschuldigt", value: "\(unexcused)")])
        }
        return [
            row("M", absent: 2, excused: 2),
            row("D", absent: 2, excused: 2),
            row("E", absent: 1, excused: 1),
            row("SPO", absent: 3, excused: 3),
            row("BIO", absent: 0, excused: 0)
        ]
    }

    // MARK: - The snapshot

    static var snapshot: Snapshot {
        var snapshot = Snapshot()
        snapshot.courses = courses
        snapshot.entries = entries
        snapshot.timetable = timetable
        snapshot.substitutions = substitutions
        snapshot.events = events
        snapshot.attendance = attendance
        snapshot.lastRefresh = Date()
        return snapshot
    }

    // MARK: - Mensa

    static var mensaAccount: MensaAccount {
        MensaAccount(username: "lena.m", balanceText: "23,40", balance: Decimal(string: "23.40"))
    }

    static var mensaWeek: MenuWeek {
        let monday = self.monday
        let isoWeek = cal.component(.weekOfYear, from: monday)
        let year = cal.component(.yearForWeekOfYear, from: monday)
        let friday = cal.date(byAdding: .day, value: 4, to: monday) ?? monday
        let label = "KW \(isoWeek) (\(GermanDate.dayMonth.string(from: monday)) - \(GermanDate.dayMonth.string(from: friday)))"
        let today = cal.startOfDay(for: Date())

        func option(_ id: String, _ title: String, _ text: String, price: String = "3,50 €", allergens: String = "1, GL", certified: Bool = false) -> MenuOption {
            MenuOption(id: id, title: title, text: text, priceText: price,
                       allergenCodes: allergens, allergenText: "", isCertified: certified)
        }

        let menus: [(String, [MenuOption])] = [
            ("MO", [option("1", "Menü 1", "Spaghetti Bolognese\nGurkensalat\nApfelmus", allergens: "GL, SE"),
                    option("2", "Vegetarisch", "Gemüselasagne\nBlattsalat\nApfelmus", allergens: "GL, ML", certified: true)]),
            ("DI", [option("1", "Menü 1", "Hähnchenschnitzel mit Kartoffelpüree\nErbsen und Möhren\nJoghurt", allergens: "GL, ML"),
                    option("2", "Vegetarisch", "Kartoffel-Gemüse-Gratin\nJoghurt", allergens: "ML", certified: true)]),
            ("MI", [option("1", "Menü 1", "Fischstäbchen mit Kartoffelsalat\nRemoulade\nObst", allergens: "GL, FI, EI"),
                    option("2", "Vegetarisch", "Pastabar: Penne mit Tomatensauce\nParmesan\nObst", allergens: "GL, ML")]),
            ("DO", [option("1", "Menü 1", "Rindergulasch mit Nudeln\nRotkohl\nPudding", allergens: "GL, ML"),
                    option("2", "Vegetarisch", "Gemüsecurry mit Reis\nPudding", allergens: "ML", certified: true)]),
            ("FR", [option("1", "Menü 1", "Pizza Margherita\nRohkost\nEis", allergens: "GL, ML"),
                    option("2", "Vegetarisch", "Kaiserschmarrn mit Apfelkompott", allergens: "GL, ML, EI")])
        ]
        let ordered: [String: String] = ["MO": "2", "DI": "1", "MI": "2", "DO": "1"]

        var days: [MenuDay] = []
        for (index, (key, options)) in menus.enumerated() {
            let date = cal.date(byAdding: .day, value: index, to: monday) ?? monday
            let isPast = cal.startOfDay(for: date) <= today
            days.append(MenuDay(id: key, date: date, isLocked: isPast,
                                orderedOptionID: ordered[key], options: options))
        }

        var week = MenuWeek()
        week.key = "\(year)_\(isoWeek)"
        week.label = label
        week.days = days
        week.availableWeeks = [WeekOption(key: week.key, label: label)]
        return week
    }

    static var mensaStatement: MensaStatement {
        func booking(_ id: String, daysAgo: Int, _ text: String, _ amount: String) -> MensaTransaction {
            MensaTransaction(id: id, date: day(-daysAgo, hour: 12, minute: 30), text: text,
                             amount: Decimal(string: amount) ?? 0)
        }
        return MensaStatement(balance: Decimal(string: "23.40"),
                              balanceText: "23,40",
                              lowBalanceThreshold: 15,
                              transactions: [
                                booking("t1", daysAgo: 0, "Menü 2 Vegetarisch", "-3.50"),
                                booking("t2", daysAgo: 3, "Menü 1", "-3.50"),
                                booking("t3", daysAgo: 4, "Kiosk: Brezel", "-1.20"),
                                booking("t4", daysAgo: 5, "Menü 2 Vegetarisch", "-3.50"),
                                booking("t5", daysAgo: 6, "Aufladung Überweisung", "30.00"),
                                booking("t6", daysAgo: 10, "Menü 1", "-3.50"),
                                booking("t7", daysAgo: 11, "Menü 1", "-3.50"),
                                booking("t8", daysAgo: 12, "Kiosk: Apfelschorle", "-1.00")
                              ])
    }

    // MARK: - Settings

    static let links: [SchoolLink] = [
        SchoolLink(title: "Schulwebsite", url: URL(string: "https://www.example.org/")!),
        SchoolLink(title: "Termine", url: URL(string: "https://www.example.org/termine")!),
        SchoolLink(title: "Elternbeirat", url: URL(string: "https://www.example.org/elternbeirat")!)
    ]

    /// Puts the invented school into the settings so every screen has
    /// something to say: a name under „Mehr“, an Essen tab, two links.
    @MainActor
    static func configure(_ settings: Settings) {
        settings.schoolID = "0000"
        settings.schoolName = schoolName
        settings.mensaTenantOverride = "demo"
        settings.showsMensaTab = true
        settings.customLinks = links
        settings.activities = activities
        settings.refreshesOnLaunch = false
    }

    /// Undoes `configure`, so a real login after the review session starts
    /// from a clean slate.
    @MainActor
    static func reset(_ settings: Settings) {
        settings.schoolID = ""
        settings.schoolName = ""
        settings.mensaTenantOverride = ""
        settings.clearMensaTabOverride()
        settings.customLinks = []
        settings.activities = []
        settings.refreshesOnLaunch = true
    }
}
