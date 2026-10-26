//
//  WelcomeView.swift
//  Remedy
//
//  first screen and choosing papers
//

import AuthenticationServices
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers     // .pdf for the Files picker

struct WelcomeView: View {
    let viewModel: ScanFlowViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                TopCard(title: viewModel.appName, subtitle: viewModel.welcomeTitle) {
                    // the app icon
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .accessibilityHidden(true)
                }
                .padding(.top, 32)

                Text(viewModel.welcomeDetail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 0) {
                    ForEach(viewModel.features) { feature in
                        IconRow(symbol: feature.symbol, tone: .info, title: feature.title,
                                subtitle: feature.detail, iconSize: 40)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.scrollBottom)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    viewModel.begin()
                } label: {
                    Text(viewModel.welcomeButton)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Label(viewModel.welcomePrivacy, systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.screenEdge)
            .background(.bar)
        }
    }
}

// MARK: - Which papers? + how to scan

// pick papers and how to add them
struct ChoosePaperView: View {
    @Bindable var viewModel: ScanFlowViewModel

    // UI only is the camera open
    @State private var isShowingCamera = false
    // UI only is the Files picker open
    @State private var isChoosingPDF = false
    // apple's secure sign-in sheet for MyChart
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.betweenCards) {
                if let error = viewModel.errorText {
                    ToneBox(eyebrow: "Try again", title: error, tone: .caution)
                }

                SectionCard(title: viewModel.choosePaperTitle, symbol: "doc.on.doc",
                            collapsible: false, rememberAs: "scan.paper") {
                    DividedList(items: viewModel.paperOptions, inset: 52) { option in
                        Button {
                            withAnimation { viewModel.choose(option.id) }
                        } label: {
                            HStack(spacing: 12) {
                                IconRow(symbol: option.symbol, title: option.title, subtitle: option.detail, iconSize: 40)
                                Image(systemName: viewModel.paper == option.id ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(viewModel.paper == option.id ? Color.remedyTeal : Color.inactive)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(viewModel.paper == option.id ? .isSelected : [])
                    }
                }

                // names typed here are always hidden on the phone
                SectionCard(title: viewModel.namesTitle, symbol: "eye.slash",
                            collapsible: false, rememberAs: "scan.names") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(viewModel.namesPrompt, text: $viewModel.namesToHide)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                            .font(.body)
                            .padding(.vertical, 8)
                        Text(viewModel.namesFooter)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.top, 8)
        }
        .navigationTitle(viewModel.choosePaperTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if viewModel.canUseCamera {
                    Button {
                        isShowingCamera = true
                    } label: {
                        Label(viewModel.cameraButton, systemImage: "camera.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }

                PhotosPicker(selection: $viewModel.photoItems, maxSelectionCount: 10, matching: .images) {
                    Label(viewModel.photosButton, systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                Button {
                    isChoosingPDF = true
                } label: {
                    Label(viewModel.pdfButton, systemImage: "doc.richtext")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                if viewModel.showsEpicButton {
                    Button {
                        Task { await viewModel.importFromEpic(using: webAuthenticationSession) }
                    } label: {
                        if viewModel.isImportingFromEpic {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(viewModel.epicButton, systemImage: "building.columns")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.glass)
                    .disabled(viewModel.isImportingFromEpic)
                }

                if viewModel.showsHealthButton {
                    Button {
                        Task { await viewModel.importFromHealth() }
                    } label: {
                        if viewModel.isImportingFromHealth {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(viewModel.healthButton, systemImage: "heart.text.square")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.glass)
                    .disabled(viewModel.isImportingFromHealth)
                }

                // DEMO ONLY
                if viewModel.showsSampleButton {
                    Button {
                        Task { await viewModel.useSamplePapers() }
                    } label: {
                        Label(viewModel.sampleButton, systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)

                    Button {
                        viewModel.useSampleMyChart()
                    } label: {
                        Label(viewModel.sampleMyChartButton, systemImage: "building.columns")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
            .controlSize(.large)
            .padding(Spacing.screenEdge)
            .background(.bar)
        }
        .fileImporter(isPresented: $isChoosingPDF, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result {
                Task { await viewModel.processPDF(at: url) }
            }
        }
        .onChange(of: viewModel.photoItems.count) { _, count in
            if count > 0 { Task { await viewModel.processPhotos() } }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            DocumentScanner { images in
                isShowingCamera = false
                Task { await viewModel.process(images: images) }
            } onCancel: {
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
    }
}
