//
//  NetworkScanner.swift
//  myscan
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import Foundation
import Network
import SystemConfiguration

struct Subnet {
    let prefix: String // e.g., "192.168.1"
    let hostRange: ClosedRange<Int> // e.g., 1...254
}

extension Subnet {
    nonisolated static func detected(startHost: Int, endHost: Int) -> Subnet? {
        guard let addr = NetworkScanner.getLocalIPv4Address(),
              let prefix = addr.split(separator: ".").prefix(3).joined(separator: ".") as String? else { return nil }
        return Subnet(prefix: prefix, hostRange: startHost...endHost)
    }
}

final class CancellationToken: @unchecked Sendable {
    nonisolated(unsafe) private var _isCancelled = false
    private let lock = NSLock()
    nonisolated var isCancelled: Bool { lock.withLock { _isCancelled } }
    nonisolated func cancel() { lock.withLock { _isCancelled = true } }
}

private extension NSLock {
    nonisolated func withLock<T>(_ body: () -> T) -> T { lock(); defer { unlock() }; return body() }
}

private final class CompletionState: @unchecked Sendable {
    nonisolated(unsafe) private var finished = false
    private let lock = NSLock()

    nonisolated init() {}

    nonisolated func claim() -> Bool {
        lock.withLock {
            if finished { return false }
            finished = true
            return true
        }
    }
}

final class NetworkScanner: @unchecked Sendable {
    nonisolated func tcpPing(host: String, port: Int, timeout: TimeInterval, queue: DispatchQueue = .global(), completion: @escaping (Bool) -> Void) {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let endpoint = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: UInt16(port))!
        let conn = NWConnection(host: endpoint, port: nwPort, using: params)

        let deadline = DispatchTime.now() + timeout
        let completionState = CompletionState()

        let finish: @Sendable (Bool) -> Void = { result in
            if completionState.claim() {
                conn.cancel()
                completion(result)
            }
        }

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(true)
            case .failed(_), .cancelled:
                finish(false)
            default:
                break
            }
        }

        conn.start(queue: queue)

        queue.asyncAfter(deadline: deadline) {
            finish(false)
        }
    }

    nonisolated func scan(
        subnet: Subnet,
        ports: [Int],
        timeout: TimeInterval,
        concurrency: Int = 32,
        token: CancellationToken? = nil,
        onProgress: @escaping @Sendable (_ host: String, _ port: Int) -> Void,
        onResult: @escaping @Sendable (_ host: String, _ port: Int, _ isOpen: Bool) -> Void
    ) async {
        await withCheckedContinuation { continuation in
            scan(subnet: subnet, ports: ports, timeout: timeout, concurrency: concurrency, token: token, onProgress: onProgress, onResult: onResult) {
                continuation.resume()
            }
        }
    }

    nonisolated func scan(
        subnet: Subnet,
        ports: [Int],
        timeout: TimeInterval,
        concurrency: Int = 32,
        token: CancellationToken? = nil,
        onProgress: @escaping @Sendable (_ host: String, _ port: Int) -> Void,
        onResult: @escaping @Sendable (_ host: String, _ port: Int, _ isOpen: Bool) -> Void,
        onFinish: @escaping @Sendable () -> Void
    ) {
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: max(1, concurrency))
        let queue = DispatchQueue(label: "scanner.queue", qos: .userInitiated, attributes: .concurrent)
        let schedulerQueue = DispatchQueue(label: "scanner.scheduler", qos: .userInitiated)

        schedulerQueue.async {
            var lastProgress = DispatchTime.now().uptimeNanoseconds
            let progressInterval: UInt64 = 120_000_000

            outer: for i in subnet.hostRange {
                for port in ports {
                    if token?.isCancelled == true { break outer }
                    let host = "\(subnet.prefix).\(i)"
                    semaphore.wait()
                    group.enter()
                    let now = DispatchTime.now().uptimeNanoseconds
                    if now - lastProgress >= progressInterval {
                        lastProgress = now
                        onProgress(host, port)
                    }
                    self.tcpPing(host: host, port: port, timeout: timeout, queue: queue) { open in
                        if token?.isCancelled == true {
                            semaphore.signal()
                            group.leave()
                            return
                        }
                        onResult(host, port, open)
                        semaphore.signal()
                        group.leave()
                    }
                }
            }

            group.notify(queue: schedulerQueue) {
                onFinish()
            }
        }
    }
    
    nonisolated static func getLocalIPv4Address() -> String? {
        var wifiAddress: String?
        var otherAddress: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                let interface = ptr!.pointee
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    if let name = String(validatingUTF8: interface.ifa_name), name != "lo0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        let ip = String(cString: hostname)
                        if name == "en0" { wifiAddress = ip } else { otherAddress = otherAddress ?? ip }
                    }
                }
                ptr = interface.ifa_next
            }
            freeifaddrs(ifaddr)
        }
        return wifiAddress ?? otherAddress
    }
}
