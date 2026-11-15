//
//  SimpleReadyView.swift
//  Remedy
//
//  simple ready for surgery list, one item per line
//

import SwiftUI

// simple ready for surgery list
struct SimpleReadyView: View {
    let list: ReadyList

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(list.title)
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            ForEach(list.items) { item in
                HStack(spacing: 14) {
                    Image(systemName: item.symbol)
                        .font(.largeTitle)
                        .foregroundStyle(item.tone.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.title3.bold())
                        Text(item.text).font(.body).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(item.spokenLabel)
            }
            ForEach(list.fastingLines, id: \.self) { line in
                Label(line, systemImage: "fork.knife")
                    .font(.title3.bold())
            }
            ForEach(list.timeLines, id: \.self) { line in
                Label(line, systemImage: "clock")
                    .font(.title3.bold())
            }
            Text(list.footer)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }
}
