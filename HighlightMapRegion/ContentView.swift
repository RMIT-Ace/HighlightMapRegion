//
//  ContentView.swift
//  HighlightMapRegion
//
//  Created by Ace on 6/7/2026.
//

import SwiftUI
import MapKit

struct ContentView: View {
    var body: some View {
        CountryHighlightMap(countryName: "Japan")
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

    var countryName: String = "Australia"
    
    var body: some View {
        Map {
            ForEach(polygons.indices, id: \.self) { i in
                MapPolygon(polygons[i])
                    .foregroundStyle(.blue.opacity(0.25))
                    .stroke(.blue, lineWidth: 2)
            }
        }
        .onAppear {
            let overlays = loadCountryOverlay(named: countryName)
            polygons = overlays.flatMap { overlay -> [MKPolygon] in
                if let polygon = overlay as? MKPolygon {
                    return [polygon]
                } else if let multi = overlay as? MKMultiPolygon {
                    return multi.polygons
                } else {
                    return []
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
