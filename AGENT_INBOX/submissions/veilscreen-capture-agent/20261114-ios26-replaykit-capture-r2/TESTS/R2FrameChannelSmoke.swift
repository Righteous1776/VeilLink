import Foundation
@main struct R2FrameChannelSmoke {
    static func main() throws {
        let id = UUID()
        var sched = VeilScreenBLEScheduler()
        var receive = VeilScreenShareAssembler(sessionID: id)
        var completed: [VeilScreenShareFrame] = []
        for index in 1...100 {
            let bytes = Data(repeating: UInt8(index & 255), count: 3600 + index)
            precondition(sched.offer(image: bytes, sessionID: id,
                                     frameID: UInt64(index), width: 320,
                                     height: 640, now: TimeInterval(index)))
            while let next = sched.peek(pendingBLEBytes: 0, now: TimeInterval(index)) {
                let clear = try VeilScreenShareChunk.decode(next.encode())
                if let frame = try receive.receive(clear, at: TimeInterval(index)) {
                    completed.append(frame)
                }
                precondition(sched.didAdmit(next))
            }
        }
        precondition(completed.count == 100)
        precondition(completed.last?.frameID == 100)
        precondition(!sched.hasPendingVideo)
        // Admit old-frame packets only to a stale replay gate; no media rolled back.
        let old = try VeilScreenShareChunk.split(image: Data(repeating: 3, count: 100),
                           sessionID: id, frameID: 1, width: 320, height: 640)
        let replay = try receive.receive(old[0], at: 200)
        precondition(replay == nil)
        print("VeilScreen R2 100-frame scheduler/codec/reassembly smoke PASS")
    }
}
