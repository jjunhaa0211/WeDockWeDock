//
//  DockPopoverView.swift.swift
//  WeDockWeDock
//
//  Created by 박준하 on 1/27/26.
//

import SwiftUI
import AppKit

struct DockPopoverView: View {
    @EnvironmentObject private var appState: AppState
    @State private var runningApps: [NSRunningApplication] = []

    // 정말로 지울 것인지 확인하는 변수
    @State private var showQuitAllConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if appState.isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .padding(12)
        .frame(width: 320)
        .animation(.easeInOut(duration: 0.18), value: appState.isExpanded)
        .onAppear { loadRunningApps() }
        .alert("모든 프로그램을 종료할까요?", isPresented: $showQuitAllConfirm) {
            Button("취소", role: .cancel) { }
            Button("종료", role: .destructive) {
                quitAllAppsLikeCommandQ()
            }
        } message: {
            Text("저장되지 않은 작업이 있으면 데이터가 유실될 수 있어요.\n(⌘Q처럼 ‘정상 종료’ 요청을 보냅니다.)")
        }
    }

    private var header: some View {
        HStack {
            Text("WeDockWeDock")
                .font(.headline)

            Spacer()

            Text(appState.isExpanded ? "펼침" : "접힘")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button {
                            AppFocuser.focus(app)
                        } label: {
                            HStack(spacing: 8) {
                                Image(nsImage: app.icon ?? NSImage())
                                    .resizable()
                                    .frame(width: 18, height: 18)

                                Text(app.localizedName ?? app.bundleIdentifier ?? "Unknown")
                                    .lineLimit(1)

                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(height: 260)

            Divider()

            HStack {
                Button("모든 시스템 종료") {
                    showQuitAllConfirm = true
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
    }

    private var collapsedContent: some View {
        Text("아이콘을 다시 누르면 펼쳐집니다.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }

    private func loadRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    /// ⌘Q
    private func quitAllAppsLikeCommandQ() {
        let myBundleID = Bundle.main.bundleIdentifier

        let excludedBundleIDs: Set<String> = [
            myBundleID ?? "",
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.SystemUIServer",
            "com.apple.loginwindow"
        ]

        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { app in
                guard let bid = app.bundleIdentifier else { return false }
                return !excludedBundleIDs.contains(bid)
            }

        for app in apps {
            app.terminate()
        }
    }
}
