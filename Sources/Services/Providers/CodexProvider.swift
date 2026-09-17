import AppKit
import Defaults
import Foundation
import SwiftUI

/// Experimental translation provider backed by a ChatGPT Codex subscription.
struct CodexProvider: ParallelModelProvider {
    let id = "codex"
    let displayName = "Codex (Experimental)"
    let iconSystemName = "terminal"
    let iconAssetName: String? = "OpenAI"
    let supportsStreaming = true
    let supportsParsing = true
    let supportsSmartTranslation = true
    let isAvailable = true

    let modelKey = Defaults.Key<String>("provider_codex_model", default: "gpt-5.4-mini")
    let enabledModelsKey = Defaults.Key<Set<String>>("provider_codex_enabledModels", default: [])
    let systemPromptKey = Defaults.Key<String>(
        "provider_codex_systemPrompt",
        default: "Translate the following text to {targetLang}. Only output the translation, nothing else."
    )

    /// Codex models published by Pi's generated OpenAI Codex catalog.
    static let availableModels = [
        "gpt-5.3-codex-spark",
        "gpt-5.4",
        "gpt-5.4-mini",
        "gpt-5.5",
        "gpt-5.6-luna",
        "gpt-5.6-sol",
        "gpt-5.6-terra",
    ]

    @MainActor var isConfigured: Bool { CodexAuthManager.hasStoredCredentials }

    func translateStream(
        _ text: String,
        from sourceLang: String?,
        to targetLang: String
    ) -> AsyncThrowingStream<String, Error> {
        translateStream(text, from: sourceLang, to: targetLang, model: Defaults[modelKey])
    }

    func translateStream(
        _ text: String,
        from sourceLang: String?,
        to targetLang: String,
        model: String
    ) -> AsyncThrowingStream<String, Error> {
        processStream(text, from: sourceLang, to: targetLang, mode: .translation, model: model)
    }

    func processStream(
        _ text: String,
        from sourceLang: String?,
        to targetLang: String,
        mode: TextProcessingMode,
        model: String?
    ) -> AsyncThrowingStream<String, Error> {
        let model = model ?? Defaults[modelKey]
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let credentials = try await CodexAuthManager.shared.validCredentials()
                    let request = try buildRequest(
                        text: text,
                        sourceLang: sourceLang,
                        targetLang: targetLang,
                        model: model,
                        mode: mode,
                        credentials: credentials
                    )
                    let (bytes, response) = try await translationURLSession.bytes(for: request)
                    try await streamResponse(bytes, response: response, to: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @MainActor
    func makeSettingsView() -> AnyView {
        AnyView(CodexSettingsView(provider: self))
    }

    private func buildRequest(
        text: String,
        sourceLang: String?,
        targetLang: String,
        model: String,
        mode: TextProcessingMode,
        credentials: CodexCredentials
    ) throws -> URLRequest {
        guard let url = URL(string: "https://chatgpt.com/backend-api/codex/responses") else {
            throw TranslationError.invalidURL
        }

        let prompt = mode.systemPrompt(translationTemplate: Defaults[systemPromptKey], sourceLanguage: sourceLang, targetLanguage: targetLang)
        let body = CodexRequest(
            model: model,
            instructions: prompt,
            input: [
                .init(role: "user", content: [.init(type: "input_text", text: text)]),
            ]
        )

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountID, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("moepeek", forHTTPHeaderField: "originator")
        request.setValue("responses=experimental", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("MoePeek", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func streamResponse(
        _ bytes: URLSession.AsyncBytes,
        response: URLResponse,
        to continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard let response = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }
        guard response.statusCode == 200 else {
            var message = ""
            for try await line in bytes.lines { message += line }
            throw TranslationError.apiError(statusCode: response.statusCode, message: message)
        }

        var parser = CodexStreamParser()
        for try await line in bytes.lines {
            guard !Task.isCancelled else { return }
            if let delta = try parser.consume(line: line) { continuation.yield(delta) }
            if parser.isComplete { return }
        }
        try parser.finish()
    }
}

// MARK: - Authentication

/// Owns Codex Device Code authentication, refresh, and Keychain persistence.
private actor CodexAuthManager {
    static let shared = CodexAuthManager()
    static var hasStoredCredentials: Bool { loadCredentials() != nil }

    private static let keychainKey = "provider.codex.oauth"
    private static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private static let deviceVerificationURL = URL(string: "https://auth.openai.com/codex/device")
    private static let deviceCodeURL = URL(string: "https://auth.openai.com/api/accounts/deviceauth/usercode")
    private static let deviceTokenURL = URL(string: "https://auth.openai.com/api/accounts/deviceauth/token")
    private static let tokenURL = URL(string: "https://auth.openai.com/oauth/token")
    private static let deviceRedirectURI = "https://auth.openai.com/deviceauth/callback"
    private var refreshTask: Task<CodexCredentials, Error>?

    /// Connects a ChatGPT account through the Codex Device Code flow.
    func connect(
        onDeviceCode: @MainActor @Sendable (_ code: String, _ verificationURL: URL) -> Void
    ) async throws {
        guard let verificationURL = Self.deviceVerificationURL else { throw CodexError.invalidResponse }
        let device = try await requestDeviceCode()
        await onDeviceCode(device.userCode, verificationURL)
        let authorization = try await waitForAuthorization(device)
        let credentials = try await exchangeAuthorizationCode(
            authorization.code,
            verifier: authorization.verifier
        )
        try Self.saveCredentials(credentials)
    }

    /// Removes the stored Codex session from this app.
    func disconnect() {
        refreshTask?.cancel()
        refreshTask = nil
        KeychainHelper.delete(key: Self.keychainKey)
    }

    /// Returns a usable credential, refreshing it shortly before expiration.
    func validCredentials() async throws -> CodexCredentials {
        guard let credentials = Self.loadCredentials() else { throw CodexError.notConnected }
        guard credentials.expiresAt <= Date().addingTimeInterval(60) else { return credentials }

        if let refreshTask { return try await refreshTask.value }

        let task = Task {
            let refreshed = try await refresh(credentials.refreshToken)
            try Self.saveCredentials(refreshed)
            return refreshed
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func requestDeviceCode() async throws -> DeviceCode {
        guard let url = Self.deviceCodeURL else { throw CodexError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ClientIDRequest(clientID: Self.clientID))

        let (data, response) = try await translationURLSession.data(for: request)
        try validate(response, data: data)
        return try JSONDecoder().decode(DeviceCode.self, from: data)
    }

    private func waitForAuthorization(_ device: DeviceCode) async throws -> DeviceAuthorization {
        guard let url = Self.deviceTokenURL else { throw CodexError.invalidResponse }
        let deadline = Date().addingTimeInterval(15 * 60)
        var interval = max(device.interval, 1)

        while Date() < deadline {
            try await Task.sleep(for: .seconds(interval))

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(
                DeviceTokenRequest(deviceAuthID: device.deviceAuthID, userCode: device.userCode)
            )

            let (data, response) = try await translationURLSession.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw CodexError.invalidResponse }
            if response.statusCode == 200 {
                return try JSONDecoder().decode(DeviceAuthorization.self, from: data)
            }
            if response.statusCode == 403 || response.statusCode == 404 { continue }

            let message = String(decoding: data, as: UTF8.self)
            if message.contains("slow_down") {
                interval += 5
                continue
            }
            throw CodexError.http(statusCode: response.statusCode, message: message)
        }
        throw CodexError.authorizationTimedOut
    }

    private func exchangeAuthorizationCode(_ code: String, verifier: String) async throws -> CodexCredentials {
        try await requestToken(form: [
            "grant_type": "authorization_code",
            "client_id": Self.clientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": Self.deviceRedirectURI,
        ])
    }

    private func refresh(_ refreshToken: String) async throws -> CodexCredentials {
        try await requestToken(form: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.clientID,
        ])
    }

    private func requestToken(form: [String: String]) async throws -> CodexCredentials {
        guard let url = Self.tokenURL else { throw CodexError.invalidResponse }
        let body = form
            .map { "\(URLFormEncoding.encode($0.key))=\(URLFormEncoding.encode($0.value))" }
            .sorted()
            .joined(separator: "&")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await translationURLSession.data(for: request)
        try validate(response, data: data)
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        return CodexCredentials(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: Date().addingTimeInterval(token.expiresIn),
            accountID: try accountID(from: token.accessToken)
        )
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else { throw CodexError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            throw CodexError.http(
                statusCode: response.statusCode,
                message: String(decoding: data, as: UTF8.self)
            )
        }
    }

    private func accountID(from accessToken: String) throws -> String {
        let parts = accessToken.split(separator: ".")
        guard parts.count == 3 else { throw CodexError.invalidToken }

        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let auth = json["https://api.openai.com/auth"] as? [String: Any],
              let accountID = auth["chatgpt_account_id"] as? String,
              !accountID.isEmpty
        else { throw CodexError.invalidToken }
        return accountID
    }

    private static func loadCredentials() -> CodexCredentials? {
        guard let value = KeychainHelper.load(key: keychainKey),
              let data = value.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(CodexCredentials.self, from: data)
    }

    private static func saveCredentials(_ credentials: CodexCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        guard let value = String(data: data, encoding: .utf8),
              KeychainHelper.save(key: keychainKey, value: value)
        else { throw CodexError.keychainSaveFailed }
    }
}

// MARK: - Settings

private struct CodexSettingsView: View {
    let provider: CodexProvider

    @State private var isConnected = CodexAuthManager.hasStoredCredentials
    @State private var isConnecting = false
    @State private var deviceCode: String?
    @State private var errorMessage: String?
    @State private var connectTask: Task<Void, Never>?
    @State private var modelText: String
    @State private var enabledModelsState: Set<String>
    private let metaService = ModelMetadataService.shared

    init(provider: CodexProvider) {
        self.provider = provider
        self._modelText = State(initialValue: Defaults[provider.modelKey])
        self._enabledModelsState = State(initialValue: Defaults[provider.enabledModelsKey])
    }

    private var model: Binding<String> {
        Binding(
            get: { modelText },
            set: {
                modelText = $0
                Defaults[provider.modelKey] = $0
            }
        )
    }

    private var enabledModels: Binding<Set<String>> {
        Binding(
            get: { enabledModelsState },
            set: {
                enabledModelsState = $0
                Defaults[provider.enabledModelsKey] = $0
            }
        )
    }

    var body: some View {
        Form {
            Section("Codex Connection") {
                HStack {
                    Label(
                        isConnected ? "Connected" : "Not Connected",
                        systemImage: isConnected ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(isConnected ? .green : .secondary)

                    Spacer()

                    if isConnected {
                        Button("Disconnect", role: .destructive) { disconnect() }
                    } else {
                        Button("Connect Codex") { connect() }
                            .disabled(isConnecting)
                    }
                }

                if isConnecting {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Complete authorization in your browser.")
                    }
                }

                if let deviceCode {
                    HStack {
                        Text("Code")
                        Text(deviceCode)
                            .font(.system(.body, design: .monospaced).bold())
                            .textSelection(.enabled)
                        Button("Copy") { copy(deviceCode) }
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                Text("Experimental: uses your ChatGPT Codex subscription and may stop working if OpenAI changes its private Codex interface.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Model") {
                TextField(provider.modelKey.defaultValue, text: model)
                    .textFieldStyle(.roundedBorder)
                Text("Model availability depends on your ChatGPT subscription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Parallel Models") {
                ParallelModelsList(
                    fetchedModels: CodexProvider.availableModels,
                    enabledModels: enabledModels,
                    metaService: metaService,
                    defaultModel: modelText
                )
            }

            Section("System Prompt") {
                TextEditor(text: Defaults.binding(provider.systemPromptKey))
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                Text("Use {targetLang} as a placeholder for the target language.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onDisappear { connectTask?.cancel() }
        .onReceive(Defaults.publisher(provider.modelKey).map(\.newValue)) { newValue in
            if modelText != newValue { modelText = newValue }
        }
        .onReceive(Defaults.publisher(provider.enabledModelsKey).map(\.newValue)) { newValue in
            if enabledModelsState != newValue { enabledModelsState = newValue }
        }
        .task { await metaService.fetchIfNeeded() }
    }

    private func connect() {
        isConnecting = true
        errorMessage = nil
        connectTask = Task {
            do {
                try await CodexAuthManager.shared.connect { code, verificationURL in
                    deviceCode = code
                    NSWorkspace.shared.open(verificationURL)
                }
                isConnected = true
                deviceCode = nil
            } catch is CancellationError {
                // The view disappeared or the user cancelled the task.
            } catch {
                errorMessage = error.localizedDescription
            }
            isConnecting = false
            connectTask = nil
        }
    }

    private func disconnect() {
        connectTask?.cancel()
        Task {
            await CodexAuthManager.shared.disconnect()
            isConnected = false
            deviceCode = nil
            errorMessage = nil
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Data Types

private struct CodexCredentials: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let accountID: String
}

private struct CodexRequest: Encodable {
    let model: String
    let store = false
    let stream = true
    let instructions: String
    let input: [InputMessage]
    let text = TextOptions(verbosity: "low")

    struct InputMessage: Encodable {
        let role: String
        let content: [Content]
    }

    struct Content: Encodable {
        let type: String
        let text: String
    }

    struct TextOptions: Encodable {
        let verbosity: String
    }
}

struct CodexStreamEvent: Decodable {
    let type: String
    let delta: String?
    let message: String?
    let error: ErrorDetail?
    let response: ResponseDetail?

    struct ErrorDetail: Decodable { let message: String? }
    struct ResponseDetail: Decodable { let error: ErrorDetail? }
}

struct CodexStreamParser {
    private(set) var isComplete = false

    mutating func consume(line: String) throws -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard payload != "[DONE]" else { return nil }
        guard let data = payload.data(using: .utf8) else { throw CodexError.invalidResponse }

        let event: CodexStreamEvent
        do {
            event = try JSONDecoder().decode(CodexStreamEvent.self, from: data)
        } catch {
            throw CodexError.invalidResponse
        }

        switch event.type {
        case "response.output_text.delta":
            return event.delta
        case "error":
            throw CodexError.api(event.error?.message ?? event.message ?? "Codex request failed")
        case "response.failed":
            throw CodexError.api(event.response?.error?.message ?? "Codex response failed")
        case "response.completed", "response.done":
            isComplete = true
            return nil
        case "response.incomplete":
            throw CodexError.api(event.response?.error?.message ?? "Codex response incomplete")
        default:
            return nil
        }
    }

    func finish() throws {
        guard isComplete else { throw CodexError.streamEndedUnexpectedly }
    }
}

private struct ClientIDRequest: Encodable {
    let clientID: String
    enum CodingKeys: String, CodingKey { case clientID = "client_id" }
}

struct DeviceCode: Decodable {
    let deviceAuthID: String
    let userCode: String
    let interval: TimeInterval

    enum CodingKeys: String, CodingKey {
        case deviceAuthID = "device_auth_id"
        case userCode = "user_code"
        case interval
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        deviceAuthID = try values.decode(String.self, forKey: .deviceAuthID)
        userCode = try values.decode(String.self, forKey: .userCode)
        if let number = try? values.decode(TimeInterval.self, forKey: .interval) {
            interval = number
        } else {
            let text = try values.decode(String.self, forKey: .interval)
            guard let number = TimeInterval(text) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .interval,
                    in: values,
                    debugDescription: "Expected a numeric polling interval."
                )
            }
            interval = number
        }
        guard interval.isFinite, interval >= 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .interval,
                in: values,
                debugDescription: "Expected a finite, non-negative polling interval."
            )
        }
    }
}

private struct DeviceTokenRequest: Encodable {
    let deviceAuthID: String
    let userCode: String

    enum CodingKeys: String, CodingKey {
        case deviceAuthID = "device_auth_id"
        case userCode = "user_code"
    }
}

private struct DeviceAuthorization: Decodable {
    let code: String
    let verifier: String

    enum CodingKeys: String, CodingKey {
        case code = "authorization_code"
        case verifier = "code_verifier"
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

enum CodexError: LocalizedError {
    case notConnected
    case invalidResponse
    case invalidToken
    case authorizationTimedOut
    case keychainSaveFailed
    case streamEndedUnexpectedly
    case http(statusCode: Int, message: String)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "Connect Codex in Settings before using this provider."
        case .invalidResponse: "Codex returned an invalid response."
        case .invalidToken: "Codex returned an invalid access token."
        case .authorizationTimedOut: "Codex authorization timed out. Try connecting again."
        case .keychainSaveFailed: "Could not save the Codex authorization in Keychain."
        case .streamEndedUnexpectedly: "Codex response ended before completion."
        case let .http(statusCode, message): "Codex authorization failed (\(statusCode)): \(message)"
        case let .api(message): message
        }
    }
}
