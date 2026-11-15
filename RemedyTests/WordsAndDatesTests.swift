//
//  WordsAndDatesTests.swift
//  RemedyTests
//
//  plan day math, the words the screens show, and the small parsers that read papers
//

import Foundation
import Testing
@testable import Remedy

@Suite struct DayMathTests {

    private let surgery = Fixtures.date("2026-11-20 07:30")

    @Test func planDaysRoundTrip() {
        for day in [-30, -1, 0, 1, 45] {
            let date = DayMath.date(forDay: day, from: surgery)
            #expect(DayMath.dayOffset(of: date, from: surgery) == day)
            #expect(DayMath.minuteOfDay(date) == 0)
        }
        let dose = DayMath.date(forDay: 2, minute: 8 * 60 + 15, from: surgery)
        #expect(DayMath.minuteOfDay(dose) == 495)
    }

    @Test func dayOffsetIgnoresTimeOfDay() {
        #expect(DayMath.dayOffset(of: Fixtures.date("2026-11-19 23:59"), from: surgery) == -1)
        #expect(DayMath.dayOffset(of: Fixtures.date("2026-11-20 00:01"), from: surgery) == 0)
    }

    @Test func clockWords() {
        #expect(DayMath.timeText(0) == "12:00 AM")
        #expect(DayMath.timeText(12 * 60) == "12:00 PM")
        #expect(DayMath.timeText(14 * 60 + 5) == "2:05 PM")
        #expect(DayMath.shortTimeText(9 * 60) == "9 AM")
        #expect(DayMath.shortTimeText(9 * 60 + 30) == "9:30 AM")
        #expect(DayMath.duration(minutes: 45) == "45 min")
        #expect(DayMath.duration(minutes: 120) == "2 h")
        #expect(DayMath.duration(minutes: 80) == "1 h 20 min")
    }

    @Test func relativeAndSurgeryWords() {
        #expect(DayMath.relative(daysFromToday: 0) == "today")
        #expect(DayMath.relative(daysFromToday: 1) == "tomorrow")
        #expect(DayMath.relative(daysFromToday: -1) == "yesterday")
        #expect(DayMath.relative(daysFromToday: 3) == "in 3 days")
        #expect(DayMath.relative(daysFromToday: -4) == "4 days ago")
        #expect(DayMath.surgeryWords(forDay: 0) == "surgery day")
        #expect(DayMath.surgeryWords(forDay: -1) == "the day before surgery")
        #expect(DayMath.surgeryWords(forDay: 5) == "5 days after surgery")
    }

    @Test func phoneAndLinks() {
        #expect(DayMath.phoneText("2015550142") == "(201) 555-0142")
        #expect(DayMath.phoneText("911") == "911")
        #expect(DayMath.phoneURL("2015550142")?.absoluteString == "tel:2015550142")
        #expect(DayMath.mapsURL("1 Main St, Springfield")?.absoluteString.hasPrefix("https://maps.apple.com/?q=1%20Main") == true)
    }
}

@Suite struct PlainTextTests {

    @Test func listsReadLikeASentence() {
        #expect(PlainText.list([]) == "")
        #expect(PlainText.list(["a"]) == "a")
        #expect(PlainText.list(["a", "b"]) == "a and b")
        #expect(PlainText.list(["a", "b", "c"]) == "a, b and c" || PlainText.list(["a", "b", "c"]) == "a, b, and c")
    }

    @Test func countsUseSingularForOne() {
        #expect(PlainText.count(1, "page") == "1 page")
        #expect(PlainText.count(3, "page") == "3 pages")
        #expect(PlainText.count(0, "page") == "0 pages")
    }

    @Test func htmlNotesBecomePlainLines() {
        let html = "<style>p{color:red}</style><p>SAMPLE &ndash; Pre-op</p><p>Stop   ibuprofen&nbsp;7 days.</p><br/>Call &amp; ask &lt;now&gt;"
        #expect(PlainText.fromHTML(html) == "SAMPLE \u{2013} Pre-op\nStop ibuprofen 7 days.\n\nCall & ask <now>")
        // an escaped entity is decoded once, never twice
        #expect(PlainText.fromHTML("&amp;lt;") == "&lt;")
    }

    @Test func firstLetterCase() {
        #expect(PlainText.upperFirst("aspirin") == "Aspirin")
        #expect(PlainText.lowerFirst("Aspirin") == "aspirin")
        #expect(PlainText.upperFirst("") == "")
    }
}

@Suite struct SmallRuleTests {

    @Test func phoneFormatKeepsOnlyRealNumbers() {
        #expect(PhoneFormat.text("201-555-0142") == "(201) 555-0142")
        #expect(PhoneFormat.text("(201) 555 0142") == "(201) 555-0142")
    }

    @Test func checkInTimeClampsAndWords() {
        #expect(CheckInTime.clamped(-5) == 0)
        #expect(CheckInTime.clamped(5000) == 24 * 60 - 1)
        #expect(CheckInTime.text(minute: 20 * 60) == "8:00 PM")
        // days already checked in are skipped
        #expect(!CheckInTime.reminderDays(today: 2, checkedIn: [2]).contains(2))
    }

    @Test func goalCountsNeverOverflow() {
        #expect(GoalCounts.shownCount(done: 7, target: 3) == 3)
        #expect(GoalCounts.isComplete(done: 3, target: 3))
        #expect(!GoalCounts.isComplete(done: 2, target: 3))
        #expect(GoalCounts.dailyTarget(timesPerDay: nil, target: 0) >= 1)
    }

    @Test func restartDayEndsTheStopTheDayBefore() {
        #expect(RestartRule.stopEndDay(restartDay: 3) == 2)
    }

    @Test func simpleWordsUseWeekdaysOnlyInsideTheWeek() {
        let now = Fixtures.date("2026-11-16 10:00")   // a monday
        #expect(SimpleWording.dayWord(daysFromToday: 0, now: now) == "today")
        #expect(SimpleWording.dayWord(daysFromToday: 1, now: now) == "tomorrow")
        #expect(SimpleWording.dayWord(daysFromToday: 3, now: now) == "Thursday")
        #expect(SimpleWording.dayWord(daysFromToday: 10, now: now) == "Nov 26")
    }
}

@Suite struct PaperParserTests {

    @Test func fastingTimesFromPaperWords() {
        #expect(FastingTimes.hoursBefore(in: "Clear liquids until 2 hours before arrival") == 2)
        #expect(FastingTimes.hoursBefore(in: "clear liquids up to two hours before") == 2)
        #expect(FastingTimes.hoursBefore(in: "drink 2 cups of water") == nil)
        #expect(FastingTimes.clockMinute(in: "Arrive at 6:30 AM") == 390)
        #expect(FastingTimes.clockMinute(in: "by 12 pm") == 720)
        #expect(FastingTimes.clockMinute(in: "at 12:15 am") == 15)
        #expect(FastingTimes.clockMinute(in: "13:00") == nil)

        let surgery = Fixtures.date("2026-11-20")
        let arrival = FastingTimes.arrival(fromTexts: ["Please arrive at 6:00 AM"], surgeryDate: surgery)
        #expect(arrival == Fixtures.date("2026-11-20 06:00"))
        let liquids = FastingTimes.clearLiquidsEnd(arrival: arrival, texts: ["Clear liquids until 2 hours before arrival"])
        #expect(liquids == Fixtures.date("2026-11-20 04:00"))
        #expect(FastingTimes.foodStop(surgeryDate: surgery, texts: ["Nothing to eat after midnight"]) == surgery)
    }

    @Test func emailsAreFoundAndChecked() {
        #expect(EmailFinder.addresses(in: "Email nurse@sample-clinic.org or call") == ["nurse@sample-clinic.org"])
        #expect(EmailFinder.isAddress("a@b.co"))
        #expect(!EmailFinder.isAddress("not an email"))
    }

    @Test func medicineNamesAreCleaned() {
        let percocet = MedicineNameCleaner.clean("oxyCODONE-acetaminophen (PERCOCET) 5-325 MG tablet")
        #expect(percocet.strength.lowercased() == "5-325 mg")
        #expect(percocet.otherNames == ["percocet"])
        #expect(percocet.name.lowercased() == "oxycodone-acetaminophen")

        let aspirin = MedicineNameCleaner.clean("baby aspirin 81 mg")
        #expect(aspirin.name.lowercased() == "aspirin")
        #expect(aspirin.strength == "81 mg")
        #expect(aspirin.otherNames.contains("baby aspirin"))

        let plain = MedicineNameCleaner.clean("ibuprofen")
        #expect(plain.name == "Ibuprofen")
        #expect(plain.strength.isEmpty)
    }

    @Test func sameMedicineUnderBrandOrGenericName() {
        let generic = MedicineIdentity.names("Ibuprofen", alsoKnownAs: [])
        let brand = MedicineIdentity.names("Advil", alsoKnownAs: [])
        let other = MedicineIdentity.names("Metformin", alsoKnownAs: [])
        #expect(MedicineIdentity.same(generic, brand))
        #expect(!MedicineIdentity.same(generic, other))
        #expect(MedicineIdentity.key(generic, brand) == MedicineIdentity.key(brand, generic))
    }

    @Test func explicitDatesParse() {
        let date = ExplicitDateParser.parse(date: "11/20/2026", calendar: DayMath.calendar)
        #expect(date.map { DayMath.calendar.startOfDay(for: $0) } == Fixtures.date("2026-11-20"))
        #expect(ExplicitDateParser.parse(date: "someday", calendar: DayMath.calendar) == nil)
    }

    @Test func warningSignPhoneIsFound() {
        #expect(WarningSigns.phone(in: "Call 201-555-0142 if fever over 101") != nil)
        #expect(WarningSigns.phone(in: "Call if fever over 101") == nil)
    }
}
