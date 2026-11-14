import Foundation
@main struct VeilScreenR2CoreSmoke {
    static func main() {
        precondition(VeilScreenCaptureRoute.select(iOSMajor: 26) == .replayKitBroadcastExtension)
        precondition(VeilScreenCaptureRoute.select(iOSMajor: 27) == .screenCaptureKit)
        precondition(VeilScreenCaptureRoute.select(iOSMajor: 11) == .unsupported)
        var pacer = VeilScreenCapturePacer()
        precondition(pacer.shouldEncode(at: 100, minimumInterval: 2))
        precondition(!pacer.shouldEncode(at: 101, minimumInterval: 2))
        precondition(pacer.shouldEncode(at: 102, minimumInterval: 2))
        precondition(!pacer.shouldEncode(at: -1, minimumInterval: 2))
        precondition(!pacer.shouldEncode(at: 20, minimumInterval: .infinity))
        var gate = VeilScreenLatestFrameGate()
        precondition(gate.accept(frameID: 5, writtenAt: 100, now: 100))
        precondition(!gate.accept(frameID: 5, writtenAt: 101, now: 101))
        precondition(!gate.accept(frameID: 4, writtenAt: 101, now: 101))
        precondition(!gate.accept(frameID: 7, writtenAt: 90, now: 100))
        precondition(!gate.accept(frameID: 7, writtenAt: 108, now: 100))
        precondition(gate.accept(frameID: 7, writtenAt: 102, now: 102))
        gate.reset()
        precondition(gate.accept(frameID: 0, writtenAt: 1, now: 1))
        print("VeilScreen R2 core route/pacer/freshness smoke PASS")
    }
}
