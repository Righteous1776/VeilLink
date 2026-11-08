/// Local editor state only. Bounds constrain input, not game rules; the reducer
/// still checks current cash, phase, fees and contract eligibility on submission.
public struct VeilopolyNumericInputDraft {
 public private(set) var text: String
 public let bounds: ClosedRange<Int>

 public init(text: String, bounds: ClosedRange<Int>) {
  self.text = text
  self.bounds = bounds
 }

 public var value: Int? {
  guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }),
        let number = Int(text), bounds.contains(number) else { return nil }
  return number
 }

 @discardableResult
 public mutating func append(_ digit: Int) -> Bool {
  guard (0...9).contains(digit) else { return false }
  let candidate = text == "0" ? String(digit) : text + String(digit)
  guard candidate.count <= String(max(0, bounds.upperBound)).count,
        candidate.utf8.allSatisfy({ (48...57).contains($0) }),
        let number = Int(candidate), number <= bounds.upperBound else { return false }
  text = candidate
  return true
 }

 public mutating func clear() { text = "" }
 public mutating func backspace() { if !text.isEmpty { text.removeLast() } }
}
