//
//  LocalModelList.swift
//  Remedy
//
//  the ai models that can be downloaded to this iphone with their size, what each can do,
//  a live download bar, cancel, retry and delete, one view for both looks
//

import SwiftUI

// models to download and run on this phone, with progress and delete
struct LocalModelList: View {
    enum Show { case all, downloaded, available }

    let store: LocalModelStore
    var isSimple = false
    var show: Show = .all

    @State private var deleting: LocalModel?

    private var models: [LocalModel] {
        LocalModel.allCases.filter(\.fitsThisPhone).filter { model in
            switch show {
            case .all: return true
            case .downloaded: return store.state(model) == .ready
            case .available: return store.state(model) != .ready
            }
        }
    }

    var body: some View {
        if models.isEmpty {
            Label(show == .downloaded ? "Nothing downloaded yet." : ReaderSetupViewModel.noModelsText,
                  systemImage: show == .downloaded ? "arrow.down.circle" : "iphone.slash")
                .font(isSimple ? .body : .subheadline)
                .foregroundStyle(Color.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(isSimple ? 18 : Spacing.insideCard)
                .cardStyle()
        } else {
            Group {
                if isSimple {
                    VStack(spacing: Spacing.betweenCards) {
                        ForEach(models) { model in
                            row(model)
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardStyle()
                        }
                    }
                } else {
                    GroupedCard {
                        ForEach(models) { model in
                            row(model).padding(.vertical, 8)
                        }
                    }
                }
            }
            .confirmationDialog("Delete \(deleting?.displayName ?? "")?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let deleting { store.delete(deleting) }
                }
            } message: {
                Text("This frees \(deleting?.sizeText ?? "") of space. You can download it again any time.")
            }
        }
    }

    // total space the downloaded models use
    static func usedText(_ store: LocalModelStore) -> String {
        let bytes = LocalModel.allCases.filter { store.state($0) == .ready }.reduce(Int64(0)) { $0 + $1.bytes }
        return bytes == 0 ? "" : ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) + " used"
    }

    private func row(_ model: LocalModel) -> some View {
        let isReady = store.state(model) == .ready
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: isSimple ? 14 : 12) {
                ItemIconTile(kind: isReady ? .custom(symbol: "iphone", tone: .neutral) : .goal(symbol: "arrow.down.circle"),
                             size: isSimple ? 48 : Spacing.iconTile)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(isSimple ? Font.title3.weight(.bold) : .body.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    // size and what it can do
                    Text("\(model.sizeText) \u{00B7} \(model.purpose)")
                        .font(isSimple ? .body : .subheadline)
                        .foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isReady {
                    Button(ReaderSetupViewModel.deleteButton) { deleting = model }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(Capsule().fill(Color.surface2))
                        .frame(minHeight: Spacing.tapMin)
                        .accessibilityLabel("Delete \(model.displayName), frees \(model.sizeText)")
                }
            }
            .accessibilityElement(children: .contain)
            if !isReady {
                ModelDownloadView(model: model, store: store, isSimple: isSimple)
            }
        }
    }
}
