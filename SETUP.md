# SETUP.md — hashStack

How to build hashStack from source.

## Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 16+ (Command Line Tools required: `xcode-select --install`)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build

```sh
git clone https://github.com/planBe/HashStack.git
cd HashStack
xcodegen generate
open HashStack.xcodeproj
```

Then ⌘R in Xcode to build and launch.

## Project structure

- `project.yml` — canonical XcodeGen spec. `HashStack.xcodeproj` is generated
  from this; never edit the `.xcodeproj` directly. Regenerate with
  `xcodegen generate` after any spec change.
- `HashStack/` — Swift source
  - `HashStackApp.swift` — `@main` entry, `MenuBarExtra` Scene
  - `HashGenerator.swift` — CryptoKit wrappers (MD5 / SHA-1 / SHA-256 /
    SHA-512); streams files in 1 MB chunks for memory efficiency
  - `MenuBarContentView.swift` — popover UI (mode picker, text input or file
    picker, algorithm picker, hash output, copy button)
  - `Assets.xcassets/` — `AppIcon` + `AccentColor`
  - `HashStack.entitlements` — App Sandbox + `files.user-selected.read-only`
    (for the Pick File... button)

## Build settings

Locked in `project.yml`:

- Bundle ID `com.planbecreative.HashStack`
- Bundle Display Name `hashStack` (lowercase brand)
- `LSUIElement = YES` (menu bar agent; no Dock icon)
- macOS 13.0 minimum
- App Sandbox + Hardened Runtime
- Universal binary (arm64 + x86_64)
- App Store category: `developer-tools`

## Troubleshooting

**`xcodebuild` fails with "no schemes":** regenerate with `xcodegen generate`.

**Code signing prompts for Team:** open `HashStack.xcodeproj` in Xcode →
Signing & Capabilities → Team dropdown → pick your Apple Developer account
(or "None (Sign to Run Locally)" for local builds).

**Pick File... button does nothing:** the `files.user-selected.read-only`
entitlement must be granted by macOS the first time you pick a file. Try
again — the dialog should appear.

**Hash differs from `shasum` CLI output:** verify both are reading the same
file content. hashStack streams the file as-is; `shasum -a 256` uses the
same SHA-256 algorithm.

## License

MIT. See [LICENSE](LICENSE).
