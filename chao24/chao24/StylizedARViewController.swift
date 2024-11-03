//
//  StylizedARViewController.swift
//  chao24
//
//  Created by Zerui Chen on 2/11/24.
//

import UIKit
import SwiftUI
import ARKit
import RealityKit
import Combine

class StylizedARViewController: UIViewController {
    
    var chosenStylizationModel: StylizationModel = .starryNight
    var isIdentity = true
    var usedStylizationModel: StylizationModel {
        isIdentity ? .identity:chosenStylizationModel
    }
    
    let arSession: ARSession = .init()
    
    lazy var imageView = UIImageView(frame: UIScreen.main.bounds)
    lazy var arView = ARView(frame: UIScreen.main.bounds)
        
    let anchor = AnchorEntity(world: .zero)
    let portalEntity = ModelEntity()
    
    var isProcessing = false
    var lastTenProcessingTimes: [TimeInterval] = []
    
    var sceneEventsUpdateSubscription: Cancellable?
    var c: Cancellable?
        
    override func viewDidLoad() {
        super.viewDidLoad()
        let config = ARWorldTrackingConfiguration()
        config.videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats
            .filter { $0.imageResolution.equalTo(.init(width: 1280, height: 720)) && $0.framesPerSecond == 30 }.first!
        arSession.delegate = self
        arSession.run(config)
        
        imageView.frame = view.bounds
        imageView.contentMode = .scaleAspectFill
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(imageView)
        
                
        arView.session = arSession
        arView.environment.background = .color(.clear)
        arView.isOpaque = false
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        arView.scene.addAnchor(anchor)
        
        addPortal()
        
        c = NotificationCenter.default.publisher(for: .didRetrieveModel).sink { [weak self] notification in
            let entity = notification.object as! Entity
            entity.position = .init(x: 0, y: 0.1, z: -1)
            self?.anchor.addChild(entity)
        }
    }
    
    func addPortal() {
        
        func makeParticleEmitter(angle: Float) -> ModelEntity {
            var particles = ParticleEmitterComponent.Presets.sparks
            particles.timing = .repeating(warmUp: 0, emit: .init(duration: .infinity))
            let entity = ModelEntity()
            entity.components.set(particles)
            entity.transform.rotation = .init(angle: 90 / 180 * .pi + angle, axis: .init(x: 1, y: 0, z: 0))
            return entity
        }
        
//        portalEntity.components.set(particles)
//        portalEntity.orientation = simd_quatf(angle: 90 / 180 * .pi, axis: .init(x: 1, y: 0, z: 0))
//        portalEntity.position = .init(x: 0, y: 0, z: -1)
//        anchor.addChild(portalEntity)
        
        
        let radius: Float = 1  // Radius of the circle
        let numEmitters = 100    // Number of emitters in the circle
        
        for i in 0..<numEmitters {
            let angle = Float(i) / Float(numEmitters) * 2 * .pi
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            let position = SIMD3<Float>(x, y, -2) // z = 0 keeps it on the plane
            
            let emitterEntity = makeParticleEmitter(angle: angle)
            emitterEntity.position = position
            portalEntity.addChild(emitterEntity)
        }
        
        portalEntity.position = .init(x: 0, y: 0, z: -1)
        anchor.addChild(portalEntity)
    }
    
    func addPortal2() {
        var particles = ParticleEmitterComponent()
        particles.emitterShape = .cylinder
        particles.mainEmitter.birthRate = 1000
        particles.birthDirection = .normal
        particles.emitterShapeSize = [0.5, 0.05, 0.5]
        particles.mainEmitter.lifeSpan = 0.15
        particles.speed = 0.3
        particles.mainEmitter.size = 0.05
        particles.mainEmitter.opacityCurve = .linearFadeOut
        particles.mainEmitter.vortexDirection = .init(x: 0, y: 0, z: 1)
        particles.mainEmitter.vortexStrength = 10
        
        particles.mainEmitter.color = .evolving(
            start: .single(.yellow),
            end: .single(.orange.withAlphaComponent(0))
        )
        portalEntity.components.set(particles)
        portalEntity.orientation = simd_quatf(angle: 90 / 180 * .pi, axis: .init(x: 1, y: 0, z: 0))
        portalEntity.position = .init(x: 0, y: 0, z: -1)
        anchor.addChild(portalEntity)
    }
    
    func stylizeAndDisplay(frame: ARFrame) {
        isProcessing = true
        let start = Date()
        let buffer = try! CapturedImageSampler.getPixelBuffer(from: frame)
        let stylizedOutput = ModelsManager.shared.predict(model: usedStylizationModel, image: buffer)
        let image = UIImage(pixelBuffer: stylizedOutput)
        lastTenProcessingTimes.append((Date().timeIntervalSince(start)))
        lastTenProcessingTimes = lastTenProcessingTimes.suffix(10)
        DispatchQueue.main.async {
            self.imageView.image = image
//            let latency = Double(self.lastTenProcessingTimes.reduce(0, +)) / Double(self.lastTenProcessingTimes.count)
//            self.label.text = String(format: "%.2f", latency)
        }
        isProcessing = false
    }
}

extension StylizedARViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if !isProcessing {
            DispatchQueue.global(qos: .userInitiated).async {
                self.stylizeAndDisplay(frame: frame)
            }
        }
        let cameraPosition = simd_float3(frame.camera.transform.columns.3.x, frame.camera.transform.columns.3.y, frame.camera.transform.columns.3.z)
        let portalPosition = portalEntity.position
        let displacement = portalPosition - cameraPosition
        let distanceFromPortal = sqrt(displacement.x * displacement.x + displacement.y * displacement.y + displacement.z * displacement.z)
        print(distanceFromPortal)
        if distanceFromPortal <= 0.6 {
            isIdentity.toggle()
            portalEntity.position -= 10 * displacement
        }
    }
    
}
