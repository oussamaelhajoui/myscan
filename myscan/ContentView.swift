//
//  ContentView.swift
//  myscan
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var items: [Item]

    var body: some View {
        @Bindable var appState = appState

        return ZStack {
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            TabView(selection: $appState.selectedTab) {
                NavigationStack { Home() }
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(AppTab.home)

                NavigationStack { ScanTabView() }
                    .tabItem { Label("Scan", systemImage: "dot.radiowaves.left.and.right") }
                    .tag(AppTab.scan)

                NavigationStack { SettingsTabView() }
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
            }
            .tint(Color.accentColor)
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [ScanFolder.self, Scan.self, ScanResult.self, ScanConfiguration.self, Item.self], inMemory: true)
}
