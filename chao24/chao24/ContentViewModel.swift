//
//  ContentViewModel.swift
//  chao24
//
//  Created by Zerui Chen on 3/11/24.
//

import SwiftUI
import RealityKit

@MainActor
class ContentViewModel: ObservableObject {
    
    @Published var createdObjects: [String] = []
    
    func retrieveListing() async throws {
        try await Task {
            let apiURL = URL(string: "https://jw2448.user.srcf.net/list.php")!
            let data = try await URLSession.shared.data(from: apiURL).0
            self.createdObjects = try JSONDecoder().decode([String].self, from: data)
        }.value
    }
    
    func retrieveObject(withPrompt prompt: String) async throws -> Entity {
        try await Task {
            let apiURL = URL(string: "https://jw2448.user.srcf.net/retrieve.php?prompt=\(prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
            let (url, response) = try await URLSession.shared.download(from: apiURL)
            let dstURL = URL.temporaryDirectory.appendingPathComponent(response.suggestedFilename!)
            if !FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.moveItem(at: url, to: dstURL)
            }
            let entity = try await Entity(contentsOf: dstURL)
            print(entity.components)
            return entity
        }.value
    }
    
    func generateObject(withPrompt prompt: String) {
        Task.detached {
            let apiURL = URL(string: "https://jw2448.user.srcf.net/generate.php?prompt=\(prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
            let response = try await URLSession.shared.data(from: apiURL)
        }
    }
}
