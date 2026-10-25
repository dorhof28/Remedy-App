//
//  TodayCards.swift
//  Remedy
//
//  cards for the today view
//

import SwiftUI

// MARK: - Header

// surgery in 4 days header
struct TodayHeader: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, tone: .info, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                    .contentTransition(.numericText())
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// card with a list of today rows
struct RowListCard: View {
    let title: String
    let rows: [TodayRow]
    var footer: String = ""

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(rows) { row in
                    TodayRowView(row: row)
                }
                if !footer.isEmpty {
                    Text(footer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// one today row
struct TodayRowView: View {
    let row: TodayRow

    var body: some View {
        HStack(spacing: 12) {
            MedicineIcon(pillShape: row.pillShape, pillColor: row.pillColor,
                         symbol: row.symbol, tone: row.tone, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.body)
                if !row.detail.isEmpty {
                    Text(row.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenLabel)
    }
}

// to do card
struct TaskListCard: View {
    let title: String
    let rows: [TaskRow]
    let onToggle: (TaskRow) -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(rows) { row in
                    Button {
                        onToggle(row)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: row.checkSymbol)
                                .font(.title2)
                                .foregroundStyle(row.checkTone.color)
                                .contentTransition(.symbolEffect(.replace))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .strikethrough(row.isDone)
                                    .foregroundStyle(row.isDone ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                                Text(row.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: Spacing.minTarget)
                        .contentShape(Rectangle())     // the whole row is tappable not js item
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(row.spokenLabel)
                    .accessibilityHint(row.spokenHint)
                    .sensoryFeedback(.success, trigger: row.isDone) { _, isDone in isDone }
                }
            }
        }
    }
}

// allows undos a little after
struct UndoBar: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Label(message, systemImage: "checkmark")
                .font(.subheadline.weight(.medium))
            Spacer()
            Button("Undo", action: onUndo)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: Spacing.minTarget + 4)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
    }
}
