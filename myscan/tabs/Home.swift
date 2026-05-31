//
//  Home.swift
//  myscan
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import SwiftUI
import SwiftData

struct Home: View {
    @Query private var folders: [ScanFolder]
    @Query private var scans: [Scan]
    @Query private var results: [ScanResult]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statsGrid
                    recentSection
                    foldersPreview
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: FolderListView()) {
                        Label("Folders", systemImage: "folder")
                    }
                }
            }
            .refreshable {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: "Total Scans", value: "\(scans.count)", symbol: "wave.3.right")
            statCard(title: "Unique Hosts", value: "\(Set(results.map { $0.host }).count)", symbol: "network")
            statCard(title: "Open Ports", value: "\(results.count)", symbol: "bolt.horizontal")
            statCard(title: "Folders", value: "\(folders.count)", symbol: "folder")
        }
    }

    private func statCard(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2).bold()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Scans").font(.headline)
                Spacer()
                NavigationLink("View All", destination: FolderListView())
            }
            ForEach(scans.sorted(by: { $0.startedAt > $1.startedAt }).prefix(5)) { scan in
                NavigationLink(destination: ScanDetailView(scan: scan)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(scan.startedAt, style: .time)
                                .font(.headline)
                            Text(scan.subnetDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                }
            }
        }
    }

    private var foldersPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Folders").font(.headline)
            ForEach(folders.prefix(3)) { folder in
                NavigationLink(destination: ScanListView(folder: folder)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(folder.name).font(.body)
                            Text("\(folder.scans.count) scans")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteFolder(folder)
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
    }

    private func deleteFolder(_ folder: ScanFolder) {
        modelContext.delete(folder)
        try? modelContext.save()
    }
}

#Preview {
    Home()
        .modelContainer(for: [ScanFolder.self, Scan.self, ScanResult.self, ScanConfiguration.self], inMemory: true)
}
