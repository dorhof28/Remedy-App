//
//  FamilyShareView.swift
//  Remedy
//
//  classic share and print any page for any day
//

import SwiftUI
import SwiftData

struct FamilyShareView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.dismiss) private var dismiss

    // UI only which page and day and the finished PDF
    @State private var kind: PrintKind = .family
    @State private var day = AppClock.now()
    @State private var pdfURL: URL?
    @State private var didFail = false

    var body: some View {
        let viewModel = FamilyShareViewModel(plan: plans.first, now: day, kind: kind)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                    Text(viewModel.intro)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker(viewModel.title, selection: $kind) {
                        ForEach(PrintKind.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(kind.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if kind.usesDay {
                        DatePicker(viewModel.dayLabel, selection: $day, in: viewModel.dayRange, displayedComponents: .date)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: .capsule)
                    }

                    FamilySheetPreview(sheet: viewModel.sheet)
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.vertical, 8)
            }
            .background(Color.screenBackground)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.doneTitle) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                FamilyShareButton(url: pdfURL, didFail: didFail, viewModel: viewModel)
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
            // a new PDF each time the page or day changes
            .task(id: "\(kind.rawValue)-\(day.timeIntervalSince1970)") {
                pdfURL = nil
                pdfURL = viewModel.makePDF()
                didFail = pdfURL == nil
            }
        }
    }
}

// the big "Send or print" button
struct FamilyShareButton: View {
    let url: URL?
    let didFail: Bool
    let viewModel: FamilyShareViewModel

    var body: some View {
        if let url {
            ShareLink(item: url, preview: SharePreview(viewModel.fileName, image: Image(systemName: "doc.richtext"))) {
                Label(viewModel.shareTitle, systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.remedyTeal)
        } else if didFail {
            Text(viewModel.failedText)
                .foregroundStyle(Tone.stop.color)
                .frame(maxWidth: .infinity, minHeight: 50)
        } else {
            HStack(spacing: 10) {
                ProgressView()
                Text(viewModel.makingText)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
    }
}

#Preview(traits: .afterSurgerySample) {
    FamilyShareView()
}
