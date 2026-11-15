//
//  PhotoQuickAddView.swift
//  Remedy
//
//  classic quick add photo sheet and the strip of latest photos
//

import SwiftUI
import SwiftData
import PhotosUI

// take or pick a photo and add it to a series
struct PhotoQuickAddSheet: View {
    var note: String = ""

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PhotoTrack.createdAt) private var tracks: [PhotoTrack]

    // UI only
    @State private var model: PhotoQuickAddViewModel
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @FocusState private var focus: Field?

    private enum Field { case newName, note }

    init(note: String = "") {
        self.note = note
        _model = State(initialValue: PhotoQuickAddViewModel(note: note))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                    TodayCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(PhotoQuickAddViewModel.trackTitle).font(.headline)
                            if !tracks.isEmpty {
                                ForEach(tracks) { track in
                                    Button {
                                        model.newName = ""
                                        model.selectedID = track.id
                                        focus = nil
                                    } label: {
                                        HStack {
                                            Text(track.name)
                                            Spacer(minLength: 0)
                                            if model.isPicked(track, in: tracks) {
                                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.remedyTeal)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(model.isPicked(track, in: tracks) ? .isSelected : [])
                                }
                            }
                            TextField(PhotoQuickAddViewModel.newTrackPrompt, text: $model.newName)
                                .focused($focus, equals: .newName)
                                .submitLabel(.next)
                                .onSubmit { focus = .note }
                                .textInputAutocapitalization(.sentences)
                        }
                    }

                    TodayCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(PhotoQuickAddViewModel.noteTitle).font(.headline)
                            TextField("Note", text: $model.note, axis: .vertical)
                                .lineLimit(1...4)
                                .focused($focus, equals: .note)
                                .submitLabel(.done)
                                .onSubmit { focus = nil }
                        }
                    }
                    .id(Field.note)

                    VStack(spacing: 10) {
                        if PhotoCamera.isAvailable {
                            Button { focus = nil; isShowingCamera = true } label: {
                                Label(PhotoQuickAddViewModel.takeTitle, systemImage: "camera")
                            }
                            .buttonStyle(RemedyButtonStyle(kind: .primary))
                            .disabled(!model.canAdd(tracks: tracks))
                        }
                        PhotosPicker(selection: $pickerItems, matching: .images) {
                            Label(PhotoQuickAddViewModel.chooseTitle, systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(RemedyButtonStyle(kind: PhotoCamera.isAvailable ? .secondary : .primary))
                        .disabled(!model.canAdd(tracks: tracks))
                    }

                    Text(PhotoTrackViewModel.noComment)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, Spacing.scrollBottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .remedyBackground()
            .navigationTitle(PhotoQuickAddViewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                PhotoCamera { image in
                    isShowingCamera = false
                    if let data = PhotoTrackViewModel.jpegData(from: image), model.add(data: data, tracks: tracks, in: context) {
                        dismiss()
                    }
                } onCancel: { isShowingCamera = false }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    var added = false
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data),
                           let small = PhotoTrackViewModel.jpegData(from: image) {
                            added = model.add(data: small, tracks: tracks, in: context) || added
                        }
                    }
                    pickerItems = []
                    if added { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
