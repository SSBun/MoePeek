import Darwin
import Foundation

/// 按本地日期追加完整解析结果；文件 IO 与界面状态分离，不截断或去重历史。
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

    nonisolated let directoryURL: URL

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
        let fileURL = try prepareDirectory().appendingPathComponent(day + ".jsonl")
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
        return fileURL
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
        let url = directoryURL.appendingPathComponent(day + ".jsonl")
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

    nonisolated static func isValidDay(_ day: String) -> Bool {
        day.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
            && day.utf8.count == 10 && day.utf8.allSatisfy { $0 == 45 || (48...57).contains($0) }
    }
}
