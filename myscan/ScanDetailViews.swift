//
//  ScanDetailViews.swift
//  myscan
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import SwiftUI
import SwiftData

struct FolderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [ScanFolder]
    @State private var renamingFolder: ScanFolder? = nil
    @State private var newName: String = ""

    var body: some View {
        List {
            Section("Scans") {
                ForEach(folders) { folder in
                    NavigationLink(destination: ScanListView(folder: folder)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(folder.name).font(.headline)
                            let stats = folderStats(folder)
                            Text("\(stats.hosts) hosts • \(stats.ports) ports • \(folder.scans.count) scans")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(folder)
                            try? modelContext.save()
                        } label: { Label("Delete", systemImage: "trash") }
                        Button {
                            renamingFolder = folder
                            newName = folder.name
                        } label: { Label("Rename", systemImage: "pencil") }
                        .tint(.blue)
                    }
                }
                .onDelete { indexSet in
                    indexSet.map { folders[$0] }.forEach { modelContext.delete($0) }
                    try? modelContext.save()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Scans")
        .alert("Rename", isPresented: Binding(get: { renamingFolder != nil }, set: { if !$0 { renamingFolder = nil } })) {
            TextField("New name", text: $newName)
            Button("Cancel", role: .cancel) { renamingFolder = nil }
            Button("Save") {
                if let f = renamingFolder { f.name = newName; try? modelContext.save() }
                renamingFolder = nil
            }
        }
    }

    private func folderStats(_ folder: ScanFolder) -> (hosts: Int, ports: Int) {
        let all = folder.scans.flatMap { $0.results }
        let hosts = Set(all.map { $0.host }).count
        let ports = Set(all.map { $0.port }).count
        return (hosts, ports)
    }
}

struct ScanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    let folder: ScanFolder

    var body: some View {
        List {
            Section("Scans") {
                ForEach(folder.scans.sorted(by: { $0.startedAt > $1.startedAt })) { scan in
                    NavigationLink(destination: ScanDetailView(scan: scan)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scan.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                            Text(scan.subnetDescription).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .onDelete { indexSet in
                    let items = indexSet.map { folder.scans.sorted(by: { $0.startedAt > $1.startedAt })[$0] }
                    items.forEach { scan in
                        if let idx = folder.scans.firstIndex(where: { $0.id == scan.id }) { folder.scans.remove(at: idx) }
                    }
                    try? modelContext.save()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(folder.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    NotificationCenter.default.post(name: Notification.Name("SelectFolderForScan"), object: nil, userInfo: ["name": folder.name])
                    appState.selectedTab = .scan
                } label: { Label("Add Scan", systemImage: "plus") }
            }
        }
    }
}

struct ScanDetailView: View {
    let scan: Scan

    var grouped: [String: [ScanResult]] {
        Dictionary(grouping: scan.results, by: { $0.host })
    }

    var body: some View {
        List {
            Section("Overview") {
                HStack {
                    Label("Started", systemImage: "clock")
                    Spacer()
                    Text(scan.startedAt.formatted(date: .numeric, time: .standard))
                        .foregroundStyle(.secondary)
                }
                if let finished = scan.finishedAt {
                    HStack {
                        Label("Finished", systemImage: "checkmark.circle")
                        Spacer()
                        Text(finished.formatted(date: .numeric, time: .standard))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Label("Results", systemImage: "list.bullet")
                    Spacer()
                    Text("\(scan.results.count)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)

            ForEach(grouped.keys.sorted(), id: \.self) { host in
                Section(host) {
                    let ports = grouped[host]?.map { $0.port }.sorted() ?? []
                    Text(ports.map(String.init).joined(separator: ", "))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Scan Details")
        .background(Color("Background").ignoresSafeArea())
    }
}
