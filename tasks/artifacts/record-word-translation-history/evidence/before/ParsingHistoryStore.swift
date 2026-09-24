import Darwin
import Foundation

/// 按本地日期保存完整解析结果；仅在用户明确删除时移除指定历史。
actor ParsingHistoryStore {
    struct Entry: Codable, Sendable {
        let schemaVersion: Int
        let id: UUID
        let completedAt: Date
        let sourceText: String
        let providerName: String
        let providerID: String
        let model: String?
        let result: ParsingResult
    }

    /// 每次打卡保留当时的本地日期和绝对时间。
    struct StudyEvent: Codable, Sendable {
        let day: String
        let studiedAt: Date
    }

    /// 次数由完整事件数组派生，避免重复存储计数产生不一致。
    struct ReviewState: Codable, Sendable {
        var isFavorite = false
        var studyEvents: [StudyEvent] = []
    }

    /// 日期来自服务端本机时区，浏览器不参与每日限次判定。
    struct ReviewSnapshot: Encodable, Sendable {
        let today: String
        let states: [String: ReviewState]
    }

    nonisolated let directoryURL: URL

    /// 本实例成功增删历史后的版本标识；新实例使用新值，让已打开网页识别应用重启。
    private(set) var historyRevision = UUID()

    init(directoryURL: URL = URL.applicationSupportDirectory.appendingPathComponent("MoePeek/ParsingHistory", isDirectory: true)) {
        self.directoryURL = directoryURL
    }

    /// 确保存储目录存在，供写入及设置页打开目录使用。
    func prepareDirectory() throws -> URL {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return directoryURL
    }

    /// 追加已完成结果；无需修改的 check 返回 nil，且不创建目录或文件。
    @discardableResult
    func append(
        sourceText: String,
        result: ParsingResult,
        providerName: String,
        providerID: String,
        model: String? = nil,
        date: Date = Date(),
        timeZone: TimeZone = .current
    ) async throws -> URL? {
        if case let .check(items, rephrase) = result,
           items.isEmpty,
           rephrase?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: date)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(Entry(
            schemaVersion: 2, id: UUID(), completedAt: date, sourceText: sourceText,
            providerName: providerName, providerID: providerID, model: model, result: result
        ))
        data.append(0x0A)
        let lockDescriptor = try await lockHistory(for: day)
        defer { flock(lockDescriptor, LOCK_UN); Darwin.close(lockDescriptor) }
        let fileURL = directoryURL.appendingPathComponent(day + ".jsonl")
        let descriptor = Darwin.open(fileURL.path, O_RDWR | O_APPEND | O_CREAT | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(descriptor) }
        // 不在系统调用中永久等待；异步退让也允许设置页创建/打开目录。
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            let code = POSIXErrorCode(rawValue: errno) ?? .EIO
            guard code == .EWOULDBLOCK || code == .EINTR else { throw POSIXError(code) }
            guard ContinuousClock.now < deadline else { throw POSIXError(.EWOULDBLOCK) }
            try await Task.sleep(for: .milliseconds(20))
        }
        defer { flock(descriptor, LOCK_UN) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard metadata.st_mode & S_IFMT == S_IFREG else { throw CocoaError(.fileWriteUnknown) }
        // 上次进程意外退出可能留下不完整尾行；加分隔符，让后续完整记录仍可独立读取。
        if metadata.st_size > 0 {
            var lastByte: UInt8 = 0
            guard pread(descriptor, &lastByte, 1, metadata.st_size - 1) == 1 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            if lastByte != 0x0A { data.insert(0x0A, at: 0) }
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch {
            // 写入失败时尽量撤回本条的部分字节，已有记录保持原样。
            try? handle.truncate(atOffset: UInt64(metadata.st_size))
            try? handle.synchronize()
            throw error
        }
        historyRevision = UUID()
        return fileURL
    }

    /// 使用不会随 JSONL 原子替换而变化的锁文件，串行化同一天的全部写入。
    private func lockHistory(for day: String) async throws -> Int32 {
        guard Self.isValidDay(day) else { throw CocoaError(.fileWriteInvalidFileName) }
        let url = try prepareDirectory().appendingPathComponent(day + ".lock")
        let descriptor = Darwin.open(url.path, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        do {
            var metadata = stat()
            guard fstat(descriptor, &metadata) == 0,
                  metadata.st_mode & S_IFMT == S_IFREG else { throw CocoaError(.fileWriteUnknown) }
            let deadline = ContinuousClock.now.advanced(by: .seconds(1))
            while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
                let code = POSIXErrorCode(rawValue: errno) ?? .EIO
                guard code == .EWOULDBLOCK || code == .EINTR else { throw POSIXError(code) }
                guard ContinuousClock.now < deadline else { throw POSIXError(.EWOULDBLOCK) }
                try await Task.sleep(for: .milliseconds(20))
            }
            try Task.checkCancellation()
            return descriptor
        } catch {
            Darwin.close(descriptor)
            throw error
        }
    }

    /// 删除指定 UUID 的原始行及复习状态；重复请求可安全重试，其他行逐字节保留。
    func deleteEntry(for day: String, entryID: UUID) async throws {
        let lockDescriptor = try await lockHistory(for: day)
        defer { flock(lockDescriptor, LOCK_UN); Darwin.close(lockDescriptor) }
        let history = try contents(for: day)
        var retained = Data()
        var matches = 0
        var start = history.startIndex
        while start < history.endIndex {
            let newline = history[start...].firstIndex(of: 0x0A)
            let end = newline.map { history.index(after: $0) } ?? history.endIndex
            let line = history[start..<end]
            if let entry = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
               let rawID = entry["id"] as? String, UUID(uuidString: rawID) == entryID {
                matches += 1
            } else {
                retained.append(contentsOf: line)
            }
            start = end
        }
        // 重复 ID 无法唯一定位，拒绝删除，避免一次操作影响多条记录。
        guard matches <= 1 else { throw POSIXError(.EINVAL) }
        var states = try reviewSnapshot(for: day).states
        let stateKeys = states.keys.filter { UUID(uuidString: $0) == entryID }
        for key in stateKeys { states.removeValue(forKey: key) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let stateData = try encoder.encode(states)
        guard stateData.count <= 64 * 1024 * 1024 else { throw CocoaError(.fileWriteOutOfSpace) }
        // 先清理关联状态；若历史提交失败，卡片仍保留，用户可以继续点击重试。
        if !stateKeys.isEmpty {
            try stateData.write(to: directoryURL.appendingPathComponent(day + ".review.json"), options: [.atomic])
        }
        if matches == 1 {
            try retained.write(to: directoryURL.appendingPathComponent(day + ".jsonl"), options: [.atomic])
            historyRevision = UUID()
        }
    }

    /// 只列出按日期命名的普通 JSONL 文件，不读取旧 Markdown 或符号链接。
    func days() throws -> [String] {
        let directory = try prepareDirectory()
        return try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        ).compactMap { url in
            guard url.pathExtension == "jsonl" else { return nil }
            let day = url.deletingPathExtension().lastPathComponent
            guard Self.isValidDay(day) else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            return values.isRegularFile == true && values.isSymbolicLink != true ? day : nil
        }.sorted(by: >)
    }

    /// 在共享锁内读取完整日期文件，拒绝路径穿越、符号链接和特殊文件。
    func contents(for day: String) throws -> Data {
        guard Self.isValidDay(day) else { throw CocoaError(.fileReadInvalidFileName) }
        return try readFile(at: directoryURL.appendingPathComponent(day + ".jsonl"))
    }

    private func readFile(at url: URL) throws -> Data {
        let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_SH | LOCK_NB) == 0 else { throw POSIXError(.EWOULDBLOCK) }
        defer { flock(descriptor, LOCK_UN) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFREG else { throw CocoaError(.fileReadUnknown) }
        // 浏览器按日加载；对异常大文件明确报错，不截断或修改源数据。
        guard metadata.st_size <= 64 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        return try handle.readToEnd() ?? Data()
    }

    /// 读取独立的复习状态，不修改已有 JSONL。
    func reviewSnapshot(for day: String) throws -> ReviewSnapshot {
        guard Self.isValidDay(day) else { throw CocoaError(.fileReadInvalidFileName) }
        let url = directoryURL.appendingPathComponent(day + ".review.json")
        let states: [String: ReviewState]
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            states = try decoder.decode([String: ReviewState].self, from: readFile(at: url))
        } catch let error as POSIXError where error.code == .ENOENT {
            states = [:]
        }
        return ReviewSnapshot(today: localDay(at: Date()), states: states)
    }

    /// 在同一个 actor 临界区读取、限次并原子保存；失败时不返回成功状态。
    func updateReview(for day: String, entryID: UUID, action: String) async throws -> ReviewSnapshot {
        guard ["favorite", "unfavorite", "study"].contains(action) else {
            throw POSIXError(.EINVAL)
        }
        let lockDescriptor = try await lockHistory(for: day)
        defer { flock(lockDescriptor, LOCK_UN); Darwin.close(lockDescriptor) }
        let history = try contents(for: day)
        let exists = history.split(separator: 0x0A).contains { line in
            guard let entry = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let rawID = entry["id"] as? String else { return false }
            return UUID(uuidString: rawID) == entryID
        }
        guard exists else { throw CocoaError(.fileReadNoSuchFile) }
        let snapshot = try reviewSnapshot(for: day)
        let now = Date()
        let today = localDay(at: now)
        var states = snapshot.states
        let key = entryID.uuidString.lowercased()
        var state = states[key] ?? ReviewState()
        switch action {
        case "favorite": state.isFavorite = true
        case "unfavorite": state.isFavorite = false
        default:
            if !state.studyEvents.contains(where: { $0.day == today }) {
                state.studyEvents.append(StudyEvent(day: today, studiedAt: now))
            }
        }
        states[key] = state
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(states)
        guard data.count <= 64 * 1024 * 1024 else { throw CocoaError(.fileWriteOutOfSpace) }
        let url = directoryURL.appendingPathComponent(day + ".review.json")
        try data.write(to: url, options: [.atomic])
        return ReviewSnapshot(today: today, states: states)
    }

    private func localDay(at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    nonisolated static func isValidDay(_ day: String) -> Bool {
        day.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
            && day.utf8.count == 10 && day.utf8.allSatisfy { $0 == 45 || (48...57).contains($0) }
    }
}
