//
//  LocalModels.swift
//  Remedy
//
//  ai models the patient downloads once and runs on this iphone with mlx
//  nothing about the papers leaves the phone, only the model files come down from hugging face
//

import Foundation
import FoundationModels
import MLX
import MLXFoundationModels
import MLXLMCommon
import MLXVLM
import Tokenizers
import os
import UIKit

// one model the patient can download
enum LocalModel: String, CaseIterable, Identifiable, Sendable {
    case glmOCR         // made only for reading documents into text with lists and tables
    case gemmaSmall     // gemma 4 e2b, reads pages and finds names
    case gemmaLarge     // gemma 4 e4b, sharper but needs a pro iphone

    var id: String { rawValue }

    nonisolated var repo: String {
        switch self {
        case .glmOCR: return "mlx-community/GLM-OCR-8bit"
        case .gemmaSmall: return "mlx-community/gemma-4-e2b-it-4bit"
        case .gemmaLarge: return "mlx-community/gemma-4-e4b-it-4bit"
        }
    }

    var displayName: String {
        switch self {
        case .glmOCR: return "GLM-OCR"
        case .gemmaSmall: return "Gemma 4"
        case .gemmaLarge: return "Gemma 4 Large"
        }
    }

    // what it is good at in plain words
    var purpose: String {
        switch self {
        case .glmOCR: return "Made for reading papers. Best with lists and tables."
        case .gemmaSmall: return "Reads papers and finds names to hide."
        case .gemmaLarge: return "The sharpest. Needs an iPhone 17 Pro or newer."
        }
    }

    // download size in bytes, close enough for the progress line and the space check
    var bytes: Int64 {
        switch self {
        case .glmOCR: return 1_590_000_000
        case .gemmaSmall: return 3_580_000_000
        case .gemmaLarge: return 5_180_000_000
        }
    }

    var sizeText: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }

    // phone memory it needs to run without being closed by ios
    var memoryNeeded: UInt64 {
        switch self {
        case .glmOCR: return 6 << 30
        case .gemmaSmall: return 8 << 30
        case .gemmaLarge: return 11 << 30
        }
    }

    // only models that can fill in a form can find names, glm only reads
    var canFindNames: Bool { self != .glmOCR }

    var configuration: ModelConfiguration {
        switch self {
        case .glmOCR: return ModelConfiguration(id: repo, extraEOSTokens: ["<|user|>", "<|endoftext|>"])
        case .gemmaSmall: return VLMRegistry.gemma4_E2B_it_4bit
        case .gemmaLarge: return VLMRegistry.gemma4_E4B_it_4bit
        }
    }

    var capabilities: [LanguageModelCapabilities.Capability] {
        canFindNames ? [.vision, .guidedGeneration] : [.vision]
    }

    // does this iphone have the memory and a real gpu
    var fitsThisPhone: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return ProcessInfo.processInfo.physicalMemory >= memoryNeeded
        #endif
    }
}

// what the patient sees for each model
enum LocalModelState: Equatable {
    case notDownloaded
    case downloading(Double)    // 0 to 1
    case ready
    case failed(String)
}

// downloads keeps and loads the models, one shared copy for the app
@MainActor @Observable
final class LocalModelStore {

    static let shared = LocalModelStore()
    nonisolated static let log = Logger(subsystem: "Remedy", category: "LocalModels")

    private(set) var states: [LocalModel: LocalModelState] = [:]
    @ObservationIgnored private var tasks: [LocalModel: Task<Void, Never>] = [:]
    @ObservationIgnored private var models: [LocalModel: MLXLanguageModel] = [:]

    init() {
        for model in LocalModel.allCases {
            states[model] = Self.isOnDisk(model) ? .ready : .notDownloaded
        }
        // a model can use gigabytes so it is let go when ios runs low and loaded again on next use
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { LocalModelStore.shared.unloadAll() }
        }
    }

    func state(_ model: LocalModel) -> LocalModelState { states[model] ?? .notDownloaded }

    func isReady(_ model: LocalModel) -> Bool { state(model) == .ready && model.fitsThisPhone }

    // the folder every model lives in, kept out of icloud backups since it can be downloaded again
    nonisolated static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Models", isDirectory: true)
    }

    // one folder per model repo
    nonisolated static func folder(for repo: String) -> URL {
        folder.appendingPathComponent(repo.replacingOccurrences(of: "/", with: "--"), isDirectory: true)
    }

    // config.json is moved in with everything else at the end so a half download never counts
    nonisolated static func isOnDisk(_ model: LocalModel) -> Bool {
        FileManager.default.fileExists(atPath: folder(for: model.repo).appendingPathComponent("config.json").path)
    }

    // starts or resumes a download, the screen shows progress from states
    func download(_ model: LocalModel) {
        guard tasks[model] == nil, state(model) != .ready else { return }
        if let free = Self.freeSpace(), free < model.bytes + 500_000_000 {
            states[model] = .failed("Not enough space. \(model.displayName) needs \(model.sizeText) free.")
            return
        }
        states[model] = .downloading(0)
        // the screen stays on while a model downloads, a locked phone stops the download
        UIApplication.shared.isIdleTimerDisabled = true
        tasks[model] = Task {
            do {
                _ = try await HubDownloader().download(id: model.repo, revision: nil, matching: Self.patterns,
                                                       useLatest: false) { progress in
                    let fraction = progress.fractionCompleted
                    Task { @MainActor in
                        // never moves back, a resumed file starts its count again
                        let store = LocalModelStore.shared
                        if case .downloading(let shown) = store.states[model], fraction <= shown { return }
                        store.states[model] = .downloading(fraction)
                    }
                }
                states[model] = .ready
                Self.log.info("Downloaded \(model.repo)")
            } catch is CancellationError {
                states[model] = .notDownloaded
            } catch {
                Self.log.error("Download of \(model.repo) failed: \(error.localizedDescription)")
                states[model] = .failed("The download stopped. Check your Wi\u{2011}Fi and try again.")
            }
            tasks[model] = nil
            if tasks.isEmpty { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }

    func cancel(_ model: LocalModel) {
        tasks[model]?.cancel()
    }

    // cancels a download, unloads the model and deletes its files
    func delete(_ model: LocalModel) {
        tasks[model]?.cancel()
        if let loaded = models.removeValue(forKey: model) { Task { await Self.evict([loaded]) } }
        try? FileManager.default.removeItem(at: Self.folder(for: model.repo))
        states[model] = .notDownloaded
    }

    // the model as a FoundationModels LanguageModel, loaded into memory on first use
    func languageModel(_ model: LocalModel) throws -> MLXLanguageModel {
        guard model.fitsThisPhone else { throw PlanReaderError.notReady(model.displayName) }
        guard Self.isOnDisk(model) else { throw PlanReaderError.notReady(model.displayName) }
        if let loaded = models[model] { return loaded }
        // only one model in memory at a time, two gemmas together are more than an iphone can hold
        let others = Array(models.values)
        models = [:]
        let clearing = Task { await Self.evict(others) }
        // a model needs this much free right now, a phone low on memory reads with the camera instead of freezing
        let needed = UInt64(model.bytes) + (1 << 30)
        let made = MLXLanguageModel(
            configuration: model.configuration,
            capabilities: model.capabilities,
            weightsLocation: { id in LocalModelStore.folder(for: id) },
            load: { configuration, progress in
                await clearing.value
                #if !targetEnvironment(simulator)
                guard UInt64(os_proc_available_memory()) >= needed else {
                    Self.log.error("Not enough free memory to load \(configuration.name)")
                    throw PlanReaderError.notReady(model.displayName)
                }
                #endif
                let container = try await VLMModelFactory.shared.loadContainer(
                    from: HubDownloader(), using: TransformersTokenizerLoader(),
                    configuration: configuration, progressHandler: progress)
                // a small scratch pool keeps memory near the weights so ios does not stall the app
                MLX.Memory.cacheLimit = 64 << 20
                return container
            })
        models[model] = made
        return made
    }

    // frees the memory of every loaded model
    func unloadAll() {
        let loaded = Array(models.values)
        models = [:]
        Task { await Self.evict(loaded) }
    }

    // dropping our copy is not enough, the weights live in mlx's own cache until evicted
    nonisolated private static func evict(_ loaded: [MLXLanguageModel]) async {
        guard !loaded.isEmpty else { return }
        for model in loaded { await model.evict() }
        MLX.Memory.clearCache()
    }

    nonisolated static let patterns = ["*.safetensors", "*.json", "*.jinja", "*.txt", "*.model"]

    // free space the phone can give to a download
    private static func freeSpace() -> Int64? {
        let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}

// MARK: - Download

// fetches a model's files from hugging face into the models folder
// files go to a temporary folder first and the whole folder moves in at the end
nonisolated struct HubDownloader: MLXLMCommon.Downloader {

    // one file in a hugging face repo listing
    private struct FileInfo: Decodable {
        let type: String
        let path: String
        let size: Int64?
    }

    // downloads only the files the model needs, with progress
    func download(id: String, revision: String?, matching patterns: [String], useLatest: Bool,
                  progressHandler: @Sendable @escaping (Progress) -> Void) async throws -> URL {
        let final = LocalModelStore.folder(for: id)
        if FileManager.default.fileExists(atPath: final.appendingPathComponent("config.json").path) { return final }

        let branch = revision ?? "main"
        guard let listURL = URL(string: "https://huggingface.co/api/models/\(id)/tree/\(branch)") else {
            throw URLError(.badURL)
        }
        let (listData, _) = try await URLSession.shared.data(from: listURL)
        let files = try JSONDecoder().decode([FileInfo].self, from: listData)
            .filter { $0.type == "file" && Self.matches($0.path, patterns) }
        let total = max(files.reduce(0) { $0 + ($1.size ?? 0) }, 1)

        let staging = LocalModelStore.folder.appendingPathComponent(".download-" + final.lastPathComponent, isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let progress = Progress(totalUnitCount: total)
        var done: Int64 = 0

        for file in files {
            try Task.checkCancellation()
            let target = staging.appendingPathComponent(file.path)
            // a file already in the staging folder at full size came from an earlier try
            if let size = file.size, (try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) == size {
                done += size
                progress.completedUnitCount = done
                progressHandler(progress)
                continue
            }
            guard let url = URL(string: "https://huggingface.co/\(id)/resolve/\(branch)/\(file.path)") else { continue }
            let before = done
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try await FileFetcher.fetch(url, to: target) { written in
                progress.completedUnitCount = before + written
                progressHandler(progress)
            }
            done = before + (file.size ?? 0)
        }

        try? FileManager.default.removeItem(at: final)
        try FileManager.default.moveItem(at: staging, to: final)
        var keep = final
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? keep.setResourceValues(values)
        return final
    }

    // shell style patterns like *.json against the file name
    static func matches(_ path: String, _ patterns: [String]) -> Bool {
        let name = (path as NSString).lastPathComponent
        return patterns.contains { pattern in
            guard pattern.hasPrefix("*") else { return name == pattern }
            return name.hasSuffix(String(pattern.dropFirst()))
        }
    }
}

// one big file from the web with progress read straight from the task, so the bar never freezes
// a dropped connection picks up where it stopped, up to a few times
nonisolated enum FileFetcher {

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 60 * 6
        configuration.allowsExpensiveNetworkAccess = true
        return URLSession(configuration: configuration)
    }()

    // downloads one file, resuming after a dropped connection
    static func fetch(_ url: URL, to target: URL, onBytes: @escaping @Sendable (Int64) -> Void) async throws {
        var resumeData: Data?
        var tries = 0
        while true {
            try Task.checkCancellation()
            do {
                try await once(url, resumeData: resumeData, to: target, onBytes: onBytes)
                return
            } catch let error as URLError where tries < 4 && error.code != .cancelled {
                tries += 1
                resumeData = error.downloadTaskResumeData
                try await Task.sleep(for: .seconds(2 * tries))
            }
        }
    }

    // one try at the download
    private static func once(_ url: URL, resumeData: Data?, to target: URL,
                             onBytes: @escaping @Sendable (Int64) -> Void) async throws {
        let box = TaskBox()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // the finished file is deleted when this handler returns, so it is moved here
                let handler: @Sendable (URL?, URLResponse?, Error?) -> Void = { temp, response, error in
                    box.finished = true
                    if let error { continuation.resume(throwing: error); return }
                    guard let temp, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        continuation.resume(throwing: URLError(.badServerResponse)); return
                    }
                    do {
                        try? FileManager.default.removeItem(at: target)
                        try FileManager.default.moveItem(at: temp, to: target)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                let task = resumeData.map { session.downloadTask(withResumeData: $0, completionHandler: handler) }
                    ?? session.downloadTask(with: url, completionHandler: handler)
                box.task = task
                task.resume()
                // reads the bytes a few times a second until the file is done
                Task.detached {
                    while !box.finished {
                        onBytes(task.countOfBytesReceived)
                        try? await Task.sleep(for: .milliseconds(300))
                    }
                }
            }
        } onCancel: {
            box.task?.cancel()
        }
    }

    // the running task shared with the cancel handler and the progress loop, behind a lock
    private final class TaskBox: @unchecked Sendable {
        private let lock = NSLock()
        private var storedTask: URLSessionDownloadTask?
        private var storedFinished = false

        var task: URLSessionDownloadTask? {
            get { lock.withLock { storedTask } }
            set { lock.withLock { storedTask = newValue } }
        }
        var finished: Bool {
            get { lock.withLock { storedFinished } }
            set { lock.withLock { storedFinished = newValue } }
        }
    }
}

// MARK: - Tokenizer

// loads the tokenizer files that came with the model using swift transformers
nonisolated struct TransformersTokenizerLoader: MLXLMCommon.TokenizerLoader {
    // bridges swift transformers' tokenizer to mlx
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        TokenizerBridge(try await Tokenizers.AutoTokenizer.from(modelFolder: directory))
    }
}

// swift transformers tokenizer in the shape mlx wants
nonisolated struct TokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) { self.upstream = upstream }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? { upstream.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { upstream.convertIdToToken(id) }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(messages: [[String: any Sendable]], tools: [[String: any Sendable]]?,
                           additionalContext: [String: any Sendable]?) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}
