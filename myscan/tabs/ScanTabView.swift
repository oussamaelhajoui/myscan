//
//  ScanTabView.swift
//  myscan
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import SwiftUI
import SwiftData
import Network

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
    @State private var pendingResults: [(host: String, port: Int)] = []

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
            Text("Configuration").font(.headline)
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
                Text(progressText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button("Clear") {
                    recentLines.removeAll()
                    hostToOpenPorts.removeAll()
                    pendingResults.removeAll()
                    pendingScan = nil
                }
                .buttonStyle(.bordered)
                Button("Save As…") { showSavePrompt = true }
                    .buttonStyle(.bordered)
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
        recentLines.removeAll()
        hostToOpenPorts.removeAll()
        pendingResults.removeAll()
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

        let foundHandler: @Sendable (String, Int) -> Void = { host, port in
            Task { @MainActor in
                recentLines.append("\(host):\(port) - OPEN")
                if recentLines.count > 50 { recentLines.removeFirst(recentLines.count - 50) }
                hostToOpenPorts[host, default: []].insert(port)
                pendingResults.append((host, port))
            }
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
                onFound: foundHandler
            )

            if shouldRetry && !newToken.isCancelled {
                await scanner.scan(
                    subnet: subnet,
                    ports: ports,
                    timeout: timeout,
                    concurrency: concurrency,
                    token: newToken,
                    onProgress: progressHandler,
                    onFound: foundHandler
                )
            }

            await MainActor.run {
                isScanning = false
                activeHostPort = nil
                progressText = newToken.isCancelled ? "Cancelled" : "Done"
                pendingScan?.finishedAt = Date()
                if let s = pendingScan {
                    s.results = pendingResults.map { ScanResult(host: $0.host, port: $0.port, isOpen: true) }
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
