import Foundation

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
    public init() {}

    public func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HTTPError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw HTTPError.status(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
