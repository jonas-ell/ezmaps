import SwiftUI
import GameMapCore

/// Platzhalter, bis die MapLibre-Karte kommt.
struct ContentView: View {
    @State private var style: MapStyle = .free

    var body: some View {
        VStack(spacing: 16) {
            Text(L("Karte kommt bald"))
                .font(.title2.bold())
            Picker(L("Stil"), selection: $style) {
                ForEach(MapStyle.allCases, id: \.self) { style in
                    Text(L(style.titleKey)).tag(style)
                }
            }
            .pickerStyle(.segmented)
            Text(L("© OpenStreetMap-Mitwirkende"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
