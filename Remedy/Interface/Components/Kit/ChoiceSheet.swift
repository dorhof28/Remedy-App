//
//  ChoiceSheet.swift
//  Remedy
//
//  a short list of choices as icon, title and subtitle cards, like the "how to scan" sheet
//

import SwiftUI

// one choice
struct ChoiceOption: Identifiable {
    let id: String
    let symbol: String
    let title: String
    var detail = ""
}

// a short sheet of big choices, the tapped id is sent back
struct ChoiceSheet: View {
    let title: String
    let options: [ChoiceOption]
    let onPick: (String) -> Void

    @AppStorage(AppLook.storageKey) private var look: AppLook = .simple

    private var isSimple: Bool { look == .simple }

    // a plain stack so the sheet is only as tall as its choices
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(isSimple ? .title2.bold() : .headline)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Spacing.screenEdge)
                .accessibilityAddTraits(.isHeader)
            if isSimple {
                VStack(spacing: 10) {
                    ForEach(options) { option in
                        Button { onPick(option.id) } label: {
                            SimpleRowCard(title: option.title, subtitle: option.detail) {
                                ItemIconTile(kind: .goal(symbol: option.symbol), size: 48)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.screenEdge)
            } else {
                DividedList(items: options, inset: 52) { option in
                    Button { onPick(option.id) } label: {
                        ItemRow(kind: .goal(symbol: option.symbol), title: option.title, detail: option.detail) { Chevron() }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.insideCard)
                .cardStyle()
                .padding(.horizontal, Spacing.screenEdge)
            }
        }
        .compactSheet()
    }
}

// what Add offers on the Plan tab
enum PlanAddChoice {
    static let title = "Add to my plan"

    // 98 words, the row and the sheet
    static let rowTitle = "Add Something"
    static let heading = "Add to your plan"
    static let footer = "Things you add are marked \u{201C}Added by you\u{201D}."
    static let sheetOptions: [(id: String, symbol: String, title: String, detail: String)] = [
        ("paper", "camera", "Papers", "Scan or import"),
        ("visit", "calendar", "A Visit", "Date, time, place, phone"),
        ("task", "checkmark.circle", "A To-Do", "Something to do by a date"),
    ]

    static let options: [ChoiceOption] = [
        ChoiceOption(id: "visit", symbol: "stethoscope", title: "A visit"),
        ChoiceOption(id: "medicine", symbol: "pills.fill", title: "A medicine"),
        ChoiceOption(id: "task", symbol: "checklist", title: "Something to do")
    ]

    static func target(for id: String) -> PlanEditTarget? {
        switch id {
        case "visit": return .visit(nil)
        case "medicine": return .medicine(nil)
        case "task": return .task(nil)
        default: return nil
        }
    }
}
