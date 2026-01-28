//
//  HotkeyRegistry.swift
//  WeDockWeDock
//
//  Created by 박준하 on 1/27/26.
//

import Cocoa
import Carbon.HIToolbox

final class HotkeyRegistry {
    private let signature = OSType(0x57445744) // 'WDWD'
    private var handlerRef: EventHandlerRef?

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1

    init() { installHandlerIfNeeded() }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        let upp: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            let registry = Unmanaged<HotkeyRegistry>.fromOpaque(userData).takeUnretainedValue()

            var hkID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            guard status == noErr, hkID.signature == registry.signature else {
                return OSStatus(eventNotHandledErr)
            }

            registry.handlers[hkID.id]?()
            return noErr
        }

        let types: [EventTypeSpec] = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                          eventKind: UInt32(kEventHotKeyPressed))
        ]

        InstallEventHandler(
            GetEventDispatcherTarget(),
            upp,
            types.count,
            types,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    @discardableResult
    func register(_ combo: KeyCombination, handler: @escaping () -> Void) -> UInt32? {
        let id = nextID
        nextID += 1

        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: signature, id: id)

        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            UInt32(combo.modifiers.carbonFlags),
            hkID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return nil }

        hotKeyRefs[id] = ref
        handlers[id] = handler
        return id
    }

    func unregisterAll() {
        for (_, ref) in hotKeyRefs { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
        handlers.removeAll()
    }
}
