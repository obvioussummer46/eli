import Foundation

/// Swift's `hashValue` is seeded per process, so it must never be used for ids
/// that are persisted to disk. This is a plain FNV-1a over UTF-8 bytes.
enum StableHash {
    static func string(_ value: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return String(hash, radix: 36)
    }
}
