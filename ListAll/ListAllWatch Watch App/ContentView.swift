//
//  ContentView.swift
//  ListAllWatch Watch App
//
//  Created by Aleksi Sutela on 19.10.2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "list.bullet")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("ListAll")
                .font(.headline)
            Text("watchOS UI coming in Phase 69")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
