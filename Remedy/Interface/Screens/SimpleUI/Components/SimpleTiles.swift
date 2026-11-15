//
//  SimpleTiles.swift
//  Remedy
//
//  simple look tiles, the undo card and the fit scroll
//

import SwiftData
import SwiftUI

// MARK: - Undo

// "Marked as taken" with a big Undo, for a few seconds after a change
struct SimpleUndoCard: View {
    let undo: TodayUndo
    let onUndo: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(undo.message, systemImage: "checkmark.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(Color.accentInk)
            HStack(spacing: 12) {
                Button("Undo", action: onUndo)
                    .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
                Button("OK", action: onClose)
                    .buttonStyle(SimpleButtonStyle(height: 56))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .simpleToneCard(.accentSoft)
        .accessibilityElement(children: .contain)
    }
}

// a big white tile, icon over the word, stacks to one per row at the largest text sizes
struct SimpleBigTile: View {
    let title: String
    let symbol: String
    var tint: Color = .accentInk

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 104)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.cardBackground))
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// two tiles a row, one a row at accessibility sizes
struct SimpleTileGrid<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let columns = typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        LazyVGrid(columns: columns, spacing: 12) { content }
    }
}

// a small square with the speaker over "Read Aloud"
struct ReadAloudTile: View {
    let text: String
    var title: String = "Read Aloud"

    private var speaker: SpeakerState { Speaker.state }

    var body: some View {
        Button {
            Speaker.toggle(text)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: speaker.isSpeaking ? "stop.fill" : "speaker.wave.2")
                    .font(.body.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .fixedSize()
            }
            .foregroundStyle(Color.accentInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: Spacing.minTarget, minHeight: Spacing.minTarget)
            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.cardBackground))
        }
        .buttonStyle(.plain)
        // stays a small button, the words are read out anyway
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityLabel(speaker.isSpeaking ? "Stop reading" : title)
        .accessibilityHint("Reads this screen out loud.")
    }
}

extension View {
    // white card, with the teal outline when it is the thing to do now
    func simpleOutlineCard(isNext: Bool = true, tone: Tone? = nil) -> some View {
        let fill: Color = tone.map { $0 == .neutral ? Color.cardBackground : $0.soft } ?? Color.cardBackground
        return self
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(fill))
            .overlay {
                if isNext {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Color.accentFill, lineWidth: 2)
                }
            }
    }
}

// the patient's text size when it fits, one step smaller next, then it scrolls
struct SimpleFitScroll<Content: View>: View {
    let content: Content

    @Environment(\.dynamicTypeSize) private var typeSize

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(Array(SimpleFitSteps.sizes(from: typeSize).prefix(2)), id: \.self) { size in
                content
                    .dynamicTypeSize(size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            ScrollView {
                content
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

// arrival time and hospital in a full sheet that scrolls, so the keyboard never hides a field or Done
struct SimpleHospitalSheet: View {
    let plan: CarePlan?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    static let title = "Surgery day details"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                    if let plan {
                        HospitalDayFields(plan: plan, simple: true)
                            .padding(Spacing.insideCard)
                            .cardStyle()
                    }
                }
                .padding(.horizontal, Spacing.simpleEdge)
                .padding(.top, 8)
                .padding(.bottom, Spacing.sectionGap)
            }
            .scrollDismissesKeyboard(.interactively)
            .remedyBackground()
            .navigationTitle(Self.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // done stays at the top, never under the keyboard
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { finish() }
                        .font(.title3.bold())
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .presentationDetents([.large])
    }

    // typed words are kept as they are typed, done saves and closes
    private func finish() {
        context.saveNow()
        dismiss()
    }
}

