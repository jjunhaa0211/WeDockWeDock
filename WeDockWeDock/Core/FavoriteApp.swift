//
//  FavoriteApp.swift
//  WeDockWeDock
//
//  Created by 박준하 on 1/27/26.
//

import Foundation
import Combine 

struct FavoriteApp: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var bundleID: String
    var hotkey: KeyCombination?

    init(id: UUID = UUID(), name: String, bundleID: String, hotkey: KeyCombination? = nil) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.hotkey = hotkey
    }
}

@MainActor
final class FavoritesStore: ObservableObject {
    @Published var items: [FavoriteApp] = [] {
        didSet { save() }
    }

    private let key = "wedockwedock.favorites.v1"

    init() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([FavoriteApp].self, from: data) {
            items = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
