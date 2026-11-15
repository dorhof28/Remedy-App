//
//  SamplePlan.swift
//  Remedy
//
//  sample data for previews tests and the demo
//

import Foundation
import SwiftData

enum SamplePlan {

    // made up patient for the demo and app media
    static let patientName = "Avery Quinn"

    // puts a full before-and-after plan into the database
    static func insert(into context: ModelContext, surgeryInDays: Int = 9) {
        // midnight of the surgery day so "days until surgery" counts whole days
        let today = Calendar.current.startOfDay(for: Date())
        let surgeryDate = Calendar.current.date(byAdding: .day, value: surgeryInDays, to: today)
        let plan = CarePlan(procedure: "Right total knee replacement", surgeryDate: surgeryDate, source: .scan)
        plan.isSample = true
        // made up hospital and times for surgery day
        if let surgeryDate {
            plan.hospitalName = "Riverside Orthopedic Hospital"
            plan.hospitalAddress = "30 Prospect Avenue, Hackensack, NJ"
            plan.hospitalWhereToGo = "Main entrance, then Surgical Admitting on the 2nd floor"
            plan.arrivalTime = DayMath.date(forDay: 0, minute: 5 * 60 + 30, from: surgeryDate)
            plan.surgeryStartTime = DayMath.date(forDay: 0, minute: 7 * 60 + 30, from: surgeryDate)
            plan.dischargeDate = DayMath.date(forDay: 2, from: surgeryDate)
        }
        plan.checkInMinute = 20 * 60
        context.insert(plan)

        insertBeforeSurgery(into: context, plan: plan)
        insertAfterSurgery(into: context, plan: plan)
        insertContacts(into: context, plan: plan)
        insertVisits(into: context, plan: plan)
        insertPapers(into: context, plan: plan, today: today)
    }

    // one paper per kind from the surgeon then every item points at its paper
    private static func insertPapers(into context: ModelContext, plan: CarePlan, today: Date) {
        let calendar = Calendar.current
        // the before paper was printed at the pre-op visit and the after paper on discharge
        let before = Paper(kind: .beforeSurgery, source: .surgeryTeam,
                           printedDate: calendar.date(byAdding: .day, value: -5, to: today))
        let after = Paper(kind: .afterSurgery, source: .surgeryTeam, printedDate: plan.surgeryDate)
        for paper in [before, after] {
            context.insert(paper)
            paper.plan = plan
        }
        func id(_ kind: PaperKind) -> UUID { kind == .beforeSurgery ? before.id : after.id }
        for item in plan.medicines { item.paperID = id(item.paper) }
        for item in plan.rules { item.paperID = id(item.paper) }
        for item in plan.tasks { item.paperID = id(item.paper) }
        for item in plan.appointments { item.paperID = id(item.paper) }
        for item in plan.documents { item.paperID = id(item.paper) }
    }

    // MARK: - Before surgery (from the HSS page, line by line)

    // before surgery: what to stop and when, from the hss page
    private static func insertBeforeSurgery(into context: ModelContext, plan: CarePlan) {

        // 1 "Seven days prior to your surgery do not take Regular Aspirin"
        let aspirin = MedicineInstruction(
            name: "Aspirin 325 mg",
            action: .stop,
            paper: .beforeSurgery,
            quote: "Regular Aspirin (325mg) baby aspirin 81mg is permitted if instructed by your doctor."
        )
        aspirin.alsoKnownAs = ["aspirin", "bayer", "ecotrin"]
        aspirin.startDay = -7
        aspirin.reason = "These cause blood thinning."
        aspirin.exception = "Baby aspirin 81 mg is permitted if instructed by your doctor."
        aspirin.quotePage = 1
        add(aspirin, to: plan, in: context)

        // "Vitamins including Multivitamins"
        let supplements = MedicineInstruction(
            name: "Vitamins and supplements",
            action: .stop,
            paper: .beforeSurgery,
            quote: "All Vitamins/Supplements including Glucosamine/Chondroitin, Fish Oil Gingko, Garlic, Ginger or Ginseng"
        )
        supplements.isGroup = true
        supplements.alsoKnownAs = ["multivitamin", "vitamins", "glucosamine", "chondroitin", "fish oil", "omega 3", "gingko", "ginkgo", "garlic", "ginger", "ginseng"]
        supplements.startDay = -7
        supplements.reason = "These cause blood thinning."
        supplements.quotePage = 1
        add(supplements, to: plan, in: context)

        // 2 "Four days prior do not take Motrin or Advil"
        let ibuprofenStop = MedicineInstruction(name: "Ibuprofen", action: .stop, paper: .beforeSurgery, quote: "Motrin or Advil (ibuprofen)")
        ibuprofenStop.alsoKnownAs = ["motrin", "advil", "ibuprofen"]
        ibuprofenStop.startDay = -4
        ibuprofenStop.reason = "These cause blood thinning."
        ibuprofenStop.quotePage = 1
        add(ibuprofenStop, to: plan, in: context)

        let naproxen = MedicineInstruction(name: "Naproxen", action: .stop, paper: .beforeSurgery, quote: "Aleve or Naprosyn (naproxen)")
        naproxen.alsoKnownAs = ["aleve", "naprosyn", "naproxen"]
        naproxen.startDay = -4
        naproxen.reason = "These cause blood thinning."
        naproxen.quotePage = 1
        add(naproxen, to: plan, in: context)

        let otherNSAIDs = MedicineInstruction(name: "Any other NSAID", action: .stop, paper: .beforeSurgery, quote: "Any other NSAID")
        otherNSAIDs.isGroup = true
        otherNSAIDs.alsoKnownAs = ["nsaid", "celecoxib", "celebrex", "meloxicam", "mobic", "diclofenac", "voltaren", "indomethacin"]
        otherNSAIDs.startDay = -4
        otherNSAIDs.reason = "These cause blood thinning."
        otherNSAIDs.quotePage = 1
        add(otherNSAIDs, to: plan, in: context)

        // 3 "Tylenol is OK to take before surgery if you need something for pain."
        let tylenolOK = MedicineInstruction(
            name: "Acetaminophen",
            action: .okToTake,
            paper: .beforeSurgery,
            quote: "Tylenol (acetaminophen) is OK to take before surgery if you need something for pain."
        )
        tylenolOK.alsoKnownAs = ["tylenol", "acetaminophen", "paracetamol"]
        tylenolOK.endDay = -1
        tylenolOK.onlyIf = "You need something for pain"
        tylenolOK.quotePage = 1
        add(tylenolOK, to: plan, in: context)

        // 4 "Bring any inhalers eye drops or creams to the hospital unless"
        let bring = CareTask(
            title: "Bring your inhalers, eye drops and creams to the hospital",
            dueDay: 0,
            paper: .beforeSurgery,
            quote: "Bring any inhalers, eye drops or creams to the hospital unless otherwise instructed by the HSS pharmacy"
        )
        bring.quotePage = 1
        context.insert(bring)
        bring.plan = plan

        // 5 "Viagra & Cialis stop 1 day before surgery"
        let viagra = MedicineInstruction(name: "Sildenafil", action: .stop, paper: .beforeSurgery, quote: "Viagra (sildenafil) & Cialis (tadalafil): stop 1 day before surgery")
        viagra.alsoKnownAs = ["viagra", "sildenafil", "revatio"]
        viagra.startDay = -1
        viagra.quotePage = 1
        add(viagra, to: plan, in: context)

        let cialis = MedicineInstruction(name: "Tadalafil", action: .stop, paper: .beforeSurgery, quote: "Viagra (sildenafil) & Cialis (tadalafil): stop 1 day before surgery")
        cialis.alsoKnownAs = ["cialis", "tadalafil"]
        cialis.startDay = -1
        cialis.quotePage = 1
        add(cialis, to: plan, in: context)

        // the page's text so Ask can search it
        let page = SourceDocument(
            pageNumber: 1,
            paper: .beforeSurgery,
            redactedText: "AFTER VISIT SUMMARY. Directions for Your Medications Preoperatively. 1. Seven (7) days prior to your surgery, do not take the following medications and supplements (these cause blood thinning): Regular Aspirin (325mg) baby aspirin 81mg is permitted if instructed by your doctor. Vitamins including Multivitamins. All Vitamins/Supplements including Glucosamine/Chondroitin, Fish Oil Gingko, Garlic, Ginger or Ginseng. 2. Four (4) days prior to your joint replacement surgery, do not take the following medications (these cause blood thinning): Motrin or Advil (ibuprofen). Aleve or Naprosyn (naproxen). Any other NSAID. 3. Tylenol (acetaminophen) is OK to take before surgery if you need something for pain. 4. Bring any inhalers, eye drops or creams to the hospital unless otherwise instructed by the HSS pharmacy. 5. Viagra (sildenafil) & Cialis (tadalafil): stop 1 day before surgery. Today's Visit: Blood Pressure 158/88, Pulse 66, Temperature 98.3 F, Oxygen Saturation 98%."
        )
        context.insert(page)
        page.plan = plan
    }

    // MARK: - After surgery (MADE UP: a typical knee replacement discharge)

    // after surgery: pain medicines, blood thinner, restarts and rules
    private static func insertAfterSurgery(into context: ModelContext, plan: CarePlan) {

        let acetaminophen = MedicineInstruction(name: "Acetaminophen", action: .take, paper: .afterSurgery, quote: "Acetaminophen 1000 mg by mouth every 8 hours for pain.")
        acetaminophen.alsoKnownAs = ["tylenol", "acetaminophen"]
        acetaminophen.strength = "500 mg"
        acetaminophen.amount = "2 tablets"
        acetaminophen.timesOfDay = [360, 840, 1320]          // 6 AM, 2 PM, 10 PM
        acetaminophen.startDay = 1
        acetaminophen.endDay = 14
        acetaminophen.pillShape = "oval"
        acetaminophen.pillColor = "white"
        add(acetaminophen, to: plan, in: context)

        let aspirinAfter = MedicineInstruction(name: "Aspirin 81 mg", action: .take, paper: .afterSurgery, quote: "Aspirin 81 mg by mouth twice a day for 35 days to prevent blood clots.")
        aspirinAfter.alsoKnownAs = ["aspirin", "baby aspirin"]
        aspirinAfter.strength = "81 mg"
        aspirinAfter.amount = "1 tablet"
        aspirinAfter.timesOfDay = [480, 1200]                // 8 AM, 8 PM
        aspirinAfter.startDay = 1
        aspirinAfter.endDay = 35
        aspirinAfter.reason = "Prevents blood clots after surgery."
        aspirinAfter.pillShape = "round"
        aspirinAfter.pillColor = "orange"
        add(aspirinAfter, to: plan, in: context)

        let oxycodone = MedicineInstruction(name: "Oxycodone", action: .takeAsNeeded, paper: .afterSurgery, quote: "Oxycodone 5 mg every 6 hours as needed for severe pain. Do not drive.")
        oxycodone.strength = "5 mg"
        oxycodone.amount = "1 tablet"
        oxycodone.onlyIf = "Severe pain that other medicines don’t help"
        oxycodone.minHoursBetween = 6
        oxycodone.maxPerDay = 4
        oxycodone.startDay = 1
        oxycodone.endDay = 10
        add(oxycodone, to: plan, in: context)

        let noDriving = CareRule(title: "No driving", isAllowed: false, paper: .afterSurgery, quote: "Do not drive while taking narcotic pain medicine.")
        noDriving.condition = "While you take oxycodone"
        context.insert(noDriving)
        noDriving.plan = plan

        let shower = CareRule(title: "Showers", isAllowed: true, paper: .afterSurgery, quote: "You may shower 3 days after surgery. Keep the dressing dry.")
        shower.startDay = 3
        context.insert(shower)
        shower.plan = plan

        // fasting rules so surgery day and the night before have rules of their own
        let noEating = CareRule(title: "Nothing to eat after midnight", isAllowed: false, paper: .beforeSurgery,
                                quote: "Eating: Nothing to eat after midnight the night before surgery.")
        noEating.condition = "The night before surgery"
        noEating.startDay = -1
        noEating.endDay = 0
        context.insert(noEating)
        noEating.plan = plan

        let clearLiquids = CareRule(title: "Clear liquids until 2 hours before you arrive", isAllowed: true, paper: .beforeSurgery,
                                    quote: "You may drink clear liquids (water, apple juice) until 2 hours before your arrival time.")
        clearLiquids.startDay = 0
        clearLiquids.endDay = 0
        context.insert(clearLiquids)
        clearLiquids.plan = plan

        let walk = DailyGoal(title: "Walk", symbol: "figure.walk", target: 3)
        walk.detail = "Short walks with your walker"
        walk.startDay = 1
        context.insert(walk)
        walk.plan = plan

        let exercises = DailyGoal(title: "Knee exercises", symbol: "figure.strengthtraining.functional", target: 2)
        exercises.detail = "The exercises from your physical therapist"
        exercises.startDay = 1
        context.insert(exercises)
        exercises.plan = plan

        let book = CareTask(title: "Call to book your check-up for 2 weeks after surgery", dueDay: 2, paper: .afterSurgery, quote: "Follow up with your surgeon in 2 weeks. Call the office to schedule.")
        context.insert(book)
        book.plan = plan
    }

    // MARK: - Contacts (made up)

    private static func insertContacts(into context: ModelContext, plan: CarePlan) {
        let surgeonOffice = CareContact(name: "Surgeon’s office", detail: "Questions about your surgery", phone: "2015550142", role: .careTeam)
        context.insert(surgeonOffice)
        surgeonOffice.plan = plan

        let pharmacy = CareContact(name: "Hospital pharmacy", detail: "Questions about your medicines", phone: "2015550143", role: .pharmacy)
        context.insert(pharmacy)
        pharmacy.plan = plan
    }

    // MARK: - Visits (MADE UP, DEMO ONLY)

    private static func insertVisits(into context: ModelContext, plan: CarePlan) {
        guard let surgeryDate = plan.surgeryDate else { return }

        // day before surgery 2 PM the nurse calls with your arrival time
        let call = Appointment(title: "Pre-surgery phone call", date: DayMath.date(forDay: -1, minute: 840, from: surgeryDate),
                               paper: .beforeSurgery, quote: "A nurse will call you the day before surgery with your arrival time.")
        call.purpose = "A nurse tells you what time to arrive and when to stop eating and drinking."
        call.phone = "2015550142"
        call.questions = ["What time should I arrive?", "When do I stop eating and drinking?", "Which morning medicines can I take?"]
        context.insert(call)
        call.plan = plan

        // day 5 11 AM first outpatient physical therapy
        let therapy = Appointment(title: "Physical therapy", date: DayMath.date(forDay: 5, minute: 660, from: surgeryDate),
                                  paper: .afterSurgery, quote: "Begin outpatient physical therapy within one week of surgery.")
        therapy.doctor = "Jordan Lee, PT"
        therapy.place = "Outpatient Rehab Center"
        therapy.address = "1 Main Street, Hackensack, NJ"
        therapy.phone = "2015550144"
        therapy.purpose = "Your first session to get your knee bending and to plan your exercises at home."
        therapy.bring = ["Loose shorts or pants", "Comfortable shoes", "Your walker", "Your medicine list"]
        therapy.questions = ["How far should I bend my knee each day?", "Should I take pain medicine before exercises?", "When can I stop using the walker?"]
        context.insert(therapy)
        therapy.plan = plan

        // day 14 9:30 AM wound check with the surgeon
        let checkUp = Appointment(title: "Check-up with your surgeon", date: DayMath.date(forDay: 14, minute: 570, from: surgeryDate),
                                  paper: .afterSurgery, quote: "Follow up with your surgeon in 2 weeks. Call the office to schedule.")
        checkUp.doctor = "Your surgeon"
        checkUp.place = "Surgeon\u{2019}s office"
        checkUp.address = "30 Prospect Avenue, Hackensack, NJ"
        checkUp.phone = "2015550142"
        checkUp.purpose = "Your surgeon checks how the cut is healing and may take out stitches or staples."
        checkUp.bring = ["Your medicine list", "Your insurance card", "A list of questions"]
        checkUp.questions = ["Is my wound healing well?", "When can I drive again?", "When can I go back to work or school?"]
        context.insert(checkUp)
        checkUp.plan = plan
    }

    // MARK: - Helper

    // insert first then link to the plan
    private static func add(_ medicine: MedicineInstruction, to plan: CarePlan, in context: ModelContext) {
        context.insert(medicine)
        medicine.plan = plan
    }
}
