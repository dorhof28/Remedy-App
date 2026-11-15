//
//  PaperIntakeRunner.swift
//  Remedy
//
//  starts the camera, photo picker, Files picker or an import once the patient has said
//  where the papers come from and which papers they are, used by both looks
//

import AuthenticationServices
import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers     // .pdf for the Files picker

// opens the camera, photos or files the scan flow asked for and hands back the pages
struct PaperIntakeRunner: ViewModifier {
    @Bindable var viewModel: ScanFlowViewModel
    // set this to start the chosen way, it clears itself
    @Binding var request: PaperIntake?

    // apple's secure sign-in sheet for MyChart
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    // UI only which picker is open
    @State private var isShowingCamera = false
    @State private var isChoosingPhotos = false
    @State private var isChoosingPDF = false
    // UI only the camera reason before apple's prompt, and the way out after a no
    @State private var isShowingCameraPrimer = false
    @State private var isShowingCameraOff = false

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, source in
                guard let source else { return }
                request = nil
                switch source {
                case .camera: openCamera()
                case .photos: isChoosingPhotos = true
                case .pdf: isChoosingPDF = true
                case .myChart: Task { await viewModel.importFromEpic(using: webAuthenticationSession) }
                case .health: Task { await viewModel.importFromHealth() }
                case .sample: Task { await viewModel.useSamplePapers() }
                }
            }
            .photosPicker(isPresented: $isChoosingPhotos, selection: $viewModel.photoItems,
                          maxSelectionCount: 10, matching: .images)
            .onChange(of: viewModel.photoItems.count) { _, count in
                if count > 0 { Task { await viewModel.processPhotos() } }
            }
            .fileImporter(isPresented: $isChoosingPDF, allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result {
                    Task { await viewModel.processPDF(at: url) }
                }
            }
            .fullScreenCover(isPresented: $isShowingCameraPrimer) {
                PermissionPrimerView(text: .camera) {
                    Task {
                        let allowed = await AVCaptureDevice.requestAccess(for: .video)
                        isShowingCameraPrimer = false
                        if allowed { isShowingCamera = true } else { isShowingCameraOff = true }
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingCameraOff) {
                PermissionOffView(text: .camera, onOtherWay: {
                    isShowingCameraOff = false
                    viewModel.begin()
                }, onBack: { isShowingCameraOff = false })
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

extension PaperIntakeRunner {
    // the camera asks only once Scan is tapped, with its own reason first
    private func openCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: isShowingCamera = true
        case .notDetermined: isShowingCameraPrimer = true
        default: isShowingCameraOff = true
        }
    }
}

extension View {
    // see PaperIntakeRunner
    func paperIntake(_ viewModel: ScanFlowViewModel, request: Binding<PaperIntake?>) -> some View {
        modifier(PaperIntakeRunner(viewModel: viewModel, request: request))
    }
}
