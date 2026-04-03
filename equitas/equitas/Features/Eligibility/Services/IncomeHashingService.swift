import Foundation
import CryptoKit

struct IncomeFields {
    var grossCents: Int
    var employerName: String
    var periodStart: Date
    var periodEnd: Date
}

struct HashedIncomeFields {
    let grossHash: Data
    let employerHash: Data
    let periodStartHash: Data
    let periodEndHash: Data
}

struct IncomeHashingService {
    func hash(_ fields: IncomeFields) -> HashedIncomeFields {
        func sha256(_ value: String) -> Data {
            Data(SHA256.hash(data: Data(value.utf8)))
        }
        func sha256Int(_ value: Int) -> Data {
            sha256("\(value)")
        }
        func sha256Date(_ date: Date) -> Data {
            sha256("\(Int(date.timeIntervalSince1970))")
        }

        let result = HashedIncomeFields(
            grossHash: sha256Int(fields.grossCents),
            employerHash: sha256(fields.employerName),
            periodStartHash: sha256Date(fields.periodStart),
            periodEndHash: sha256Date(fields.periodEnd)
        )
        // Raw values are stack-allocated and discarded after this scope
        return result
    }
}
