# hashStack

A lean macOS menu bar hash generator. Type text or pick a file, get its MD5 /
SHA-1 / SHA-256 / SHA-512 hash, copy to clipboard. That's it.

Part of the **Stack** family of free macOS utilities by Michael Wild — sibling
to [clipStack](https://github.com/planBe/ClipStack),
[timeStack](https://github.com/planBe/TimeStack), and
[qrStack](https://github.com/planBe/QRStack).

## Status

**v0.4 — in development.** Working menu bar app with live text + file
hashing, drag-and-drop, verify mode (paste expected hash for an auto ✓/✗
match), recent-files history, copy-to-clipboard, and a global hotkey
(⌥⇧⌘H) to pop the menu from anywhere. Configurable hotkey binding is
planned for a later version.

## Features (v0.4)

- Lives in the menu bar; no Dock icon
- Live hash output as you type
- **Verify mode** — paste the expected hash in the field below the output;
  hashStack auto-compares and shows a big ✓ MATCH (green) or ✗ DIFFER (red)
  next to your input. Case- and whitespace-insensitive comparison
- **Drag-and-drop files** anywhere onto the popover — auto-switches to File
  mode and hashes the dropped file. Or use the standard macOS Open File
  dialog if you prefer
- **Recent files history** — last 10 hashed files persist across launches;
  click any entry to re-hash with the current algorithm (handy when
  iterating on a build output). Hover any entry for the full path
- File hashing streams in 1 MB chunks — large files don't load fully into
  memory
- Four algorithms: MD5, SHA-1, SHA-256, SHA-512
- **Global hotkey ⌥⇧⌘H** opens the popover from any app, even when hashStack
  doesn't have focus
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
- [x] v0.2 — verify mode (paste expected hash, auto ✓/✗ compare),
  drag-and-drop files onto the popover, NSStatusItem refactor for sticky
  popover behavior
- [x] v0.3 — recent-files history (last 10 hashed files, click to re-hash)
- [x] v0.4 — global hotkey ⌥⇧⌘H to open the popover from anywhere (Carbon
  RegisterEventHotKey; sandbox-clean, no Accessibility permission required)
- [ ] v0.5 — configurable hotkey binding (Settings UI)
- [ ] v0.6 — drag-onto-menu-bar-icon (drop a file on the # icon → auto-hash)
- [ ] v0.7 — multiple-file batch hashing
- [ ] v1.0 — App Store + notarized GitHub Release

## License

MIT. See [LICENSE](LICENSE).

---

Made by Michael Wild — plan Be creative
