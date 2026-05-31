//
//  ScannerTests.swift
//  myscanTests
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import Network
import XCTest
@testable import myscan

private final class ResultStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Bool] = [:]

    func set(_ value: Bool, for key: String) {
        lock.lock()
        storage[key] = value
        lock.unlock()
    }

    func value(for key: String) -> Bool? {
        lock.lock()
        let value = storage[key]
        lock.unlock()
        return value
    }
}

final class ScannerTests: XCTestCase {
    func testCancellationTokenStartsActiveAndCanCancel() {
        let token = CancellationToken()
        XCTAssertFalse(token.isCancelled)

        token.cancel()

        XCTAssertTrue(token.isCancelled)
    }

    func testScannerReportsOpenAndClosedResults() async throws {
        let listener = try NWListener(using: .tcp, on: .any)
        let ready = expectation(description: "listener ready")

        listener.newConnectionHandler = { connection in
            connection.start(queue: .global(qos: .userInitiated))
        }
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                ready.fulfill()
            }
        }
        listener.start(queue: .global(qos: .userInitiated))
        await fulfillment(of: [ready], timeout: 2)
        defer { listener.cancel() }

        guard let port = listener.port?.rawValue else {
            XCTFail("Expected listener to bind to a port")
            return
        }
        let openPort = Int(port)
        let closedPort = openPort == 65_535 ? openPort - 1 : openPort + 1

        let scanner = NetworkScanner()
        let subnet = Subnet(prefix: "127.0.0", hostRange: 1...1)
        let results = ResultStore()

        await scanner.scan(
            subnet: subnet,
            ports: [openPort, closedPort],
            timeout: 0.2,
            concurrency: 2,
            token: nil,
            onProgress: { _, _ in },
            onResult: { host, port, isOpen in
                results.set(isOpen, for: "\(host):\(port)")
            }
        )

        XCTAssertEqual(results.value(for: "127.0.0.1:\(openPort)"), true)
        XCTAssertEqual(results.value(for: "127.0.0.1:\(closedPort)"), false)
    }
}
