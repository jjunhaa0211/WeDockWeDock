//
//  SettingsView.swift
//  WeDockWeDock
//
//  Created by 박준하 on 1/27/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: FavoritesStore
    @EnvironmentObject var hotkeys: HotkeyManager

    @State private var name = ""
    @State private var bundleID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("즐겨찾기 & 단축키")
                .font(.headline)

            // MARK: - App Picker
            HStack {
                Button("앱 선택…") {
                    pickApplication()
                }

                Text(name.isEmpty ? "선택된 앱 없음" : name)
                    .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()

                Button("추가") {
                    guard !name.isEmpty, !bundleID.isEmpty else { return }
                    if store.items.contains(where: { $0.bundleID == bundleID }) { return }

                    store.items.append(FavoriteApp(name: name, bundleID: bundleID))
                    name = ""
                    bundleID = ""
                }
                .disabled(name.isEmpty || bundleID.isEmpty)
            }

            Divider()

            // MARK: - Favorites List
            List {
                ForEach(store.items) { item in
                    FavoriteRow(item: item)
                }
            }
            .frame(minWidth: 760, minHeight: 380)

            Text("‘앱 선택…’으로 등록하면 CFBundleIdentifier를 자동으로 저장합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }

    // MARK: - App Picker Logic
    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.title = "앱 선택"
        panel.prompt = "선택"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]

        if panel.runModal() == .OK, let url = panel.url {
            guard
                let bundle = Bundle(url: url),
                let id = bundle.bundleIdentifier
            else { return }

            let displayName =
                bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent

            self.name = displayName
            self.bundleID = id
        }
    }

    // MARK: - Row
    private struct FavoriteRow: View {
        @EnvironmentObject var store: FavoritesStore
        @EnvironmentObject var hotkeys: HotkeyManager

        let item: FavoriteApp

        @State private var recording = false
        @State private var showDeleteConfirm = false

        @State private var showHotkeyAlert = false
        @State private var hotkeyAlertMessage = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text(item.name)
                        Text(item.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(item.hotkey?.display ?? "단축키 없음")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 140, alignment: .trailing)

                    Button(recording ? "입력중..." : "단축키 지정") {
                        recording.toggle()
                    }
                    .background(
                        HotkeyRecorder(isRecording: $recording) { combo in
                            guard let combo else { return }

                            if combo.isReservedBySystem {
                                hotkeyAlertMessage = "이 단축키는 macOS에서 예약된 조합이라 사용할 수 없어요.\n다른 조합을 선택해주세요."
                                showHotkeyAlert = true
                                return
                            }

                            if store.items.contains(where: { $0.id != item.id && $0.hotkey == combo }) {
                                hotkeyAlertMessage = "이미 다른 즐겨찾기에 사용 중인 단축키예요.\n다른 조합을 선택해주세요."
                                showHotkeyAlert = true
                                return
                            }

                            if let idx = store.items.firstIndex(where: { $0.id == item.id }) {
                                store.items[idx].hotkey = combo
                            }
                        }
                    )
                    .alert("단축키 충돌", isPresented: $showHotkeyAlert) {
                        Button("확인", role: .cancel) {}
                    } message: {
                        Text(hotkeyAlertMessage)
                    }

                    Button("실행") {
                        HotkeyManager.launchOrFocus(bundleID: item.bundleID)
                    }

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .alert("즐겨찾기 삭제", isPresented: $showDeleteConfirm) {
                        Button("취소", role: .cancel) {}
                        Button("삭제", role: .destructive) {
                            store.items.removeAll { $0.id == item.id }
                        }
                    } message: {
                        Text("‘\(item.name)’을(를) 삭제할까요?\n지정된 단축키도 함께 제거됩니다.")
                    }
                }

                if let msg = hotkeys.conflicts[item.id] {
                    Text("⚠️ \(msg)")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Hotkey Recorder

struct HotkeyRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCaptured: (KeyCombination?) -> Void

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.updateRecording(isRecording)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isRecording: $isRecording, onCaptured: onCaptured)
    }

    final class Coordinator {
        @Binding var isRecording: Bool
        let onCaptured: (KeyCombination?) -> Void
        private var monitor: Any?

        init(isRecording: Binding<Bool>, onCaptured: @escaping (KeyCombination?) -> Void) {
            self._isRecording = isRecording
            self.onCaptured = onCaptured
        }

        func updateRecording(_ recording: Bool) {
            recording ? start() : stop()
        }

        private func start() {
            stop()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard self.isRecording else { return event }

                let combo = KeyCombination(event: event)
                self.onCaptured(combo)
                self.isRecording = false
                return nil // 키 입력 소비
            }
        }

        private func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit { stop() }
    }
}
