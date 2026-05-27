# Privacy Policy — hashStack

**Last updated:** 2026-05-27

hashStack is a local-only macOS menu bar hash generator. It does not collect,
transmit, store, or share any user data.

## What hashStack does with your input

When you type text into hashStack's popover, the text is hashed using Apple's
CryptoKit framework, entirely on your Mac. Nothing leaves your device.

When you click **Pick File…**, hashStack reads only the file you select and
computes its hash on-device. The file is read in streamed 1 MB chunks; no
file content is held in memory longer than needed for hashing, and no copy
is made anywhere.

The text you type is held in memory while the popover is open and discarded
when the app quits. hashStack does not write your input or any file content
to disk.

## Network

hashStack makes no network requests of any kind. There is no telemetry,
analytics, crash reporting, ad SDK, or remote configuration.

## Clipboard

When you click **Use Clipboard Text**, hashStack reads the current system
clipboard contents (text only) and places them in the input field. When you
click **Copy Hash**, hashStack writes the computed hash string to the system
clipboard. No other clipboard access occurs.

## App Sandbox

hashStack runs inside macOS's App Sandbox with the most restrictive default
profile plus a single file-system entitlement
(`com.apple.security.files.user-selected.read-only`) that allows reading
files you explicitly pick via the standard macOS Open File dialog. With that
entitlement, hashStack can read a file ONLY when you pick it via the dialog
— there is no broader file system access, no scanning, no enumeration.

## Open source

hashStack's full source code is available at
[github.com/planBe/HashStack](https://github.com/planBe/HashStack). Anyone
can audit the privacy claims above by reading the code.

## Contact

Questions: [github.com/planBe/HashStack/issues](https://github.com/planBe/HashStack/issues)

---

Made by Michael Wild — plan Be creative
