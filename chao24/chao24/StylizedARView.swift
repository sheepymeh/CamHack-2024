//
//  StylizedARView.swift
//  chao24
//
//  Created by Zerui Chen on 2/11/24.
//

import SwiftUI

struct StylizedARView: UIViewControllerRepresentable {
    
    init(model: Binding<StylizationModel>) {
        self._model = model
    }
    
    @Binding var model: StylizationModel
    
    func makeUIViewController(context: Context) -> StylizedARViewController {
        StylizedARViewController()
    }
    
    func updateUIViewController(_ uiViewController: StylizedARViewController, context: Context) {
        uiViewController.chosenStylizationModel = model
    }
    
}
