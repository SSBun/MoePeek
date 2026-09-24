import Foundation
import Network

/// 本机复习服务；支持读取、删除单条历史及更新收藏、打卡状态。
@MainActor
final class ParsingHistoryServer {
    private let store: ParsingHistoryStore
    private var listener: NWListener?
    private var startTask: Task<URL, Error>?
    private var pendingStart: CheckedContinuation<URL, Error>?
    private var startupDeadline: Task<Void, Never>?
    private var address: URL?
    private var connections: [UUID: NWConnection] = [:]
    private var deadlines: [UUID: Task<Void, Never>] = [:]

    init(store: ParsingHistoryStore) {
        self.store = store
    }

    /// 返回可收藏的本机浏览器地址；并发点击共享同一次启动。
    func start() async throws -> URL {
        if let address { return address }
        if let startTask { return try await startTask.value }
        let task = Task { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.startListener()
        }
        startTask = task
        defer { startTask = nil }
        return try await task.value
    }

    /// 停止监听并关闭全部请求。
    func stop() {
        startTask?.cancel()
        startupDeadline?.cancel()
        startupDeadline = nil
        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil
        address = nil
        pendingStart?.resume(throwing: CancellationError())
        pendingStart = nil
        for id in Array(connections.keys) { close(id) }
    }

    private func startListener() async throws -> URL {
        try Task.checkCancellation()
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: 18765)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                guard let self, self.listener === listener else { connection.cancel(); return }
                self.accept(connection)
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            pendingStart = continuation
            startupDeadline = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                guard let self, self.pendingStart != nil else { return }
                self.stop()
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self, self.listener === listener else { return }
                    switch state {
                    case .ready:
                        guard let port = listener.port,
                              let url = URL(string: "http://127.0.0.1:\(port.rawValue)/index.html") else {
                            self.stop()
                            return
                        }
                        self.address = url
                        self.startupDeadline?.cancel()
                        self.startupDeadline = nil
                        self.pendingStart?.resume(returning: url)
                        self.pendingStart = nil
                    case let .failed(error):
                        self.pendingStart?.resume(throwing: error)
                        self.pendingStart = nil
                        self.stop()
                    case .cancelled:
                        self.stop()
                    default:
                        break
                    }
                }
            }
            listener.start(queue: .main)
        }
    }

    private func accept(_ connection: NWConnection) {
        guard connections.count < 16 else { connection.cancel(); return }
        let id = UUID()
        connections[id] = connection
        deadlines[id] = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard let self else { return }
            self.close(id)
        }
        connection.start(queue: .main)
        receive(id, buffer: Data())
    }

    private func close(_ id: UUID) {
        deadlines.removeValue(forKey: id)?.cancel()
        connections.removeValue(forKey: id)?.cancel()
    }

    private func receive(_ id: UUID, buffer: Data) {
        guard let connection = connections[id] else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, complete, error in
            Task { @MainActor [weak self] in
                guard let self, self.connections[id] != nil else { return }
                var buffer = buffer
                if let data { buffer.append(data) }
                guard buffer.count <= 16_384 else { self.respond(id, status: 431); return }
                if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                    await self.handle(id, header: Data(buffer[..<end.lowerBound]))
                } else if complete || error != nil {
                    self.close(id)
                } else {
                    self.receive(id, buffer: buffer)
                }
            }
        }
    }

    private func handle(_ id: UUID, header: Data) async {
        guard let text = String(data: header, encoding: .utf8) else { respond(id, status: 400); return }
        let lines = text.components(separatedBy: "\r\n")
        let request = (lines.first ?? "").split(separator: " ")
        guard request.count == 3, request[2] == "HTTP/1.1" else { respond(id, status: 400); return }
        let method = String(request[0])
        guard method == "GET" || method == "POST" else { respond(id, status: 405); return }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { respond(id, status: 400); return }
            let name = line[..<colon].lowercased()
            guard headers[name] == nil else { respond(id, status: 400); return }
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard headers["transfer-encoding"] == nil,
              headers["content-length"] == nil || headers["content-length"] == "0" else {
            respond(id, status: 400)
            return
        }
        guard let port = listener?.port,
              headers["host"] == "127.0.0.1:\(port.rawValue)"
        else { respond(id, status: 403); return }
        let path = String(request[1])
        let assets: [String: (String, String)] = [
            "/": ("parsing-history.html", "text/html; charset=utf-8"),
            "/index.html": ("parsing-history.html", "text/html; charset=utf-8"),
            "/history.js": ("parsing-history.js", "text/javascript; charset=utf-8"),
            "/history.css": ("parsing-history.css", "text/css; charset=utf-8"),
            "/favicon.png": ("parsing-history-favicon.png", "image/png"),
        ]
        // 固定静态资源不含历史数据；允许从任意网页链接直接进入，无需授权。
        if let (name, type) = assets[path], method == "GET" {
            guard let url = Bundle.main.url(forResource: name, withExtension: nil),
                  let data = try? Data(contentsOf: url) else { respond(id, status: 500); return }
            respond(id, status: 200, type: type, body: data)
            return
        }
        // 仅数据接口检查来源；写操作必须明确来自本页，不能仅凭回环地址信任请求。
        guard (method == "GET" && headers["origin"] == nil) || headers["origin"] == "http://127.0.0.1:\(port.rawValue)",
              headers["sec-fetch-site"] == nil || ["same-origin", "none"].contains(headers["sec-fetch-site"] ?? "")
        else { respond(id, status: 403); return }
        do {
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            if method == "POST", components.count == 6,
               components[1] == "api", components[2] == "history",
               ParsingHistoryStore.isValidDay(String(components[3])),
               let entryID = UUID(uuidString: String(components[4])), components[5] == "delete" {
                try await store.deleteEntry(for: String(components[3]), entryID: entryID)
                respond(id, status: 200)
            } else if components.count >= 4, components[1] == "api", components[2] == "review",
               ParsingHistoryStore.isValidDay(String(components[3])) {
                let day = String(components[3])
                let snapshot: ParsingHistoryStore.ReviewSnapshot
                if method == "GET", components.count == 4 {
                    snapshot = try await store.reviewSnapshot(for: day)
                } else if method == "POST", components.count == 6,
                          let entryID = UUID(uuidString: String(components[4])),
                          ["favorite", "unfavorite", "study"].contains(String(components[5])) {
                    snapshot = try await store.updateReview(for: day, entryID: entryID, action: String(components[5]))
                } else {
                    respond(id, status: 400)
                    return
                }
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                respond(id, status: 200, type: "application/json", body: try encoder.encode(snapshot))
            } else if method != "GET" {
                respond(id, status: 405)
            } else if path == "/api/history-revision" {
                let revision = await store.historyRevision
                respond(id, status: 200, type: "application/json", body: try JSONEncoder().encode(revision))
            } else if path == "/api/days" {
                let days = try await store.days()
                respond(id, status: 200, type: "application/json", body: try JSONEncoder().encode(days))
            } else if path.hasPrefix("/api/history/"), ParsingHistoryStore.isValidDay(String(path.dropFirst(13))) {
                let data = try await store.contents(for: String(path.dropFirst(13)))
                respond(id, status: 200, type: "application/x-ndjson; charset=utf-8", body: data)
            } else {
                respond(id, status: 404)
            }
        } catch {
            // 不把文件路径、解析内容或底层错误细节暴露给 HTTP 客户端。
            respond(id, status: 503)
        }
    }

    private func respond(_ id: UUID, status: Int, type: String = "text/plain; charset=utf-8", body: Data = Data()) {
        guard let connection = connections[id] else { return }
        let headers = [
            "HTTP/1.1 \(status) \(status == 200 ? "OK" : "Error")",
            "Content-Type: \(type)", "Content-Length: \(body.count)", "Connection: close",
            "Cache-Control: no-store", "X-Content-Type-Options: nosniff", "Referrer-Policy: no-referrer",
            "Content-Security-Policy: default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
        ].joined(separator: "\r\n")
        var response = Data((headers + "\r\n\r\n").utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.close(id)
            }
        })
    }
}
