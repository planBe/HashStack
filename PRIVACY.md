# Privacy Policy — hashStack

**Last updated:** 2026-10-12

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

**Recent Files** keeps the last 10 files you hashed in hashStack's own
preferences on your Mac: each file's path and a macOS bookmark that lets
hashStack read that file again after a restart, the same way the Open dialog
did. Click **Clear** to remove the list.

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
profile plus two file-system entitlements:
`com.apple.security.files.user-selected.read-only`, which allows reading
files you explicitly pick via the standard macOS Open File dialog or drop
onto the popover, and `com.apple.security.files.bookmarks.app-scope`, which
lets Recent Files re-read those same files, read-only, after a restart.
hashStack can read a file ONLY when you have picked or dropped it yourself
— there is no broader file system access, no scanning, no enumeration.

## Open source

hashStack's full source code is available at
[github.com/planBe/HashStack](https://github.com/planBe/HashStack). Anyone
can audit the privacy claims above by reading the code.

## Contact

Questions: [github.com/planBe/HashStack/issues](https://github.com/planBe/HashStack/issues)

---

Made by Michael Wild — plan Be creative
