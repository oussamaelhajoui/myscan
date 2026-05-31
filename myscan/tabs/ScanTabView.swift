//
//  ScanTabView.swift
//  myscan
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import SwiftUI
import SwiftData
import Network

private struct ScanPortHit: Sendable {
    let host: String
    let port: Int
}

private final class ScanLiveOutputBuffer: @unchecked Sendable {
    nonisolated(unsafe) private var pendingLines: [String] = []
    nonisolated(unsafe) private var pendingOpenHits: [ScanPortHit] = []
    nonisolated(unsafe) private var openHits: [ScanPortHit] = []
    nonisolated(unsafe) private var completedCount = 0
    nonisolated(unsafe) private var scheduled = false
    private let lock = NSLock()
    private let flush: @MainActor (_ lines: [String], _ openHits: [ScanPortHit], _ completedCount: Int) -> Void

    nonisolated init(flush: @escaping @MainActor (_ lines: [String], _ openHits: [ScanPortHit], _ completedCount: Int) -> Void) {
        self.flush = flush
    }

    nonisolated func record(host: String, port: Int, isOpen: Bool) {
        let shouldSchedule = lock.withLock {
            pendingLines.append("\(host):\(port) - \(isOpen ? "OPEN" : "CLOSED")")
            completedCount += 1
            if isOpen {
                let hit = ScanPortHit(host: host, port: port)
                pendingOpenHits.append(hit)
                openHits.append(hit)
            }
            if scheduled { return false }
            scheduled = true
            return true
        }

        if shouldSchedule {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.flushPending()
            }
        }
    }

    nonisolated func flushPending() {
        let payload: (lines: [String], hits: [ScanPortHit], completed: Int) = lock.withLock {
            scheduled = false
            let lines = pendingLines
            let hits = pendingOpenHits
            let completed = completedCount
            pendingLines.removeAll()
            pendingOpenHits.removeAll()
            return (lines, hits, completed)
        }

        guard !payload.lines.isEmpty || !payload.hits.isEmpty else { return }
        Task { @MainActor in
            flush(payload.lines, payload.hits, payload.completed)
        }
    }

    nonisolated func openResultsSnapshot() -> [ScanPortHit] {
        lock.withLock { openHits }
    }
}

struct ScanTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [ScanFolder]
    @Query private var configs: [ScanConfiguration]

    @State private var isScanning = false
    @State private var progressText = "Idle"
    @State private var activeHostPort: (String, Int)? = nil
    @State private var recentLines: [String] = []
    @State private var folderName: String = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
    @State private var token: CancellationToken? = nil

    @State private var hostToOpenPorts: [String: Set<Int>] = [:]
    @State private var showSavePrompt: Bool = false
    @State private var pendingScan: Scan? = nil
    @State private var scanTask: Task<Void, Never>? = nil

    @State private var enableRetry: Bool = true
    @State private var scanProgress: Double = 0
    @State private var scanETAText: String = "ETA --"

    private let scanner = NetworkScanner()
    
    private var placeScanUIAtBottom: Bool { activeConfig.scanUIBottom }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if placeScanUIAtBottom {
                    // Found Hosts, Live Output, Configuration
                    Spacer()
                    foundHostsCard
                    liveOutputCard
                    configurationCard
                } else {
                    // Configuration, Live Output, Found
                    configurationCard
                    liveOutputCard
                    foundHostsCard
                    Spacer()
                }

                if let hp = activeHostPort {
                    HStack {
                        Text("Scanning:").font(.subheadline).foregroundStyle(.secondary)
                        Text("\(hp.0):\(hp.1)").font(.body).bold()
                    }
                }
            }
            .padding()
            .navigationTitle("Scan")
            .sheet(isPresented: $showSavePrompt) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Save scan").font(.title2).bold()
                        Picker("Existing", selection: $folderName) {
                            ForEach(folders.map { $0.name }, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .pickerStyle(.wheel)
                        Text("Or new name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("New folder name", text: $folderName)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("Cancel") { showSavePrompt = false }
                            Spacer()
                            Button("Save") {
                                if let s = pendingScan {
                                    let folder = ensureFolder(named: folderName)
                                    folder.scans.append(s)
                                    try? modelContext.save()
                                }
                                pendingScan = nil
                                showSavePrompt = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .navigationTitle("Save Scan")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SelectFolderForScan"))) { note in
                if let name = note.userInfo?["name"] as? String { folderName = name }
            }
            .onAppear {
                enableRetry = activeConfig.enableRetry
            }
            .onChange(of: enableRetry) {
                let cfg = activeConfig
                cfg.enableRetry = enableRetry
                try? modelContext.save()
            }
        }
    }

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Configuration").font(.headline)
                Spacer()
                Button {
                    clearScanOutput()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                Button {
                    showSavePrompt = true
                } label: {
                    Label("Save As", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }
            HStack {
                TextField("Folder name", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                Toggle("Retry once", isOn: $enableRetry)
                    .toggleStyle(.switch)
            }
            HStack(spacing: 12) {
                Button(isScanning ? "Stop" : "Start Scan") {
                    if isScanning { stopScan() } else { startScan() }
                }
                .buttonStyle(.borderedProminent)
                ProgressView().opacity(isScanning ? 1 : 0)
                VStack(alignment: .leading, spacing: 4) {
                    Text(progressText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ProgressView(value: scanProgress)
                        .frame(width: 160)
                    Text(scanETAText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if isScanning {
                    Button("Stop & Save") {
                        stopScan()
                        showSavePrompt = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var liveOutputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Output").font(.headline)
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground))
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(recentLines.enumerated()), id: \.offset) { idx, line in
                                Text(line)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(line.contains("OPEN") ? .green : .primary)
                                    .id(idx)
                            }
                        }
                        .padding(8)
                        .onChange(of: recentLines.count) {
                            guard recentLines.count > 0 else { return }
                            withAnimation { proxy.scrollTo(recentLines.count - 1, anchor: .bottom) }
                        }
                    }
                }
            }
            .frame(height: 120)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var foundHostsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Found Hosts").font(.headline)
            if hostToOpenPorts.isEmpty {
                Text("Nothing found yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
            } else {
                ForEach(hostToOpenPorts.keys.sorted(), id: \.self) { host in
                    let ports = hostToOpenPorts[host]!.sorted()
                    HStack(alignment: .firstTextBaseline) {
                        Text(host)
                            .font(.subheadline)
                            .frame(width: 140, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ports.map(String.init).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                ForEach(ports, id: \.self) { p in
                                    if let name = knownServiceName(for: p) {
                                        Text(name)
                                            .font(.system(size: 10, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color(.tertiarySystemFill)))
                                    }
                                }
                            }
                        }
                        Spacer()
                        quickOpenButtons(for: host, ports: ports)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var activeConfig: ScanConfiguration {
        if let cfg = configs.first { return cfg }
        let cfg = ScanConfiguration()
        cfg.enableRetry = true
        cfg.scanUIBottom = false
        modelContext.insert(cfg)
        try? modelContext.save()
        return cfg
    }

    private func startScan() {
        isScanning = true
        progressText = "Starting..."
        scanProgress = 0
        scanETAText = "ETA calculating..."
        recentLines.removeAll()
        hostToOpenPorts.removeAll()
        pendingScan = nil

        let cfg = activeConfig
        let prefix = cfg.subnetPrefix?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detected = Subnet.detected(startHost: cfg.startHost, endHost: cfg.endHost)
        let effectivePrefix = (prefix?.isEmpty == false ? prefix! : detected?.prefix) ?? "192.168.1"
        let subnet = Subnet(prefix: effectivePrefix, hostRange: cfg.startHost...cfg.endHost)
        let ports = cfg.targetPorts
        let timeout = cfg.timeoutSeconds
        let concurrency = cfg.maxConcurrency
        let shouldRetry = enableRetry
        let saveBehavior = cfg.saveBehavior
        let selectedFolderName = folderName
        let scanner = scanner
        let totalChecks = max(1, subnet.hostRange.count * ports.count * (shouldRetry ? 2 : 1))
        let startedAt = Date()

        let scan = Scan(subnetDescription: "\(subnet.prefix).x ports: \(ports)")
        pendingScan = scan

        let newToken = CancellationToken()
        token = newToken

        let progressHandler: @Sendable (String, Int) -> Void = { host, port in
            Task { @MainActor in
                activeHostPort = (host, port)
                progressText = "Scanning \(host):\(port)"
            }
        }

        let outputBuffer = ScanLiveOutputBuffer { lines, openHits, completedCount in
            recentLines.append(contentsOf: lines)
            if recentLines.count > 1_000 { recentLines.removeFirst(recentLines.count - 1_000) }
            for hit in openHits {
                hostToOpenPorts[hit.host, default: []].insert(hit.port)
            }

            scanProgress = min(1, Double(completedCount) / Double(totalChecks))
            scanETAText = Self.etaText(startedAt: startedAt, completed: completedCount, total: totalChecks)
        }

        let resultHandler: @Sendable (String, Int, Bool) -> Void = { host, port, isOpen in
            outputBuffer.record(host: host, port: port, isOpen: isOpen)
        }

        scanTask?.cancel()
        scanTask = Task.detached {
            await scanner.scan(
                subnet: subnet,
                ports: ports,
                timeout: timeout,
                concurrency: concurrency,
                token: newToken,
                onProgress: progressHandler,
                onResult: resultHandler
            )

            if shouldRetry && !newToken.isCancelled {
                await scanner.scan(
                    subnet: subnet,
                    ports: ports,
                    timeout: timeout,
                    concurrency: concurrency,
                    token: newToken,
                    onProgress: progressHandler,
                    onResult: resultHandler
                )
            }

            outputBuffer.flushPending()
            let finalOpenResults = outputBuffer.openResultsSnapshot()

            await MainActor.run {
                isScanning = false
                activeHostPort = nil
                progressText = newToken.isCancelled ? "Cancelled" : "Done"
                scanProgress = newToken.isCancelled ? scanProgress : 1
                scanETAText = newToken.isCancelled ? "ETA --" : "ETA done"
                pendingScan?.finishedAt = Date()
                if let s = pendingScan {
                    s.results = finalOpenResults.map { ScanResult(host: $0.host, port: $0.port, isOpen: true) }
                }
                for hit in finalOpenResults {
                    hostToOpenPorts[hit.host, default: []].insert(hit.port)
                }

                switch saveBehavior {
                case .auto:
                    if let s = pendingScan {
                        let folder = ensureFolder(named: selectedFolderName)
                        folder.scans.append(s)
                        try? modelContext.save()
                        pendingScan = nil
                    }
                case .prompt:
                    showSavePrompt = true
                case .never:
                    pendingScan = nil
                }
            }
        }
    }

    private func stopScan() {
        token?.cancel()
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanETAText = "ETA --"
    }

    private func clearScanOutput() {
        recentLines.removeAll()
        hostToOpenPorts.removeAll()
        scanProgress = 0
        scanETAText = "ETA --"
        pendingScan = nil
    }

    private static func etaText(startedAt: Date, completed: Int, total: Int) -> String {
        guard completed > 0, completed < total else { return completed >= total ? "ETA done" : "ETA calculating..." }
        let elapsed = Date().timeIntervalSince(startedAt)
        let remaining = (elapsed / Double(completed)) * Double(total - completed)
        return "ETA \(Self.formatDuration(remaining))"
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }

    private func ensureFolder(named name: String) -> ScanFolder {
        if let existing = folders.first(where: { $0.name == name }) {
            return existing
        }
        let folder = ScanFolder(name: name)
        modelContext.insert(folder)
        return folder
    }

    private func knownServiceName(for port: Int) -> String? {
        switch port {
        case 20,21: return "FTP"
        case 22: return "SSH"
        case 23: return "Telnet"
        case 25: return "SMTP"
        case 53: return "DNS"
        case 67,68: return "DHCP"
        case 80,8080: return "HTTP"
        case 110: return "POP3"
        case 123: return "NTP"
        case 143: return "IMAP"
        case 161,162: return "SNMP"
        case 179: return "BGP"
        case 389: return "LDAP"
        case 443,8443: return "HTTPS"
        case 445: return "SMB"
        case 465: return "SMTPS"
        case 514: return "Syslog"
        case 587: return "Submission"
        case 631: return "IPP"
        case 993: return "IMAPS"
        case 995: return "POP3S"
        case 1433: return "MSSQL"
        case 1521: return "Oracle"
        case 1883: return "MQTT"
        case 1900: return "SSDP"
        case 2049: return "NFS"
        case 2379,2380: return "etcd"
        case 27017: return "MongoDB"
        case 3000: return "Node"
        case 3306: return "MySQL"
        case 3389: return "RDP"
        case 5432: return "Postgres"
        case 5672: return "AMQP"
        case 5900: return "VNC"
        case 6379: return "Redis"
        case 8081: return "HTTP-alt"
        case 8554: return "RTSP"
        default: return nil
        }
    }

    @ViewBuilder
    private func quickOpenButtons(for host: String, ports: [Int]) -> some View {
        if ports.contains(80) {
            openURLButton(urlString: "http://\(host)", systemImage: "arrow.up.right.square", label: "Open HTTP")
        }
        if ports.contains(8080) {
            openURLButton(urlString: "http://\(host):8080", systemImage: "arrow.up.right.square", label: "Open HTTP 8080")
        }
        if ports.contains(443) {
            openURLButton(urlString: "https://\(host)", systemImage: "lock.open.arrowtriangle.right", label: "Open HTTPS")
        }
        if ports.contains(8443) {
            openURLButton(urlString: "https://\(host):8443", systemImage: "lock.open.arrowtriangle.right", label: "Open HTTPS 8443")
        }
    }

    private func openURLButton(urlString: String, systemImage: String, label: String) -> some View {
        Button {
            if let url = URL(string: urlString) { UIApplication.shared.open(url) }
        } label: {
            Image(systemName: systemImage)
        }
        .accessibilityLabel(label)
    }
}

#Preview {
    ScanTabView()
        .modelContainer(for: [ScanFolder.self, Scan.self, ScanResult.self, ScanConfiguration.self], inMemory: true)
}
