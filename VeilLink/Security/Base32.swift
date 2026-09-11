import Foundation

enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    static func encode(_ data: Data) -> String {
        var output = ""
        var buffer = 0
        var bitsLeft = 0

        for byte in data {
            buffer = (buffer << 8) | Int(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                bitsLeft -= 5
                output.append(alphabet[(buffer >> bitsLeft) & 31])
            }
            if bitsLeft == 0 {
                buffer = 0
            } else {
                buffer &= (1 << bitsLeft) - 1
            }
        }

        if bitsLeft > 0 {
            output.append(alphabet[(buffer << (5 - bitsLeft)) & 31])
        }
        return output
    }
}
