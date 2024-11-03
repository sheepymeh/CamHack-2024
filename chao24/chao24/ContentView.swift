//
//  ContentView.swift
//  chao24
//
//  Created by Zerui Chen on 2/11/24.
//

import SwiftUI
import RealityKit

extension String: @retroactive Identifiable {
    public var id: Self { self }
}

extension NSNotification.Name {
    static let didRetrieveModel = NSNotification.Name("didRetrieveModel")
}

struct ContentView : View {
    
    init() {
        model = .init()
    }
    
    @State var stylizationModel: StylizationModel = .starryNight
    @State var showingItemValue = false
    @State var prompt: String = ""
    @State var showLoadingHUD = false
    
    @ObservedObject var model: ContentViewModel

    var body: some View {
        ZStack {
            StylizedARView(model: $stylizationModel)
            
            Spacer()
            
            HStack {
                ForEach(StylizationModel.allCases.suffix(from: 1)) { model in
                    Image(model.modelFileName)
                        .resizable()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 2))
                        .frame(width: 64, height: 64)
                        .onTapGesture {
                            stylizationModel = model
                        }
                }
                
                Button {
                    showingItemValue.toggle()
                } label: {
                    Image(systemName: "arrow.2.circlepath.circle")
                }
            }
            .padding(.bottom)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .onAppear {
            Task.detached {
                try? await self.model.retrieveListing()
            }
        }
        .sheet(isPresented: $showingItemValue) {
            VStack {
                TextField(text: $prompt, prompt: Text("Describe the object")) {
                    Image(systemName: "plus.circle.fill")
                }
                .frame(maxHeight: 48)
                .padding()
                Spacer()
                Button {
                    Task.detached {
                        await model.generateObject(withPrompt: prompt)
//                        try await model.retrieveObject(withPrompt: prompt)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(prompt.isEmpty)
                List(model.createdObjects) { objectPrompt in
                    Text(objectPrompt)
                        .onTapGesture {
                            Task.detached { @MainActor in
                                showLoadingHUD = true
                                let object = try! await model.retrieveObject(withPrompt: objectPrompt)
                                NotificationCenter.default.post(name: .didRetrieveModel, object: object)
                                showingItemValue = false
                                showLoadingHUD = false
                            }
                        }
                }
                .refreshable {
                    try? await model.retrieveListing()
                }
            }
            .alert("Loading", isPresented: $showLoadingHUD) {
            }
        }
        
    }

}

#Preview {
    ContentView()
}
