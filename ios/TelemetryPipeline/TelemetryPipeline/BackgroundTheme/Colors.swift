//
//  Colors.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 1/3/26.
//

import Foundation
import SwiftUI

public extension Color {
    /// App brand color used across the UI (formerly hard-coded as RGB 0.11, 0.18, 0.31)
    static let eggshell = Color(red: 0.11, green: 0.18, blue: 0.31)
    static let navy = Color(red: 0.11, green: 0.18, blue: 0.31)
}

public extension View {
    /// Applies the app's standard squiggle border style.
    /// - Returns: A view with the standardized squiggle border applied.
    func squiggleCardBorder() -> some View {
        self.squiggleBorder(
            color: .navy,
            lineWidth: 4,
            cornerRadius: 24,
            amplitude: 3.0,
            wavelength: 20
        )
    }
}
