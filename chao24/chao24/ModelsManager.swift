//
//  ModelsManager.swift
//  chao24
//
//  Created by Zerui Chen on 3/11/24.
//

import CoreML

enum StylizationModel: String, CaseIterable, Identifiable {
    
    var id: String { rawValue }
    
    case identity = "Identity"
    case starryNight = "Starry Night"
    case cuphead = "Cuphead"
    case mosaic = "Mosaic"
    
    var modelFileName: String {
        switch self {
        case .identity: "IdentityStylizer"
        case .starryNight: "StarryNightStylizer"
        case .mosaic: "MosaicStylizer"
        case .cuphead: "CupheadStylizer"
        }
    }
}

class ModelsManager {
    
    static let shared = ModelsManager()
    
    private init() {}
    
    private var modelsCache = [StylizationModel: MLModel]()
    
    func get(model: StylizationModel) -> MLModel {
        modelsCache[model] ?? load(model: model)
    }
    
    private func load(model: StylizationModel) -> MLModel {
        guard let modelURL = Bundle.main.url(forResource: model.modelFileName, withExtension: "mlmodelc") else {
            fatalError("Failed to load model \(model.rawValue).mlmodelc")
        }
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        return try! MLModel(contentsOf: modelURL, configuration: config)
    }
    
    func predict(model: StylizationModel, image: CVPixelBuffer) -> CVPixelBuffer {
        let input = try! MLDictionaryFeatureProvider(dictionary: ["source": MLFeatureValue(pixelBuffer: image)])
        return try! get(model: model)
            .prediction(from: input)
            .featureValue(for: "styled")!
            .imageBufferValue!
    }
}
