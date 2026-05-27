# hashStack

A lean macOS menu bar hash generator. Type text or pick a file, get its MD5 /
SHA-1 / SHA-256 / SHA-512 hash, copy to clipboard. That's it.

Part of the **Stack** family of free macOS utilities by Michael Wild — sibling
to [clipStack](https://github.com/planBe/ClipStack),
[timeStack](https://github.com/planBe/TimeStack), and
[qrStack](https://github.com/planBe/QRStack).

## Status

**v0.1 — early development.** Working menu bar app with live text hashing,
file hashing via picker, and copy-to-clipboard. Drag-and-drop file support,
recent-files history, and hash-verification mode are planned for later
versions.

## Features (v0.1)

- Lives in the menu bar; no Dock icon
- Live hash output as you type
- File hashing via standard macOS Open File dialog (streams in 1 MB chunks —
  large files don't load fully into memory)
- Four algorithms: MD5, SHA-1, SHA-256, SHA-512
- One-click pull text from the system clipboard
- One-click copy hash to the system clipboard
- Pure SwiftUI + AppKit + CryptoKit; zero third-party dependencies
- App Sandbox + Hardened Runtime enabled (App Store ready)

## Privacy

hashStack does not collect, transmit, or store any data. Hashing happens
entirely on-device via Apple's CryptoKit. No network calls. Files are read
only on your explicit click in the Open File dialog. See
[PRIVACY.md](PRIVACY.md) for the full statement.

## Requirements

- macOS 13.0 (Ventura) or later
- Universal binary: Apple Silicon and Intel

## Building from source

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(install via `brew install xcodegen`). See [SETUP.md](SETUP.md).

```sh
git clone https://github.com/planBe/HashStack.git
cd HashStack
xcodegen generate
open HashStack.xcodeproj
```

Then ⌘R in Xcode.

## Roadmap

- [x] v0.1 — live menu bar hash generator (text + file) with copy-to-clipboard
- [ ] v0.2 — drag-and-drop files onto the popover; multiple-file batch hashing
- [ ] v0.3 — verify mode: paste expected hash + compare to computed
- [ ] v0.4 — recent-files history
- [ ] v0.5 — configurable global hotkey
- [ ] v1.0 — App Store + notarized GitHub Release

## License

MIT. See [LICENSE](LICENSE).

---

Made by Michael Wild — plan Be creative
