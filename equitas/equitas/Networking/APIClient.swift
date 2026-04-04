import Foundation

private struct APIErrorResponse: Decodable {
    let error: String
}

@MainActor final class APIClient {
    static let shared = APIClient()
    private let session = URLSession.shared

    func post<Body: Encodable, Response: Decodable>(
        endpoint: APIEndpoint,
        body: Body
    ) async throws -> Response {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.badStatus(0)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverMessage(http.statusCode, apiError.error)
            }
            throw APIError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func upload<Response: Decodable>(
        endpoint: APIEndpoint,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "document"
    ) async throws -> Response {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.badStatus(0) }
        guard (200..<300).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverMessage(http.statusCode, apiError.error)
            }
            throw APIError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func get<Response: Decodable>(endpoint: APIEndpoint) async throws -> Response {
        let request = URLRequest(url: endpoint.url)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.badStatus(0)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverMessage(http.statusCode, apiError.error)
            }
            throw APIError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
