# Phase 1: New AI system

Goal: better text reading, Apple's on-phone model reading the blacked-out photo, and a "Who reads your papers" setting with offline and cloud choices. Nothing ever falls back to the cloud silently. Ask stays on the on-phone model.

Order: 1.1, then 1.2 + 1.3 (DORRON first), then 1.4, then 1.5, 1.6, 1.7 (they share ModelChoice and Settings, so not in parallel). Numbers match the build plan doc.

---

## 1.1 Better text reading
helper: coder

Files: `Services/Reading/TextReader.swift`, maybe new `Core/DocumentText.swift`, new `RemedyTests/TextReaderTests.swift`.

Brief:
- Use Vision's `RecognizeDocumentsRequest` (iOS 26+). It returns paragraphs, lists and tables. Turn them into the same text format TextReader returns today (check what AIPrompt and Redactor expect) so nothing downstream changes. Formatting rules that are pure string work go in `Core/DocumentText.swift`.
- Keep `TypoFixer`, the medicine word list and the old reader as a fallback when the new request returns nothing.
- Test: run both readers over 3 of the PDFs in `SamplePapers/` (render a page with PDFReader) and check every medicine name and number from `SamplePapers/expected/*.json` appears in the new text. Print a short old vs new count.

Done when: TextReaderTests pass and the new reader finds at least as many expected names and numbers as the old one.

---

## 1.2 + 1.3 One reader for any model, with the photo
helper: engine

DORRON first: lead prints these steps and waits.
1. In Xcode, File > Add Package Dependencies. Add Anthropic's and Google's Swift packages for the Foundation Models `LanguageModel` protocol, if they're published (the engine looks up the URLs first and gives them to you). Skip either one if it isn't out.
2. Say done, or "skip packages".

Files: new `Services/AI/ModelChoice.swift`, new `Services/AI/ModelPlanReader.swift`, `Services/AI/PlanReader.swift`, `Services/AI/AIPrompt.swift`, `Services/AI/PromptExamples.swift`, `Interface/ViewModels/ScanFlowViewModel.swift` (reading steps only), new `RemedyTests/PlanReaderTests.swift`.

Brief:
- First check the current iOS 27 Foundation Models docs on developer.apple.com: the `LanguageModel` protocol, image attachments in a prompt, the Vision OCR tool, `PrivateCloudComputeLanguageModel`, and the context size of `SystemLanguageModel`. Write a 5-line note of what you confirmed at the top of ModelPlanReader.swift as comments in house style.
- `ModelChoice`: one entry per reader with id, display name, group (`onPhone`, `offlineDownload`, `applePrivateCloud`, `yourMac`, `cloud`), `sendsDataOffPhone`, `canReadPhoto`, `needsKey`. Start with: On this iPhone, Apple Private Cloud, Claude, Gemini. Later steps add more.
- `ModelPlanReader(choice:)`: one reader for any `LanguageModel`. Reuse the `@Generable` types in `AIPlan.swift`, the prompt and the worked examples. Input: the blacked-out page photo from `PageBlackout`, the redacted document text, and the Vision OCR tool where the model supports tools. Respect the on-phone context window: read page by page and merge, using the existing merge in `AIPlanConverter` if there is one.
- A `sendTextOnly` flag: when on, no photo is attached for any model that sends data off the phone.
- `PlanReader.swift`: replace the fixed order at line 63 with the user's choice. If the chosen reader fails, return an error the ViewModel shows with a "Try On this iPhone instead?" button. Never fall back to another reader by itself.
- If a vendor package is missing or can't take a photo plus the answer format, keep `Gemini/*` working behind the same reader protocol and note it. Claude without a package is added in 1.6.
- ScanFlowViewModel: the "Google Gemini reads the blacked out page" step text becomes "<display name> reads the page", from the choice.
- Leave `Apple/ApplePlanReader.swift` in place but unused. Phase 5 removes it.
- Tests with a fake `LanguageModel` (or a fake reader behind the protocol): the chosen reader is the one used; a failure returns an error and does not call any other reader; `sendTextOnly` sends no image.

Done when: tests pass and a sample PDF reads into a plan with On this iPhone in the Simulator (DORRON checks by hand).

---

## 1.4 "Who reads your papers" setting
helper: coder

Files: `Interface/ViewModels/SettingsViewModel.swift`, `Interface/Screens/ClassicUI/Views/Settings/SettingsView.swift`, `Interface/Screens/SimpleUI/Views/Settings/SimpleSettingsView.swift`, `Interface/ViewModels/ScanFlowViewModel.swift`, `ScanFlowView.swift`, `Services/Security/KeychainStore.swift` (reuse), new `Interface/Components/WhatGetsSentSheet.swift`.

Brief:
- Settings row "Who reads your papers", opening a list grouped as: On this iPhone (default), Offline downloads, Apple Private Cloud, Your own Mac, Cloud. Show only the choices that exist in `ModelChoice`. Each cloud row has a one-line warning: "The blacked-out page leaves your phone."
- Rows that need a key show a secure field. Keys are saved with KeychainStore, never in UserDefaults.
- A "Send text only" switch (off by default) under the cloud group.
- `WhatGetsSentSheet`: before the first read with any choice that sends data off the phone, show the blacked-out image (unless text only) and the redacted text, with "Send" and "Use On this iPhone instead". Remember that it was shown per choice.
- The scan screen keeps showing which model read the paper.
- Simple look: Settings shows the current reader and one "Change" button that opens the same list. Logic in the ViewModels only.

Done when: build ok, changing the setting changes who reads (check in the reading step text).

---

## 1.5 Offline downloads (MLX)
helper: coder

DORRON first: add Apple's MLX Swift package that provides `MLXLanguageModel` (the coder finds the URL and prints it before starting), then say done.

Files: new `Services/AI/Local/LocalModelStore.swift`, `Services/AI/ModelChoice.swift`, Settings ViewModel and both Settings views.

Brief:
- Two optional downloads: one small text-only model (about 1 to 2 GB, 4-bit) and one small vision model (about 2 to 4 GB, 4-bit). Pick current models from the mlx-community collection that `MLXLanguageModel` supports and that fit those sizes. Put their ids in one constant list with a comment on why they were picked.
- LocalModelStore: download with progress into Application Support, excluded from backup, delete, size on disk, and a memory check (`ProcessInfo.processInfo.physicalMemory` at least 8 GB) that hides the rows on phones that can't run them.
- Downloaded models appear in ModelChoice under `offlineDownload`. The text model has `canReadPhoto = false`.
- If the increased-memory entitlement is needed, stop and tell Dorron (it may need the paid account).

Done when: build ok. DORRON: download the text model on a real phone and read one sample paper in airplane mode.

---

## 1.6 More cloud readers
helper: coder

Files: new `Services/AI/Cloud/OpenAICompatibleModel.swift`, maybe new `Services/AI/Cloud/AnthropicModel.swift`, `Services/AI/ModelChoice.swift`, `Services/AI/Gemini/GeminiSchema.swift` (reuse its schema building), Settings ViewModel and both Settings views, Info.plist keys through build settings if needed.

Brief:
- `OpenAICompatibleModel`: base URL, key, model name. Chat completions with a JSON schema response built from the same plan types (reuse the approach in GeminiSchema.swift). Image as a base64 data URL unless text only.
- Presets in ModelChoice: OpenAI, Your own Mac (Ollama `http://<name>.local:11434/v1` or LM Studio `:1234/v1`, no key), OpenRouter, Groq, Mistral, and Custom (any URL). The model name is a text field with a suggested default; check each provider's docs for a current default rather than guessing.
- Your own Mac needs local network access: add `NSLocalNetworkUsageDescription` and allow local networking in App Transport Security through the target's build settings (`INFOPLIST_KEY_...`), the only pbxproj edit allowed in this step.
- If 1.2 could not use an Anthropic package, add `AnthropicModel.swift` here with the Messages API (image block plus JSON output).
- Tests with a stubbed URLProtocol: the request has the schema, has no image when text only, and never includes a name or record number from a sample (run the text through the existing redactor first).

Done when: tests pass. DORRON tries OpenAI or OpenRouter with his own key and one sample paper.

---

## 1.7 Pick the default by testing
helper: coder

Files: new `RemedyTests/ModelComparisonTests.swift`, writes `SamplePapers/results.md`.

Brief: a test that only runs when the env var `REMEDY_COMPARE=1` is set. For each reader that is available (keys come from env vars, never from code), read every sample paper, compare to `SamplePapers/expected/*.json`, and write a table: reader, medicines right, stop days right, doses right, seconds per paper. No pass or fail, it's a report.

Done when: the report is written for at least On this iPhone. DORRON runs it with his keys and picks the default.
