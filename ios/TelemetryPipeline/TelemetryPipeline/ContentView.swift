//
//  ContentView.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/29/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    
                }
                
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Metric") {
                        print("Metric added")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .paperBackground()
        }
    }
}

#Preview {
    ContentView()
}
