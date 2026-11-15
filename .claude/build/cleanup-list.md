# Phase 5.1 scout list (for Dorron's picks)
Dead (nothing uses): Services/AI/Apple/ApplePlanReader.swift, Services/AI/Gemini/GeminiPageReader.swift, MedicalWords.medicineWords(in:), Services/Epic/SampleFHIR.swift.
Still used (keep): GeminiPlanReader, GeminiClient, GeminiSchema (PlanReader.swift:58, SettingsViewModel:170, ConnectionCheck:51, RemedyApp:26), AppleAI.
Already gone: Core/NameFinder.swift, RemedyWidget/RemedyActivityMirror.swift.
Demo-only LaunchOptions: demoSamplePlan, demoPatient, demoWelcome, demoFakeAI (FakePlanReader + DianeDrafts), demoDay, demoTime, isDemo, isSampleData. All still used by the app, DemoTour UI tests or the Remedy Demo scheme.
Not checked: SimpleMedicinesView, Classic Medicines and Ask screens, Resources/PreviewSamples.swift, SampleDrafts.swift, Simple/Classic duplicate pairs.
