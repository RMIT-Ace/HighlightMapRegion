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
        "Australia", "Japan", "Indonesia", "Vietnam"
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
    
    var body: some View {
        Map {
            ForEach(polygons.indices, id: \.self) { i in
                MapPolygon(polygons[i])
                    .foregroundStyle(.blue.opacity(0.25))
                    .stroke(.blue, lineWidth: 2)
            }
        }
        .id(countryName)
        .onAppear {
            loadPolygons()
        }
        .onChange(of: countryName) { _, _ in
            loadPolygons()
        }
    }
    
    private func loadPolygons() {
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
          DispatchQueue.main.async {
              withAnimation {
                  self.polygons = newPolygons
              }
          }
      }
}

#Preview {
    ContentView()
}
