import Foundation
import Network

/// Resolves the current Bonjour-advertised port for `_remotepairing._tcp` on the
/// LocalDevVPN tunnel interface. The on-device RemoteXPC/RSD service doesn't reliably
/// bind to a fixed port every session, so the port has to be discovered per-connection
/// rather than hardcoded.
enum RemotePairingDiscovery {
    private static let serviceType = "_remotepairing._tcp"

    /// Repeatedly browses for the service, retrying if the VPN tunnel interface only just came
    /// up and hasn't finished advertising over mDNS yet (e.g. VPN connected after app launch,
    /// then the user hits Retry immediately). A single 3s browse can lose that race even though
    /// the service shows up moments later, which used to make every retry fall back to the
    /// hardcoded `RP_PAIRING_PORT` and fail outright when the on-device service wasn't actually
    /// bound there. Returns `nil` only if every attempt comes up empty.
    static func resolvePort(attempts: Int = 3, timeoutPerAttempt: TimeInterval = 2, delayBetweenAttempts: TimeInterval = 1) -> UInt16? {
        for attempt in 0..<attempts {
            if let port = resolvePortOnce(timeout: timeoutPerAttempt) {
                return port
            }
            if attempt < attempts - 1 {
                Thread.sleep(forTimeInterval: delayBetweenAttempts)
            }
        }
        return nil
    }

    /// Browses for the service and resolves the first result's port.
    /// Returns `nil` if nothing is found within `timeout`.
    private static func resolvePortOnce(timeout: TimeInterval) -> UInt16? {
        let semaphore = DispatchSemaphore(value: 0)
        var resolvedPort: UInt16?
        let lock = NSLock()

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .tcp)
        var connection: NWConnection?
        var finished = false

        func finish(_ port: UInt16?) {
            lock.lock()
            guard !finished else { lock.unlock(); return }
            finished = true
            resolvedPort = port
            lock.unlock()
            semaphore.signal()
        }

        browser.browseResultsChangedHandler = { results, _ in
            guard connection == nil, let result = results.first else { return }
            let conn = NWConnection(to: result.endpoint, using: .tcp)
            connection = conn
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if case let .hostPort(_, port) = conn.currentPath?.remoteEndpoint {
                        finish(port.rawValue)
                    } else {
                        finish(nil)
                    }
                    conn.cancel()
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .userInitiated))
        }
        browser.start(queue: .global(qos: .userInitiated))

        _ = semaphore.wait(timeout: .now() + timeout)
        browser.cancel()
        connection?.cancel()

        lock.lock()
        let result = resolvedPort
        lock.unlock()
        return result
    }
}
