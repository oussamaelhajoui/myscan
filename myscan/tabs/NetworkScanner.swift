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
    static func detected(startHost: Int, endHost: Int) -> Subnet? {
        guard let addr = NetworkScanner.getLocalIPv4Address(),
              let prefix = addr.split(separator: ".").prefix(3).joined(separator: ".") as String? else { return nil }
        return Subnet(prefix: prefix, hostRange: startHost...endHost)
    }
}

final class CancellationToken: @unchecked Sendable {
    private var _isCancelled = false
    private let lock = NSLock()
    var isCancelled: Bool { lock.withLock { _isCancelled } }
    func cancel() { lock.withLock { _isCancelled = true } }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T { lock(); defer { unlock() }; return body() }
}

final class NetworkScanner: @unchecked Sendable {
    func tcpPing(host: String, port: Int, timeout: TimeInterval, queue: DispatchQueue = .global(), completion: @escaping (Bool) -> Void) {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let endpoint = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: UInt16(port))!
        let conn = NWConnection(host: endpoint, port: nwPort, using: params)

        let deadline = DispatchTime.now() + timeout
        var finished = false

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if !finished { finished = true; conn.cancel(); completion(true) }
            case .failed(_), .cancelled:
                if !finished { finished = true; completion(false) }
            default:
                break
            }
        }

        conn.start(queue: queue)

        queue.asyncAfter(deadline: deadline) {
            if !finished { finished = true; conn.cancel(); completion(false) }
        }
    }

    func scan(subnet: Subnet, ports: [Int], timeout: TimeInterval, concurrency: Int = 32, token: CancellationToken? = nil, onProgress: @escaping (_ host: String, _ port: Int) -> Void, onFound: @escaping (_ host: String, _ port: Int) -> Void, onFinish: @escaping () -> Void) {
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: max(1, concurrency))
        let queue = DispatchQueue(label: "scanner.queue", attributes: .concurrent)

        outer: for i in subnet.hostRange {
            for port in ports {
                if token?.isCancelled == true { break outer }
                let host = "\(subnet.prefix).\(i)"
                semaphore.wait()
                group.enter()
                onProgress(host, port)
                tcpPing(host: host, port: port, timeout: timeout, queue: queue) { open in
                    if token?.isCancelled == true {
                        semaphore.signal(); group.leave(); return
                    }
                    if open { onFound(host, port) }
                    semaphore.signal()
                    group.leave()
                }
            }
        }

        group.notify(queue: queue) {
            onFinish()
        }
    }
    
    static func getLocalIPv4Address() -> String? {
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
