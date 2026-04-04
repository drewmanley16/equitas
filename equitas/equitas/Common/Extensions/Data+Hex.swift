import Foundation

extension Data {
    nonisolated var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    nonisolated init?(hexString: String) {
        let len = hexString.count
        guard len % 2 == 0 else { return nil }
        var data = Data()
        data.reserveCapacity(len / 2)
        var idx = hexString.startIndex
        while idx < hexString.endIndex {
            let next = hexString.index(idx, offsetBy: 2)
            guard let byte = UInt8(hexString[idx..<next], radix: 16) else { return nil }
            data.append(byte)
            idx = next
        }
        self = data
    }
}
