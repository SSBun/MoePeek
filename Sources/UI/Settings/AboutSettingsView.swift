import SwiftUI

struct AboutSettingsView: View {
    let updaterController: UpdaterController?

    @State private var showsReleaseNotes = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("MoePeek")
                .font(.title.bold())

            HStack(spacing: 6) {
                Text("Version \(appVersion) (\(buildNumber))")

                Button {
                    showsReleaseNotes.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Release Notes"))
                .help(Text("Release Notes"))
                .popover(isPresented: $showsReleaseNotes, arrowEdge: .trailing) {
                    releaseNotesPopover
                }
            }
            .foregroundStyle(.secondary)

            Text("Copyright © 2025-2026 MoePeek. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Licensed under AGPL-3.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if let updaterController {
                @Bindable var updater = updaterController

                Divider()
                    .padding(.horizontal, 40)

                HStack(spacing: 16) {
                    Button("Check for Updates...") {
                        updater.checkForUpdates()
                    }
                    .disabled(!updater.canCheckForUpdates)

                    Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://github.com/SSBun/MoePeek/issues")!) {
                    Label("Issue Feedback", systemImage: "ladybug")
                }
                .buttonStyle(.link)

                Link(destination: URL(string: "https://github.com/SSBun/MoePeek/discussions")!) {
                    Label("Community Discussions", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.link)
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var releaseNotesPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Release Notes")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if releaseNotes.isEmpty {
                Text("No release notes are available for this version.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(releaseNotes.enumerated()), id: \.offset) { _, line in
                            if line.hasPrefix("### ") {
                                Text(line.dropFirst(4))
                                    .font(.subheadline.bold())
                                    .accessibilityAddTraits(.isHeader)
                            } else {
                                Text(line.replacingOccurrences(of: "^- ", with: "• ", options: .regularExpression))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
                .frame(height: 220)
            }
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
    }

    private var releaseNotes: [Substring] {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let changelog = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        let lines = changelog.split(whereSeparator: \.isNewline)
        let versionHeading = "## [\(appVersion)]"
        guard let headingIndex = lines.firstIndex(where: {
            $0 == versionHeading || $0.hasPrefix(versionHeading + " ")
        }) else {
            return []
        }

        return Array(lines.dropFirst(headingIndex + 1).prefix {
            !$0.hasPrefix("## ") && !$0.hasPrefix("[")
        })
    }
}
