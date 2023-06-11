//
//  CellularApp.swift
//  Cellular
//
//  Created by Xuan Han on 5/6/23.
//

import SwiftUI

@main
struct CellularApp: App {
    enum Views {
    case start, downloadApp
    }
    
    @State private var currentView: Views = .start
    
    var body: some Scene {
        WindowGroup {
            VStack {
                switch currentView {
                    case .start:
                        StartView(
                            handleNextButton: {
                                currentView = .downloadApp
                            }
                        )
                    case .downloadApp:
                        StartView(
                            handleNextButton: {
                                currentView = .downloadApp
                            }
                        )
                }
            }.frame(minWidth: 700, idealWidth: 900, maxWidth: 1100,
                    minHeight: 600, idealHeight: 800, maxHeight: 1000,
                    alignment: .center)
        }.windowStyle(.hiddenTitleBar)
    }
}
