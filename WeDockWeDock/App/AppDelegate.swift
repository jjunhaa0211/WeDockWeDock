//
//  AppDelegate.swift
//  WeDockWeDock
//
//  Created by 박준하 on 1/27/26.
//

import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let appState = AppState()

    let favoritesStore = FavoritesStore()
    let hotkeyManager = HotkeyManager()

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2",
                                   accessibilityDescription: "weDockWeDock")
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
        }

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: DockPopoverView()
                .environmentObject(appState)
        )

        // 즐겨찾기 바뀔 때마다 핫키 재등록
        favoritesStore.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                Task { @MainActor in
                    self?.hotkeyManager.reload(from: items)
                }
            }
            .store(in: &cancellables)

        Task { @MainActor in
            hotkeyManager.reload(from: favoritesStore.items)
        }
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            appState.isExpanded.toggle()
        } else {
            appState.isExpanded = true
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
