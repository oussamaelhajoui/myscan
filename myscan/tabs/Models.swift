//
//  Models.swift
//  myscan
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import Foundation
import SwiftData

@Model
final class ScanFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var scans: [Scan]

    init(name: String, createdAt: Date = Date(), scans: [Scan] = []) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.scans = scans
    }
}

@Model
final class Scan {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var subnetDescription: String
    var results: [ScanResult]
    var note: String?

    init(startedAt: Date = Date(), subnetDescription: String, results: [ScanResult] = [], note: String? = nil) {
        self.id = UUID()
        self.startedAt = startedAt
        self.subnetDescription = subnetDescription
        self.results = results
        self.note = note
    }
}

@Model
final class ScanResult {
    @Attribute(.unique) var id: UUID
    var host: String
    var port: Int
    var isOpen: Bool

    init(host: String, port: Int, isOpen: Bool) {
        self.id = UUID()
        self.host = host
        self.port = port
        self.isOpen = isOpen
    }
}

@Model
final class ScanConfiguration {
    @Attribute(.unique) var id: UUID
    var targetPorts: [Int]
    var timeoutSeconds: Double
    var maxConcurrency: Int
    var filterOpenOnly: Bool
    var startHost: Int
    var endHost: Int
    var subnetPrefix: String?
    var saveBehaviorRaw: Int // 0=auto,1=prompt,2=never
    var enableRetry: Bool = true
    var scanUIBottom: Bool = false

    enum SaveBehavior: Int { case auto = 0, prompt = 1, never = 2 }

    var saveBehavior: SaveBehavior {
        get { SaveBehavior(rawValue: saveBehaviorRaw) ?? .auto }
        set { saveBehaviorRaw = newValue.rawValue }
    }

    init(targetPorts: [Int] = [80, 443, 22], timeoutSeconds: Double = 0.5, maxConcurrency: Int = 32, filterOpenOnly: Bool = true, startHost: Int = 1, endHost: Int = 254, saveBehavior: SaveBehavior = .auto, subnetPrefix: String? = nil, enableRetry: Bool = true, scanUIBottom: Bool = false) {
        self.id = UUID()
        self.targetPorts = targetPorts
        self.timeoutSeconds = timeoutSeconds
        self.maxConcurrency = maxConcurrency
        self.filterOpenOnly = filterOpenOnly
        self.startHost = startHost
        self.endHost = endHost
        self.subnetPrefix = subnetPrefix
        self.saveBehaviorRaw = saveBehavior.rawValue
        self.enableRetry = enableRetry
        self.scanUIBottom = scanUIBottom
    }
}
