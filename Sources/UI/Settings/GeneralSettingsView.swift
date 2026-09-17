import Defaults
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var parsingCoordinator: ParsingCoordinator
    @Bindable var smartTranslationCoordinator: SmartTranslationCoordinator
    @Default(.targetLanguage) private var targetLanguage
    @Default(.isAutoDetectEnabled) private var isAutoDetectEnabled
    @Default(.textDetectionMode) private var textDetectionMode
    @Default(.showInDock) private var showInDock
    @Default(.popupDefaultWidth) private var popupDefaultWidth
    @Default(.popupDefaultHeight) private var popupDefaultHeight
    @Default(.popupFontSize) private var popupFontSize
    @Default(.popupFontName) private var popupFontName
    @Default(.sourceLanguage) private var sourceLanguage
    @Default(.detectionConfidenceThreshold) private var confidenceThreshold
    @Default(.appLanguage) private var appLanguage
    @Default(.defaultInputSource) private var defaultInputSource
    @Default(.capitalizeFirstLetter) private var capitalizeFirstLetter

    private var textDetectionModeDescription: String {
        switch textDetectionMode {
        case .conservative:
            String(localized: "Uses Accessibility API only. Most compatible with remote desktops and virtual machines, but may not detect text in some apps.")
        case .standard:
            String(localized: "Uses Accessibility API + AppleScript (Safari). Covers most apps without simulating keystrokes.")
        case .full:
            String(localized: "Uses all detection methods including ⌘C simulation. Best coverage, but may interfere with remote desktop apps and keyboard shortcut recording.")
        }
    }

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showRestartAlert = false
    @State private var showHistoryFolderError = false
    @State private var availableFonts = NSFontManager.shared.availableFontFamilies
    @State private var availableInputSources: [KeyboardInputSource] = []

    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                KeyboardShortcuts.Recorder("Selection Translation:", name: .translateSelection)
                KeyboardShortcuts.Recorder("Screenshot OCR:", name: .ocrScreenshot)
                KeyboardShortcuts.Recorder("Manual Translation:", name: .inputTranslation)
                KeyboardShortcuts.Recorder("Text Parsing:", name: .inputParsing)
                KeyboardShortcuts.Recorder("Smart Translation:", name: .inputSmartTranslation)
                KeyboardShortcuts.Recorder("Clipboard Translation:", name: .clipboardTranslation)
            }

            Section("General") {
                Picker("App Language:", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .onChange(of: appLanguage) { _, newValue in
                    if newValue == .system {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([newValue.rawValue], forKey: "AppleLanguages")
                    }
                    UserDefaults.standard.synchronize()
                    showRestartAlert = true
                }

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue // Revert on failure
                        }
                    }

                Toggle("Show Dock icon", isOn: $showInDock)
                    .onChange(of: showInDock) { _, newValue in
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                        if !newValue {
                            NSApp.activate()
                        }
                    }

                Picker("Default Input Method:", selection: $defaultInputSource) {
                    Text("System Default").tag("")
                    Divider()
                    ForEach(availableInputSources) { source in
                        Text(source.name).tag(source.id)
                    }
                }
            }

            Section("Translation") {
                Picker("Translate to:", selection: $targetLanguage) {
                    ForEach(SupportedLanguages.all, id: \.code) { code, name in
                        Text(name).tag(code)
                    }
                }

                Toggle("Capitalize first letter of translation", isOn: $capitalizeFirstLetter)

                Toggle("Show floating icon on text selection", isOn: $isAutoDetectEnabled)

                if isAutoDetectEnabled {
                    Picker("Text Detection Mode:", selection: $textDetectionMode) {
                        Text("Conservative").tag(TextDetectionMode.conservative)
                        Text("Standard").tag(TextDetectionMode.standard)
                        Text("Full").tag(TextDetectionMode.full)
                    }

                    Text(textDetectionModeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Parsing") {
                Picker("Parsing Provider", selection: $parsingCoordinator.selectedProviderID) {
                    Text("Enabled LLMs (Default)").tag("")
                    ForEach(parsingCoordinator.availableProviders, id: \.id) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                    if !parsingCoordinator.selectedProviderID.isEmpty,
                       !parsingCoordinator.availableProviders.contains(where: { $0.id == parsingCoordinator.selectedProviderID }) {
                        Text("Unavailable Provider").tag(parsingCoordinator.selectedProviderID)
                    }
                }

                Picker("Explanation Language", selection: $parsingCoordinator.selectedExplanationLanguage) {
                    Text("Same as translation target (Default)").tag("")
                    ForEach(SupportedLanguages.all, id: \.code) { code, name in
                        Text(name).tag(code)
                    }
                }
                Text("Chinese input becomes natural English; English input is analyzed directly. This setting only controls the explanation language.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Review English", action: parsingCoordinator.openHistory)
                Button("Open Parsing History Folder", action: openParsingHistoryFolder)
                Text("Parsing results are saved locally as daily JSONL files. Review them in your browser while MoePeek is running.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Smart Translation") {
                Picker("Smart Translation Provider", selection: $smartTranslationCoordinator.selectedProviderID) {
                    Text("Enabled LLMs (Default)").tag("")
                    ForEach(smartTranslationCoordinator.availableProviders, id: \.id) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                    if !smartTranslationCoordinator.selectedProviderID.isEmpty,
                       !smartTranslationCoordinator.availableProviders.contains(where: { $0.id == smartTranslationCoordinator.selectedProviderID }) {
                        Text("Unavailable Provider").tag(smartTranslationCoordinator.selectedProviderID)
                    }
                }
                Text("Automatically handles English and Chinese words and sentences. Sentence analysis uses the Parsing explanation language, paste-back behavior, and local history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Language Detection") {
                Picker("Source Language:", selection: $sourceLanguage) {
                    Text("Auto Detect").tag("auto")
                    ForEach(SupportedLanguages.all, id: \.code) { code, name in
                        Text(name).tag(code)
                    }
                }

                if sourceLanguage == "auto" {
                    LabeledContent("Detection Sensitivity: \(confidenceThreshold, specifier: "%.1f")") {
                        Slider(value: $confidenceThreshold, in: 0.1...0.8, step: 0.1)
                    }
                    Text("Lower = more aggressive detection (may be inaccurate); Higher = more conservative (may return unknown)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Popup Panel") {
                LabeledContent("Default Width: \(popupDefaultWidth)") {
                    Slider(
                        value: Binding(
                            get: { Double(popupDefaultWidth) },
                            set: { popupDefaultWidth = Int($0) }
                        ),
                        in: 280...800,
                        step: 10
                    )
                }

                LabeledContent("Default Height: \(popupDefaultHeight)") {
                    Slider(
                        value: Binding(
                            get: { Double(popupDefaultHeight) },
                            set: { popupDefaultHeight = Int($0) }
                        ),
                        in: 200...800,
                        step: 10
                    )
                }

                LabeledContent("Font Size: \(popupFontSize)") {
                    Slider(
                        value: Binding(
                            get: { Double(popupFontSize) },
                            set: { popupFontSize = Int($0) }
                        ),
                        in: 12...24,
                        step: 1
                    )
                }

                Picker("Font:", selection: $popupFontName) {
                    Text("System Default")
                        .tag("")
                    Divider()
                    ForEach(availableFonts, id: \.self) { family in
                        Text(family)
                            .font(.custom(family, size: 13))
                            .tag(family)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            availableInputSources = KeyboardInputSource.availableSources()
        }
        .alert("App Language", isPresented: $showRestartAlert) {
            Button("Restart Now") { AppRelaunch.relaunch() }
            Button("Later", role: .cancel) { }
        } message: {
            Text("Changing language requires restarting the app.")
        }
        .alert("Could not open parsing history folder.", isPresented: $showHistoryFolderError) {
            Button("OK", role: .cancel) { }
        }
    }

    /// 即使尚无记录，也创建并打开同一个实际存储目录。
    private func openParsingHistoryFolder() {
        Task { @MainActor in
            do {
                let directory = try await parsingCoordinator.historyStore.prepareDirectory()
                showHistoryFolderError = !NSWorkspace.shared.open(directory)
            } catch {
                showHistoryFolderError = true
            }
        }
    }
}

private struct KeyboardInputSource: Identifiable {
    let id: String
    let name: String

    @MainActor
    static func availableSources() -> [KeyboardInputSource] {
        let textView = NSTextView()
        let sources = textView.inputContext?.keyboardInputSources ?? []
        return sources.map {
            KeyboardInputSource(
                id: $0,
                name: NSTextInputContext.localizedName(forInputSource: $0) ?? $0
            )
        }
    }
}
