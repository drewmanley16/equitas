import Foundation

enum APIClientError: Error {
    case invalidBaseURL
    case badStatus(Int)
    case decoding
}

final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    private init() {}

    /// Base URL for the Equitas backend (simulator: Mac loopback).
    private var baseURL: URL {
        if let s = Bundle.main.object(forInfoDictionaryKey: "EquitasAPIBaseURL") as? String,
           let u = URL(string: s), !s.isEmpty {
            return u
        }
        return URL(string: "http://127.0.0.1:8787")!
    }

    private func url(for endpoint: APIEndpoint) throws -> URL {
        guard let u = URL(string: endpoint.path, relativeTo: baseURL) else { throw APIClientError.invalidBaseURL }
        return u.absoluteURL
    }

    func post<T: Encodable, R: Decodable>(endpoint: APIEndpoint, body: T) async throws -> R {
        let url = try url(for: endpoint)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIClientError.badStatus(-1) }
        guard (200 ... 299).contains(http.statusCode) else { throw APIClientError.badStatus(http.statusCode) }
        let dec = JSONDecoder()
        return try dec.decode(R.self, from: data)
    }

    func get<R: Decodable>(endpoint: APIEndpoint) async throws -> R {
        let url = try url(for: endpoint)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIClientError.badStatus(-1) }
        guard (200 ... 299).contains(http.statusCode) else { throw APIClientError.badStatus(http.statusCode) }
        return try JSONDecoder().decode(R.self, from: data)
    }
}
