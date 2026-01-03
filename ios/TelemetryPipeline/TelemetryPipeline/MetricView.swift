//
//  MetricView.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/29/25.
//

import SwiftUI

struct MetricView: View {
    var body: some View {
        VStack{
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .ignoresSafeArea()
    }
}

enum MetricSymbol: String, CaseIterable, Identifiable {
    case none, thermometer, gauge, waveform
    var id: String { rawValue }

    // If you're using your custom PNGs, add them to Assets.xcassets with these names.
    var assetName: String {
        switch self {
        case .none: return ""
        case .thermometer: return "Thermometer"
        case .gauge: return "Guage"
        case .waveform: return "Vibration"
        }
    }
}

struct AddMetricTopBlock: View {
    // Inputs you’ll later send to your backend
    @Binding var name: String
    @Binding var unit: String
    @Binding var selectedIcon: MetricSymbol

    // Theme colors (match your mock)
    private let navy = Color(red: 0.11, green: 0.18, blue: 0.31)
    private let cardFill = Color.white.opacity(0.22)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // NAME
            Text("Name")
                .font(.headline)
                .foregroundStyle(navy)

            TextField("", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(navy.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                )

            // ICON PICKER
            Text("Icon")
                .font(.headline)
                .foregroundStyle(navy)

            HStack(spacing: 14) {
                ForEach(MetricSymbol.allCases) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(selectedIcon == icon ? 0.35 : 0.18))

                            if icon == .none {
                                VStack {
                                    Image(systemName: "slash.circle")
                                        .font(.system(size: 28, weight: .regular))
                                        .foregroundStyle(navy.opacity(0.8))
                                    Text("")
                                        .font(.footnote)
                                        .foregroundStyle(navy.opacity(0.9))
                                }
                                .padding(14)
                            } else {
                                Image(icon.assetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(4)
                            }
                        }
                        .frame(height: 96)
                        .squiggleBorder(
                            color: navy.opacity(selectedIcon == icon ? 1.0 : 0.65),
                            lineWidth: selectedIcon == icon ? 3.5 : 3,
                            cornerRadius: 18,
                            amplitude: 2.4,
                            wavelength: 18
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(icon.rawValue))
                }
            }
            .padding(.vertical, 4)

            // UNIT
            Text("Unit")
                .font(.headline)
                .foregroundStyle(navy)

            TextField("", text: $unit)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(navy.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                )

        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardFill)
        )
        .squiggleBorder(color: navy, lineWidth: 4, cornerRadius: 24, amplitude: 3.0, wavelength: 20)
    }
}

#Preview {
    MetricView()
}

