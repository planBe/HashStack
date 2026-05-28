import AppKit
import Carbon.HIToolbox

/// Registers a global system hotkey using Carbon's RegisterEventHotKey.
///
/// Carbon (long deprecated, still functional and the only public API for
/// global hotkeys without Accessibility permission) lets hashStack stay
/// dependency-free and sandbox-clean per D-002.
///
/// **Default chord: ⌥⇧⌘H.** Chord audit (per memory
/// feedback_check_hotkey_conflicts_with_michaels_workflow):
///
/// - **H for Hash** — thematic + memorable.
/// - **Same modifiers as ClipStack's ⌥⇧⌘V + QRStack's ⌥⇧⌘R** — Stack-family
///   consistency.
/// - **Verified clean** against macOS system shortcuts (⌘H = Hide app,
///   ⌥⌘H = Hide Others, ⌘⇧H = Finder Home — none use the ⌥⇧⌘ trio with H),
///   Safari (⌘⇧H = Home navigate), Chrome, Xcode (⇧⌘H = system Hide forward),
///   VS Code, Terminal, Slack.
///
/// Configurable binding is queued for a later version; for now this is a
/// compile-time constant.
@MainActor
final class HotkeyManager {
    typealias Handler = () -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: Handler

    // ⌥⇧⌘H — H is keycode 4, modifiers are cmd+shift+option.
    private let keyCode: UInt32 = UInt32(kVK_ANSI_H)
    private let modifiers: UInt32 = UInt32(cmdKey | shiftKey | optionKey)
    private let signature: OSType = OSType(0x4853544B) // 'HSTK'
    private let hotKeyID: UInt32 = 1

    init(handler: @escaping Handler) {
        self.handler = handler
        registerHandler()
        registerHotkey()
    }

    deinit {
        if let hk = hotKeyRef {
            UnregisterEventHotKey(hk)
        }
        if let eh = eventHandler {
            RemoveEventHandler(eh)
        }
    }

    private func registerHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Pass `self` through as user data so the C callback can call back into us.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let userData = userData, let eventRef = eventRef else {
                    return noErr
                }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if status == noErr {
                    Task { @MainActor in
                        manager.handler()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    private func registerHotkey() {
        let hkID = EventHotKeyID(signature: signature, id: hotKeyID)
        RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
