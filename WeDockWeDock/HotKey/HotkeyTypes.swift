//
//  HotkeyTypes.swift
//  WeDockWeDock
//
//  Created by 박준하 on 1/27/26.
//

import Cocoa
import Carbon.HIToolbox

struct Modifiers: OptionSet, Codable, Hashable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let control = Modifiers(rawValue: 1 << 0)
    static let option  = Modifiers(rawValue: 1 << 1)
    static let shift   = Modifiers(rawValue: 1 << 2)
    static let command = Modifiers(rawValue: 1 << 3)

    init(ns: NSEvent.ModifierFlags) {
        var r = 0
        if ns.contains(.control) { r |= Modifiers.control.rawValue }
        if ns.contains(.option)  { r |= Modifiers.option.rawValue }
        if ns.contains(.shift)   { r |= Modifiers.shift.rawValue }
        if ns.contains(.command) { r |= Modifiers.command.rawValue }
        self.init(rawValue: r)
    }

    var carbonFlags: Int {
        var r = 0
        if contains(.control) { r |= controlKey }
        if contains(.option)  { r |= optionKey }
        if contains(.shift)   { r |= shiftKey }
        if contains(.command) { r |= cmdKey }
        return r
    }

    var symbolic: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option)  { s += "⌥" }
        if contains(.shift)   { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

struct KeyCombination: Codable, Hashable {
    var keyCode: Int
    var modifiers: Modifiers

    init(keyCode: Int, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        self.keyCode = Int(event.keyCode)
        self.modifiers = Modifiers(ns: event.modifierFlags)
    }

    var display: String { "\(modifiers.symbolic) \(keyCode)" }
}

// MARK: - System Reserved Hotkey Check
extension KeyCombination {
    var isReservedBySystem: Bool {
        var list: Unmanaged<CFArray>?
        let status = CopySymbolicHotKeys(&list)
        guard status == noErr, let arr = list?.takeRetainedValue() as? [[String: Any]] else {
            return false
        }

        for hk in arr {
            guard (hk[kHISymbolicHotKeyEnabled] as? Bool) == true else { continue }
            guard let code = hk[kHISymbolicHotKeyCode] as? Int else { continue }
            guard let mods = hk[kHISymbolicHotKeyModifiers] as? Int else { continue }

            if code == self.keyCode, mods == self.modifiers.carbonFlags {
                return true
            }
        }
        return false
    }
}
