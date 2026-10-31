import Foundation

func check(_ header: String?, _ length: Int, _ start: Int?, _ end: Int?) {
    let actual = VeilNovelRangeParser.resolve(header, fileLength: length)
    if let start = start, let end = end {
        precondition(actual?.first == start, "bad start for \(header ?? "nil")")
        precondition(actual?.last == end, "bad end for \(header ?? "nil")")
    } else { precondition(actual == nil, "expected rejection: \(header ?? "nil")") }
}
check(nil, 100, 0, 99)
check("bytes=0-0", 100, 0, 0)
check("bytes=13-", 100, 13, 99)
check("bytes=-10", 100, 90, 99)
check("bytes=-999", 100, 0, 99)
check("bytes=90-300", 100, 90, 99)
check("bytes=99-99", 100, 99, 99)
check("bytes=100-", 100, nil, nil)
check("bytes=12-11", 100, nil, nil)
check("bytes=1-2,3-4", 100, nil, nil)
check("bytes=1-xyz", 100, nil, nil)
check("bytes=18446744073709551616-", 100, nil, nil)
check("bytes=-0", 100, nil, nil)
check("BYTES=1-5", 100, nil, nil)
check(nil, 0, nil, nil)
print("PASS: 15 Swift Foundation range-parser cases")
