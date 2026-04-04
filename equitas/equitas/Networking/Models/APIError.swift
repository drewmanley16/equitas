import Foundation

enum APIError: Error, LocalizedError {
    case badStatus(Int)
    case serverMessage(Int, String)
    case decodingFailed
    case noData

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Server returned status \(code)"
        case .serverMessage(_, let message):
            if let data = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                return detail
            }
            return message
        case .decodingFailed:      return "Failed to decode server response"
        case .noData:              return "No data received"
        }
    }
}
