//
//  ContentView.swift
//  HighlightMapRegion
//
//  Created by Ace on 6/7/2026.
//

import SwiftUI
import MapKit

struct ContentView: View {
    let countries: [String] = [
        "Reset",
        "Australia", "Japan", "Indonesia", "Vietnam", "China", "Thailand"
    ]
    @State private var selectedCountry: String = "Australia"
    
    var body: some View {
        VStack {
            VStack {
                Picker(selection: $selectedCountry, label: Text("Country")) {
                    ForEach(countries, id: \.self) { country in
                        Text(country)
                            .font(.system(size: 30))
                            .tag(country)
                    }
                }
            }
            
            CountryHighlightMap(countryName: selectedCountry)
        }
        .padding()
    }
}

func loadCountryOverlay(named countryName: String) -> [MKOverlay] {
    guard let url = Bundle.main.url(forResource: "countries", withExtension: "geojson") else {
        print("countries.geojson not found in bundle")
        return []
    }
    guard let data = try? Data(contentsOf: url) else {
        print("Unable to load countries.geojson data")
        return []
    }

    let decoder = MKGeoJSONDecoder()
    guard let features = try? decoder.decode(data) as? [MKGeoJSONFeature] else {
        print("Failed to decode GeoJSON features")
        return []
    }

    var overlays: [MKOverlay] = []

    // Try a set of common property keys used by country datasets
    let candidateKeys = [
        "ADMIN", "NAME", "name", "ADMIN_NAME", "SOVEREIGNT", "NAME_EN", "BRK_NAME", "FORMAL_EN"
    ]

    for feature in features {
        guard let propsData = feature.properties,
              let props = try? JSONSerialization.jsonObject(with: propsData) as? [String: Any] else { continue }

        // Find the first matching country name from the candidate keys
        if let countryValue = candidateKeys.compactMap({ props[$0] as? String }).first,
           countryValue == countryName {
            // Append all geometries that MapKit decoded as overlays
            for geometry in feature.geometry {
                if let overlay = geometry as? MKOverlay {
                    overlays.append(overlay)
                }
            }
        }
    }

    return overlays
}

struct CountryHighlightMap: View {
    @State private var polygons: [MKPolygon] = []

    var countryName: String
    
    var randomForegroundColor: Color {
        let newColor = Color.orange
        return newColor
    }
    
    var body: some View {
        Map {
            MapPolygon(worldBlankPolygon)
                .foregroundStyle(Color(white: 0.9))
                .mapOverlayLevel(level: .aboveLabels)
            ForEach(polygons.indices, id: \.self) { i in
                MapPolygon(polygons[i])
                    .foregroundStyle(randomForegroundColor)
                    .stroke(.black, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .mapOverlayLevel(level: .aboveLabels)
            }
        }
//        .mapStyle(.imagery(elevation: .flat))
        .mapStyle(.standard(
            elevation: .flat,
            emphasis: .muted,
            pointsOfInterest: .excludingAll,
            showsTraffic: false))
        .id(countryName)
        .onAppear {
            loadPolygons()
        }
        .onChange(of: countryName) { _, _ in
            loadPolygons()
        }
    }
    
    private func loadPolygons() {
        if countryName == "Reset" {
            self.polygons.removeAll()
            return
        }
        
        let overlays = loadCountryOverlay(named: countryName)
        let newPolygons: [MKPolygon] = overlays.flatMap { overlay -> [MKPolygon] in
            if let polygon = overlay as? MKPolygon {
                return [polygon]
            } else if let multi = overlay as? MKMultiPolygon {
                return multi.polygons
            } else {
                return []
            }
        }
        // Need some delay + animation to prevent deadlock-update.
        DispatchQueue.main.async {
            withAnimation {
                self.polygons += newPolygons
            }
        }
    }
    
    let worldBlankPolygon: MKPolygon = {
        var corners = [
            CLLocationCoordinate2D(latitude: 90, longitude: -180),
            CLLocationCoordinate2D(latitude: 90, longitude: 180),
            CLLocationCoordinate2D(latitude: -90, longitude: 180),
            CLLocationCoordinate2D(latitude: -90, longitude: -180)
        ]
        return MKPolygon(coordinates: &corners, count: corners.count)
    }()
}

#Preview {
    ContentView()
}
