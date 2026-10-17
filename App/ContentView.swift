import SwiftUI
import EzMapsCore

/// Erste echte Karte: Neon City über MapLibre (GM-017). Suche, Route und Navigation folgen auf Basis von EzMapsCore.
struct ContentView: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NeonMapView()
                .ignoresSafeArea()
            OSMAttribution()
                .padding(.trailing, 12)
                .padding(.bottom, 8)
        }
        .overlay(alignment: .topLeading) {
            Text(L(MapStyle.neonCity.titleKey))
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.75))
                .padding(.leading, 16)
                .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
