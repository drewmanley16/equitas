import Foundation

enum APIError: Error, LocalizedError {
    case badStatus(Int)
    case decodingFailed
    case noData

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Server returned status \(code)"
        case .decodingFailed:      return "Failed to decode server response"
        case .noData:              return "No data received"
        }
    }
}
