//
//  SharePlanSheet.swift
//  Remedy
//
//  share plan (51, 102): pick a kind and its options, then the preview (103) and the share sheet
//

import SwiftUI
import SwiftData
import PDFKit

// classic share: pick a kind, see the pages, make the pdf
struct SharePlanSheet: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.dismiss) private var dismiss

    // UI only the kind, the day and the parts left off
    @State private var choice: ShareChoice = .fullPlan
    @State private var day = AppClock.now()
    @State private var leftOff: Set<PrintPart>
    @State private var isPreviewing = false
    @State private var isAddingPapers = false

    // check-ins opens it with check-ins already on
    init(startsOff: Set<PrintPart> = FamilyShareViewModel.planStartsOff) {
        _leftOff = State(initialValue: startsOff)
    }

    var body: some View {
        let viewModel = SharePlanViewModel(plan: plans.first, now: AppClock.now(), choice: choice, day: day, leftOff: leftOff)
        NavigationStack {
            Group {
                if viewModel.hasPlan {
                    pickList(viewModel)
                } else {
                    ContentUnavailableView {
                        Label(viewModel.emptyTitle, systemImage: "square.and.arrow.up")
                    } actions: {
                        PrimaryButton(title: viewModel.addPapersTitle, symbol: "doc.viewfinder") { isAddingPapers = true }
                            .padding(.horizontal, Spacing.screenEdge)
                    }
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(viewModel.cancelTitle) { dismiss() } }
            }
            .navigationDestination(isPresented: $isPreviewing) {
                SharePreviewPage(viewModel: viewModel)
            }
        }
        .fullScreenCover(isPresented: $isAddingPapers) {
            ScanFlowView(isAddingPapers: true, planHasSurgeryDate: false)
        }
    }

    private func pickList(_ viewModel: SharePlanViewModel) -> some View {
        List {
            Section {
                ForEach(ShareChoice.allCases) { item in
                    RadioRow(title: item.title, subtitle: item.subtitle ?? "", isOn: choice == item) { choice = item }
                }
            } header: {
                ListSectionHeader(title: viewModel.pickHeader)
            }
            if choice == .fullPlan {
                Section {
                    ForEach(viewModel.includeParts) { part in
                        Toggle(isOn: binding(part)) {
                            ListRow(symbol: part.symbol == "pills.fill" ? "pills" : part.symbol, title: viewModel.switchTitle(part))
                        }
                        .tint(Color.accentFill)
                    }
                } header: {
                    ListSectionHeader(title: viewModel.includeHeader)
                } footer: {
                    Text(viewModel.includeFooter).font(.footnote).foregroundStyle(Color.ink2)
                }
                nameSection(viewModel)
            } else {
                Section {
                    if viewModel.showsDayRow {
                        NavigationLink { DayPickPage(title: viewModel.dayTitle, day: $day, range: viewModel.dayRange) } label: {
                            ListRow(symbol: "calendar", title: viewModel.dayTitle, value: viewModel.dayText)
                        }
                    }
                    if viewModel.showsWeekRow {
                        NavigationLink { DayPickPage(title: viewModel.weekTitle, day: $day, range: viewModel.dayRange) } label: {
                            ListRow(symbol: "calendar", title: viewModel.weekTitle, value: viewModel.weekText)
                        }
                    }
                    if viewModel.showsPhonesSwitch {
                        Toggle(isOn: binding(.phones)) {
                            ListRow(symbol: PrintPart.phones.symbol, title: PrintPart.phones.title)
                        }
                        .tint(Color.accentFill)
                    }
                    if viewModel.printedName != nil {
                        nameToggle
                    }
                } header: {
                    ListSectionHeader(title: viewModel.optionsHeader)
                }
            }
        }
        .remedyList()
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: viewModel.makePDFTitle, symbol: "square.and.arrow.up") { isPreviewing = true }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func nameSection(_ viewModel: SharePlanViewModel) -> some View {
        if viewModel.printedName != nil {
            Section { nameToggle }
        }
    }

    private var nameToggle: some View {
        Toggle(isOn: binding(.name)) {
            ListRow(symbol: PrintPart.name.symbol, title: PrintPart.name.title)
        }
        .tint(Color.accentFill)
    }

    // on means it goes in the PDF
    private func binding(_ part: PrintPart) -> Binding<Bool> {
        Binding(get: { !leftOff.contains(part) },
                set: { if $0 { leftOff.remove(part) } else { leftOff.insert(part) } })
    }
}

// a pushed page with a calendar to pick one day of the plan
struct DayPickPage: View {
    let title: String
    @Binding var day: Date
    let range: ClosedRange<Date>

    var body: some View {
        List {
            DatePicker(title, selection: $day, in: range, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Color.accentInk)
        }
        .remedyList()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 103 Preview

// the pdf pages as they will print, swipe between them
struct SharePreviewPage: View {
    let viewModel: SharePlanViewModel
    var isSimple = false

    @State private var pdfURL: URL?
    @State private var didFail = false
    @State private var page = 1

    var body: some View {
        VStack(spacing: 10) {
            if let pdfURL {
                PDFPreview(url: pdfURL, page: $page)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                Text(viewModel.pageText(page))
                    .font(.footnote)
                    .foregroundStyle(Color.ink2)
            } else if didFail {
                Spacer()
                Label(viewModel.failedText, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color.cautionInk)
                SecondaryButton(title: viewModel.tryAgainTitle) { make() }
                Spacer()
            } else {
                Spacer()
                HStack(spacing: 10) { ProgressView(); Text(viewModel.makingText) }
                    .foregroundStyle(Color.ink2)
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.top, 8)
        .remedyBackground()
        .navigationTitle(viewModel.previewTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let pdfURL {
                ShareLink(item: pdfURL, preview: SharePreview(viewModel.fileName, image: Image(systemName: "doc.richtext"))) {
                    Label(viewModel.shareTitle, systemImage: "square.and.arrow.up")
                }
                .buttonStyle(isSimple ? AnyButtonStyle(SimpleButtonStyle()) : AnyButtonStyle(RemedyButtonStyle(kind: .primary)))
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.vertical, 10)
            }
        }
        .task(id: viewModel.pdfKey) { make() }
    }

    private func make() {
        didFail = false
        pdfURL = viewModel.makePDF()
        didFail = pdfURL == nil
    }
}

// the real pdf, pinch to zoom, and which page is showing
struct PDFPreview: UIViewRepresentable {
    let url: URL
    @Binding var page: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.changed(_:)),
                                               name: .PDFViewPageChanged, object: view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(page: $page) }

    final class Coordinator: NSObject {
        let page: Binding<Int>
        init(page: Binding<Int>) { self.page = page }
        // keeps the page number in step as the pdf scrolls
        @objc func changed(_ note: Notification) {
            guard let view = note.object as? PDFView, let current = view.currentPage,
                  let index = view.document?.index(for: current) else { return }
            page.wrappedValue = index + 1
        }
    }
}

#Preview(traits: .afterSurgerySample) {
    SharePlanSheet()
}
