//
//  HotkeyManager.swift
//  WeDockWeDock
//
//  Created by 박준하 on 1/27/26.
//

import Foundation
import AppKit
import Combine
import Carbon.HIToolbox

@MainActor
final class HotkeyManager: ObservableObject {
    /// UUID(즐겨찾기 id) -> 충돌 메시지
    @Published var conflicts: [UUID: String] = [:]

    private let signature: OSType = {
        // "WDWK"
        OSType(UInt32(bigEndian: 0x5744574B))
    }()

    private var eventHandlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1

    private var handlers: [UInt32: () -> Void] = [:]

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]

    // MARK: - Public

    // Favorites 변경 시마다 호출: 전부 해제 후 다시 등록
    func reload(from items: [FavoriteApp]) {
        unregisterAll()
        conflicts = [:]

        for item in items {
            guard let combo = item.hotkey else { continue }

            let status = register(combo: combo, forFavoriteID: item.id) { [bundleID = item.bundleID] in
                HotkeyManager.launchOrFocus(bundleID: bundleID)
            }

            if status != noErr {
                conflicts[item.id] = statusMessage(status)
            }
        }
    }

    static func launchOrFocus(bundleID: String) {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            AppFocuser.focus(running)
            return
        }

        NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleID,
                                             options: [.default],
                                             additionalEventParamDescriptor: nil,
                                             launchIdentifier: nil)
    }

    // MARK: - Register / Unregister

    private func ensureInstalledEventHandler() -> OSStatus {
        if eventHandlerRef != nil { return noErr }

        let handlerUPP: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return status }

            guard hotKeyID.signature == manager.signature else {
                return OSStatus(eventNotHandledErr)
            }

            if let action = manager.handlers[hotKeyID.id] {
                action()
                return noErr
            }

            return OSStatus(eventNotHandledErr)
        }

        let eventTypes: [EventTypeSpec] = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]

        return InstallEventHandler(
            GetEventDispatcherTarget(),
            handlerUPP,
            eventTypes.count,
            eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func register(combo: KeyCombination, forFavoriteID favoriteID: UUID, handler: @escaping () -> Void) -> OSStatus {
        let installStatus = ensureInstalledEventHandler()
        guard installStatus == noErr else { return installStatus }

        let id = nextID
        nextID &+= 1

        let hotKeyID = EventHotKeyID(signature: signature, id: id)

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            UInt32(combo.modifiers.carbonFlags),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )

        guard status == noErr, let hotKeyRef = ref else {
            return status
        }

        handlers[id] = handler
        hotKeyRefs[id] = hotKeyRef
        return noErr
    }

    private func unregisterAll() {
        for (id, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
            handlers.removeValue(forKey: id)
        }
        hotKeyRefs.removeAll()
    }

    private func statusMessage(_ status: OSStatus) -> String {
        "이미 다른 앱(또는 시스템)에서 사용 중이라 등록할 수 없어요. (status: \(status))"
    }

    deinit {
        Task { @MainActor in
            unregisterAll()
        }
    }
}
