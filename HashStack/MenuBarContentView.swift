import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum InputMode: String, CaseIterable, Identifiable {
    case text = "Text"
    case file = "File"
    var id: String { rawValue }
}

struct MenuBarContentView: View {
    @StateObject private var fileHistory = FileHistoryStore()
    /// Computes file digests off the main thread, once per (file, algorithm).
    @StateObject private var fileHash = FileHashModel()
    @State private var algorithm: HashAlgorithm = .sha256
    @State private var inputMode: InputMode = .text
    @State private var inputText: String = ""
    @State private var pickedFileURL: URL?
    @State private var fileHashError: String?
    @State private var copiedFlash: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var expectedHash: String = ""

    private let popoverWidth: CGFloat = 380

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Picker("", selection: $inputMode) {
                ForEach(InputMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if inputMode == .text {
                textInputSection
            } else {
                fileInputSection
            }

            Divider()

            HStack {
                Text("Algorithm")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $algorithm) {
                    ForEach(HashAlgorithm.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 110)
            }

            hashOutputSection

            verifySection

            if !fileHistory.paths.isEmpty {
                Divider()
                recentFilesSection
            }

            Divider()

            Button("Quit hashStack") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: [.command])
                .controlSize(.small)
        }
        .padding(14)
        .frame(width: popoverWidth)
        // Whole-popover file drop: drag any file from Finder onto the popover
        // and it switches to File mode + hashes it. Beats hunting for the
        // Pick File... button.
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleFileDrop)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.accentColor, lineWidth: isDropTargeted ? 2 : 0)
                .padding(2)
                .allowsHitTesting(false)
        )
        // Single-parameter onChange: the app still deploys to macOS 13.
        .onChange(of: algorithm) { newAlgorithm in
            fileHash.request(url: pickedFileURL, algorithm: newAlgorithm)
        }
        .onChange(of: fileHash.result) { digest in
            // Only a file that actually hashed goes into Recent Files.
            if digest != nil, let url = pickedFileURL { fileHistory.add(url) }
        }
        .onChange(of: fileHash.failedURL) { failed in
            guard let failed, failed == pickedFileURL else { return }
            fileHashError = "Couldn't read file (it may have moved or been deleted)."
            pickedFileURL = nil
            fileHistory.releaseAccess()
            fileHash.request(url: nil, algorithm: algorithm)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "number")
                .font(.system(size: 14, weight: .semibold))
            Text("hashStack")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
    }

    // MARK: - Text input

    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextEditor(text: $inputText)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 60)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Button(action: pasteFromClipboard) {
                Label("Use Clipboard Text", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
        }
    }

    // MARK: - File input

    private var fileInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: pickFile) {
                Label(pickedFileURL?.lastPathComponent ?? "Pick File or Drop One Here…",
                      systemImage: "doc")
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .controlSize(.regular)

            if let error = fileHashError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Hash output

    @ViewBuilder
    private var hashOutputSection: some View {
        let hashValue = currentHash
        let hashing = inputMode == .file && fileHash.isHashing
        VStack(alignment: .leading, spacing: 6) {
            ScrollView {
                Text(hashValue.isEmpty ? (hashing ? "Hashing…" : "—") : hashValue)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(hashValue.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 56)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Button(action: { copyHash(hashValue) }) {
                Label(copiedFlash ? "Copied" : "Copy Hash",
                      systemImage: copiedFlash ? "checkmark" : "square.on.square")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            .disabled(hashValue.isEmpty)
            .keyboardShortcut("c", modifiers: [.command])
        }
    }

    // MARK: - Verify (paste-expected + auto-compare)

    private var verifySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Verify")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                verifyBadge
            }

            TextField("Paste expected hash to compare…", text: $expectedHash)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(verifyBorderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private var verifyBadge: some View {
        switch verifyState {
        case .idle:
            EmptyView()
        case .match:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("MATCH").foregroundStyle(.green)
                    .font(.system(size: 11, weight: .bold))
            }
        case .differ:
            HStack(spacing: 3) {
                Image(systemName: "xmark.seal.fill").foregroundStyle(.red)
                Text("DIFFER").foregroundStyle(.red)
                    .font(.system(size: 11, weight: .bold))
            }
        }
    }

    private var verifyBorderColor: Color {
        switch verifyState {
        case .idle: return Color(nsColor: .separatorColor)
        case .match: return .green
        case .differ: return .red
        }
    }

    // MARK: - Recent files

    private var recentFilesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("RECENT FILES")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                Spacer()
                Button("Clear") { fileHistory.clear() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            ForEach(fileHistory.paths, id: \.self) { path in
                // Through the bookmark: a bare path is unreadable after a relaunch.
                Button(action: { adoptFile(fileHistory.open(path)) }) {
                    Text((path as NSString).lastPathComponent)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(path)  // hover tooltip shows full path
            }
        }
    }

    // MARK: - State

    private var currentHash: String {
        switch inputMode {
        case .text:
            return inputText.isEmpty ? "" : HashGenerator.hash(inputText, with: algorithm)
        case .file:
            // Never hash here: `body` reads this several times per render.
            // FileHashModel computes it once, off the main thread.
            return pickedFileURL == nil ? "" : (fileHash.result ?? "")
        }
    }

    private var verifyState: VerifyState {
        HashVerifier.state(expected: expectedHash, computed: currentHash)
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string) {
            inputText = text
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Pick a file to hash"
        panel.prompt = "Hash"

        if panel.runModal() == .OK, let url = panel.url {
            fileHistory.releaseAccess()
            adoptFile(url)
        }
    }

    private func adoptFile(_ url: URL) {
        fileHashError = nil
        pickedFileURL = url
        inputMode = .file
        // Readability and Recent Files are settled by the model's result
        // (see the onChange handlers on `body`), not by a second, blocking hash.
        // Reset first so re-picking the same file re-reads it from disk.
        fileHash.request(url: nil, algorithm: algorithm)
        fileHash.request(url: url, algorithm: algorithm)
    }

    private func copyHash(_ value: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
        flashCopied()
    }

    private func flashCopied() {
        copiedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            copiedFlash = false
        }
    }

    /// Whole-popover file drop. Switches to File mode and hashes the dropped
    /// file. NSItemProvider is async — the input updates on the main queue
    /// once the URL is resolved.
    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        guard provider.canLoadObject(ofClass: URL.self) else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async {
                self.fileHistory.releaseAccess()
                self.adoptFile(url)
            }
        }
        return true
    }
}
