//
//  SettingsTabView.swift
//  myscan
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import SwiftUI
import SwiftData

struct SettingsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [ScanConfiguration]

    @State private var portsText: String = ""
    @State private var timeout: Double = 0.5
    @State private var concurrency: Int = 32
    @State private var filterOpenOnly: Bool = true
    @State private var startHost: Int = 1
    @State private var endHost: Int = 254
    @State private var subnetPrefix: String = ""
    @State private var saveBehavior: ScanConfiguration.SaveBehavior = .auto
    @State private var scanUIBottom: Bool = false
    
    @State private var enableRetry: Bool = true
    @State private var svcHTTP: Bool = true
    @State private var svcHTTPS: Bool = true
    @State private var svcSSH: Bool = false
    @State private var svcFTP: Bool = false
    @State private var svcRDP: Bool = false
    @State private var svcSMB: Bool = false
    
    @State private var svcTelnet: Bool = false
    @State private var svcDNS: Bool = false
    @State private var svcNTP: Bool = false
    @State private var svcSNMP: Bool = false
    @State private var svcLDAP: Bool = false
    @State private var svcVNC: Bool = false
    @State private var svcMySQL: Bool = false
    @State private var svcPostgres: Bool = false
    @State private var svcMongo: Bool = false
    @State private var svcRedis: Bool = false
    @State private var svcMQTT: Bool = false
    @State private var svcHTTPAlt: Bool = false // 8080
    @State private var svcHTTPSAlt: Bool = false // 8443

    private struct SettingsFingerprint: Equatable {
        var portsText: String
        var timeout: Double
        var concurrency: Int
        var filterOpenOnly: Bool
        var startHost: Int
        var endHost: Int
        var subnetPrefix: String
        var saveBehavior: ScanConfiguration.SaveBehavior
        var scanUIBottom: Bool
        var enableRetry: Bool
        var services: [Bool]
    }

    private var settingsFingerprint: SettingsFingerprint {
        SettingsFingerprint(
            portsText: portsText,
            timeout: timeout,
            concurrency: concurrency,
            filterOpenOnly: filterOpenOnly,
            startHost: startHost,
            endHost: endHost,
            subnetPrefix: subnetPrefix,
            saveBehavior: saveBehavior,
            scanUIBottom: scanUIBottom,
            enableRetry: enableRetry,
            services: [
                svcHTTP, svcHTTPS, svcSSH, svcFTP, svcRDP, svcSMB,
                svcTelnet, svcDNS, svcNTP, svcSNMP, svcLDAP, svcVNC,
                svcMySQL, svcPostgres, svcMongo, svcRedis, svcMQTT,
                svcHTTPAlt, svcHTTPSAlt
            ]
        )
    }

    var body: some View {
        NavigationStack {
            settingsForm
            .navigationTitle("Settings")
            .onAppear(perform: load)
            .onChange(of: settingsFingerprint) { _, _ in save() }
        }
    }

    private var settingsForm: some View {
        Form {
            portsSection
            knownServicesSection
            subnetSection
            layoutSection
            hostRangeSection
            performanceSection
            reliabilitySection
            filterSection
            savingSection
        }
    }

    private var portsSection: some View {
        Section(header: Text("Ports")) {
            TextField("e.g. 80,443,22,8080", text: $portsText)
                .keyboardType(.numbersAndPunctuation)
        }
    }

    private var knownServicesSection: some View {
        Section(header: Text("Known services")) {
            NavigationLink("Manage known services") {
                KnownServicesView(
                    svcHTTP: $svcHTTP, svcHTTPS: $svcHTTPS, svcSSH: $svcSSH, svcFTP: $svcFTP, svcRDP: $svcRDP, svcSMB: $svcSMB,
                    svcTelnet: $svcTelnet, svcDNS: $svcDNS, svcNTP: $svcNTP, svcSNMP: $svcSNMP, svcLDAP: $svcLDAP, svcVNC: $svcVNC,
                    svcMySQL: $svcMySQL, svcPostgres: $svcPostgres, svcMongo: $svcMongo, svcRedis: $svcRedis, svcMQTT: $svcMQTT,
                    svcHTTPAlt: $svcHTTPAlt, svcHTTPSAlt: $svcHTTPSAlt
                )
            }
        }
    }

    private var subnetSection: some View {
        Section(header: Text("Subnet prefix")) {
            TextField("e.g. 192.168.2", text: $subnetPrefix)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var layoutSection: some View {
        Section(header: Text("Layout")) {
            Toggle("Place Scan UI at bottom", isOn: $scanUIBottom)
        }
    }

    private var hostRangeSection: some View {
        Section(header: Text("Host range")) {
            Stepper(value: $startHost, in: 1...254) { Text("Start host: \(startHost)") }
            Stepper(value: $endHost, in: 1...254) { Text("End host: \(endHost)") }
            Text("Range: .\(startHost) - .\(endHost)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var performanceSection: some View {
        Section(header: Text("Performance")) {
            Stepper(value: $timeout, in: 0.1...5.0, step: 0.1) {
                Text("Timeout: \(String(format: "%.1f", timeout))s")
            }
            Stepper(value: $concurrency, in: 1...128, step: 1) {
                Text("Concurrency: \(concurrency)")
            }
        }
    }

    private var reliabilitySection: some View {
        Section(header: Text("Reliability")) {
            Toggle("Retry once", isOn: $enableRetry)
        }
    }

    private var filterSection: some View {
        Section(header: Text("Filter")) {
            Toggle("Only store open results", isOn: $filterOpenOnly)
        }
    }

    private var savingSection: some View {
        Section(header: Text("Saving")) {
            Picker("Save scans", selection: $saveBehavior) {
                Text("Auto").tag(ScanConfiguration.SaveBehavior.auto)
                Text("Prompt").tag(ScanConfiguration.SaveBehavior.prompt)
                Text("Never").tag(ScanConfiguration.SaveBehavior.never)
            }
            .pickerStyle(.segmented)
        }
    }

    private func load() {
        let cfg = configs.first ?? ScanConfiguration(timeoutSeconds: 0.8)
        if configs.isEmpty { modelContext.insert(cfg) }
        portsText = cfg.targetPorts.map(String.init).joined(separator: ",")
        timeout = cfg.timeoutSeconds
        concurrency = cfg.maxConcurrency
        filterOpenOnly = cfg.filterOpenOnly
        startHost = cfg.startHost
        endHost = cfg.endHost
        subnetPrefix = configs.first?.subnetPrefix ?? ""
        saveBehavior = cfg.saveBehavior
        enableRetry = cfg.enableRetry
        scanUIBottom = cfg.scanUIBottom
        
        svcHTTP = UserDefaults.standard.object(forKey: "svcHTTP") as? Bool ?? true
        svcHTTPS = UserDefaults.standard.object(forKey: "svcHTTPS") as? Bool ?? true
        svcSSH = UserDefaults.standard.object(forKey: "svcSSH") as? Bool ?? false
        svcFTP = UserDefaults.standard.object(forKey: "svcFTP") as? Bool ?? false
        svcRDP = UserDefaults.standard.object(forKey: "svcRDP") as? Bool ?? false
        svcSMB = UserDefaults.standard.object(forKey: "svcSMB") as? Bool ?? false
        svcTelnet = UserDefaults.standard.object(forKey: "svcTelnet") as? Bool ?? false
        svcDNS = UserDefaults.standard.object(forKey: "svcDNS") as? Bool ?? false
        svcNTP = UserDefaults.standard.object(forKey: "svcNTP") as? Bool ?? false
        svcSNMP = UserDefaults.standard.object(forKey: "svcSNMP") as? Bool ?? false
        svcLDAP = UserDefaults.standard.object(forKey: "svcLDAP") as? Bool ?? false
        svcVNC = UserDefaults.standard.object(forKey: "svcVNC") as? Bool ?? false
        svcMySQL = UserDefaults.standard.object(forKey: "svcMySQL") as? Bool ?? false
        svcPostgres = UserDefaults.standard.object(forKey: "svcPostgres") as? Bool ?? false
        svcMongo = UserDefaults.standard.object(forKey: "svcMongo") as? Bool ?? false
        svcRedis = UserDefaults.standard.object(forKey: "svcRedis") as? Bool ?? false
        svcMQTT = UserDefaults.standard.object(forKey: "svcMQTT") as? Bool ?? false
        svcHTTPAlt = UserDefaults.standard.object(forKey: "svcHTTPAlt") as? Bool ?? false
        svcHTTPSAlt = UserDefaults.standard.object(forKey: "svcHTTPSAlt") as? Bool ?? false
    }

    private func save() {
        let ports = portsText.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let cfg = configs.first ?? {
            let c = ScanConfiguration()
            modelContext.insert(c)
            return c
        }()
        let trimmedPrefix = subnetPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        cfg.subnetPrefix = trimmedPrefix.isEmpty ? nil : trimmedPrefix
        
        var combined = Set(ports)
        if svcHTTP { combined.insert(80) }
        if svcHTTPAlt { combined.insert(8080) }
        if svcHTTPS { combined.insert(443) }
        if svcHTTPSAlt { combined.insert(8443) }
        if svcSSH { combined.insert(22) }
        if svcFTP { combined.insert(21) }
        if svcTelnet { combined.insert(23) }
        if svcDNS { combined.insert(53) }
        if svcNTP { combined.insert(123) }
        if svcSNMP { combined.insert(161); combined.insert(162) }
        if svcLDAP { combined.insert(389) }
        if svcRDP { combined.insert(3389) }
        if svcVNC { combined.insert(5900) }
        if svcSMB { combined.insert(445) }
        if svcMySQL { combined.insert(3306) }
        if svcPostgres { combined.insert(5432) }
        if svcMongo { combined.insert(27017) }
        if svcRedis { combined.insert(6379) }
        if svcMQTT { combined.insert(1883) }
        let finalPorts = combined.isEmpty ? [80,443,22] : Array(combined).sorted()
        cfg.targetPorts = finalPorts
        
        cfg.timeoutSeconds = timeout
        cfg.maxConcurrency = concurrency
        cfg.filterOpenOnly = filterOpenOnly
        cfg.startHost = min(startHost, endHost)
        cfg.endHost = max(startHost, endHost)
        cfg.saveBehavior = saveBehavior
        cfg.enableRetry = enableRetry
        cfg.scanUIBottom = scanUIBottom
        
        try? modelContext.save()
        UserDefaults.standard.set(svcHTTP, forKey: "svcHTTP")
        UserDefaults.standard.set(svcHTTPS, forKey: "svcHTTPS")
        UserDefaults.standard.set(svcSSH, forKey: "svcSSH")
        UserDefaults.standard.set(svcFTP, forKey: "svcFTP")
        UserDefaults.standard.set(svcRDP, forKey: "svcRDP")
        UserDefaults.standard.set(svcSMB, forKey: "svcSMB")
        UserDefaults.standard.set(svcTelnet, forKey: "svcTelnet")
        UserDefaults.standard.set(svcDNS, forKey: "svcDNS")
        UserDefaults.standard.set(svcNTP, forKey: "svcNTP")
        UserDefaults.standard.set(svcSNMP, forKey: "svcSNMP")
        UserDefaults.standard.set(svcLDAP, forKey: "svcLDAP")
        UserDefaults.standard.set(svcVNC, forKey: "svcVNC")
        UserDefaults.standard.set(svcMySQL, forKey: "svcMySQL")
        UserDefaults.standard.set(svcPostgres, forKey: "svcPostgres")
        UserDefaults.standard.set(svcMongo, forKey: "svcMongo")
        UserDefaults.standard.set(svcRedis, forKey: "svcRedis")
        UserDefaults.standard.set(svcMQTT, forKey: "svcMQTT")
        UserDefaults.standard.set(svcHTTPAlt, forKey: "svcHTTPAlt")
        UserDefaults.standard.set(svcHTTPSAlt, forKey: "svcHTTPSAlt")
    }
}

#Preview {
    SettingsTabView()
        .modelContainer(for: [ScanFolder.self, Scan.self, ScanResult.self, ScanConfiguration.self], inMemory: true)
}

struct KnownServicesView: View {
    @Binding var svcHTTP: Bool
    @Binding var svcHTTPS: Bool
    @Binding var svcSSH: Bool
    @Binding var svcFTP: Bool
    @Binding var svcRDP: Bool
    @Binding var svcSMB: Bool
    @Binding var svcTelnet: Bool
    @Binding var svcDNS: Bool
    @Binding var svcNTP: Bool
    @Binding var svcSNMP: Bool
    @Binding var svcLDAP: Bool
    @Binding var svcVNC: Bool
    @Binding var svcMySQL: Bool
    @Binding var svcPostgres: Bool
    @Binding var svcMongo: Bool
    @Binding var svcRedis: Bool
    @Binding var svcMQTT: Bool
    @Binding var svcHTTPAlt: Bool
    @Binding var svcHTTPSAlt: Bool

    var body: some View {
        Form {
            Section("Web") {
                Toggle("HTTP (80)", isOn: $svcHTTP)
                Toggle("HTTP Alt (8080)", isOn: $svcHTTPAlt)
                Toggle("HTTPS (443)", isOn: $svcHTTPS)
                Toggle("HTTPS Alt (8443)", isOn: $svcHTTPSAlt)
            }
            Section("Remote access") {
                Toggle("SSH (22)", isOn: $svcSSH)
                Toggle("RDP (3389)", isOn: $svcRDP)
                Toggle("VNC (5900)", isOn: $svcVNC)
                Toggle("Telnet (23)", isOn: $svcTelnet)
            }
            Section("File & Infra") {
                Toggle("SMB (445)", isOn: $svcSMB)
                Toggle("FTP (21)", isOn: $svcFTP)
                Toggle("DNS (53)", isOn: $svcDNS)
                Toggle("NTP (123)", isOn: $svcNTP)
                Toggle("SNMP (161/162)", isOn: $svcSNMP)
                Toggle("LDAP (389)", isOn: $svcLDAP)
            }
            Section("Databases & MQ") {
                Toggle("MySQL (3306)", isOn: $svcMySQL)
                Toggle("Postgres (5432)", isOn: $svcPostgres)
                Toggle("MongoDB (27017)", isOn: $svcMongo)
                Toggle("Redis (6379)", isOn: $svcRedis)
                Toggle("MQTT (1883)", isOn: $svcMQTT)
            }
        }
        .navigationTitle("Known services")
    }
}
