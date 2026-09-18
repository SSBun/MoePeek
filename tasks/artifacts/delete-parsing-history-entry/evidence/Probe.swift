import Foundation

@main
struct Probe {
    @MainActor
    static func main() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let store = ParsingHistoryStore(directoryURL: directory)
        if CommandLine.arguments.count > 2 {
            try await store.append(sourceText: CommandLine.arguments[2], result: .skip, providerName: "Fixture", providerID: "fixture")
            print("appended")
            return
        }
        let server = ParsingHistoryServer(store: store)
        let url = try await server.start()
        try url.absoluteString.write(to: directory.deletingLastPathComponent().appendingPathComponent("url"), atomically: true, encoding: .utf8)
        while !Task.isCancelled { try await Task.sleep(for: .seconds(1)) }
    }
}
