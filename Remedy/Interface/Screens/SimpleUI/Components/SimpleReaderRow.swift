//
//  SimpleReaderRow.swift
//  Remedy
//
//  simple look row on the first screens: how papers are read, opens the model choice in a sheet
//

import SwiftUI

// simple row for who reads the papers
struct SimpleReaderRow: View {
    // told when the sheet closes so the scan flow reloads its copy
    var onChange: () -> Void = {}

    // UI only the sheet and the pick shown on the second line
    @State private var isShowing = false
    @State private var settings = ModelSettings.load(from: .standard)

    var body: some View {
        Button { isShowing = true } label: {
            HStack(spacing: 14) {
                ItemIconTile(kind: .custom(symbol: "slider.horizontal.3", tone: .info), size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(SimpleReaderRowWords.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                    Text(SimpleReaderRowWords.current(settings))
                        .font(.body)
                        .foregroundStyle(Color.ink2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                Chevron()
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: Spacing.tapSimple, alignment: .leading)
            .cardStyle()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(SimpleReaderRowWords.hint)
        .accessibilityIdentifier("welcome-reader")
        .onAppear { settings = ModelSettings.load(from: .standard) }
        .sheet(isPresented: $isShowing, onDismiss: {
            settings = ModelSettings.load(from: .standard)
            onChange()
        }) {
            NavigationStack { SimpleReaderChoiceView() }
        }
    }
}
