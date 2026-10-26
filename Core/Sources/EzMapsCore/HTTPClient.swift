import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking // GM-020: Linux (swift test in der Cloud); auf Apple-Systemen ohne Wirkung
#endif

/// Netzwerk über ein Protokoll, damit Tests ohne Internet laufen (Mock in den Tests).
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> Data
}

public enum HTTPError: Error, Equatable, Sendable {
    case status(Int, String)
    case invalidResponse
}

/// Echte Umsetzung mit URLSession.
public struct URLSessionHTTPClient: HTTPClient {
    /// GM-020: öffentliche OSM-Dienste verlangen eine erkennbare App-Kennung (Nutzungsregeln Photon/Valhalla FOSSGIS)
    public let userAgent: String?

    public init(userAgent: String? = nil) {
        self.userAgent = userAgent
    }

    public func send(_ request: URLRequest) async throws -> Data {
        var request = request
        if let ua = userAgent { request.setValue(ua, forHTTPHeaderField: "User-Agent") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HTTPError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw HTTPError.status(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
