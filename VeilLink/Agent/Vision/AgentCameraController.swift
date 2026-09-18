import Foundation
import Combine

#if canImport(AVFoundation) && canImport(Vision) && canImport(UIKit)
@preconcurrency import AVFoundation
@preconcurrency import Vision
import UIKit

final class AgentCameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    @Published private(set) var latestContext: AgentVisualContext?
    @Published private(set) var isRunning = false
    @Published private(set) var statusText = "摄像头未启动"

    let session = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "studio.zeo.veillink.agent.camera", qos: .userInitiated)
    private let analysisQueue = DispatchQueue(label: "studio.zeo.veillink.agent.vision", qos: .utility)
    private struct Pacing {
        var enabled: Bool
        var sampleInterval: TimeInterval
        var classificationStride: Int
        var ocrStride: Int
    }

    private let pacingLock = NSLock()
    private var pacing: Pacing
    private let sessionPreset: AVCaptureSession.Preset
    private var lastSampleAt: TimeInterval = 0
    private var sampledFrames = 0
    private var configured = false
    private var cachedLabels: [String] = []
    private var cachedRecognizedText: [String] = []

    init(profile: AgentCapabilityProfile) {
        switch profile.tier {
        case .legacyA10:
            pacing = Pacing(enabled: true, sampleInterval: 1.6, classificationStride: 2, ocrStride: 4)
            sessionPreset = .vga640x480
        case .balanced:
            pacing = Pacing(enabled: true, sampleInterval: 0.85, classificationStride: 1, ocrStride: 2)
            sessionPreset = .medium
        case .high:
            pacing = Pacing(enabled: true, sampleInterval: 0.45, classificationStride: 1, ocrStride: 1)
            sessionPreset = .medium
        }
        super.init()
    }

    func applyComputeBudget(_ budget: AgentVisionComputeBudget) {
        pacingLock.lock()
        pacing = Pacing(
            enabled: budget.enabled,
            sampleInterval: max(0.20, Double(budget.sampleIntervalMilliseconds) / 1_000.0),
            classificationStride: max(1, budget.classificationStride),
            ocrStride: max(1, budget.ocrStride)
        )
        pacingLock.unlock()
    }

    private func currentPacing() -> Pacing {
        pacingLock.lock()
        let value = pacing
        pacingLock.unlock()
        return value
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async {
                    self.statusText = "没有摄像头权限"
                    self.isRunning = false
                }
                return
            }
            self.captureQueue.async { [weak self] in
                self?.configureAndStart()
            }
        }
    }

    func stop() {
        captureQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async {
                self.isRunning = false
                self.statusText = "摄像头已停止"
            }
        }
    }

    private func configureAndStart() {
        if !configured {
            session.beginConfiguration()
            session.sessionPreset = sessionPreset
            defer { session.commitConfiguration() }
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                DispatchQueue.main.async { self.statusText = "前置摄像头不可用" }
                return
            }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            output.setSampleBufferDelegate(self, queue: analysisQueue)
            guard session.canAddOutput(output) else {
                DispatchQueue.main.async { self.statusText = "视频输出不可用" }
                return
            }
            session.addOutput(output)
            if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            configured = true
        }
        if !session.isRunning { session.startRunning() }
        DispatchQueue.main.async {
            self.isRunning = true
            self.statusText = "纯本地视觉输入"
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentPacing = currentPacing()
        let now = CACurrentMediaTime()
        guard currentPacing.enabled,
              now - lastSampleAt >= currentPacing.sampleInterval,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastSampleAt = now
        sampledFrames += 1

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let faceRequest = VNDetectFaceRectanglesRequest()
        let shouldClassify = sampledFrames % currentPacing.classificationStride == 0
        let classifyRequest = shouldClassify ? VNClassifyImageRequest() : nil
        let shouldOCR = sampledFrames % currentPacing.ocrStride == 0
        let textRequest = shouldOCR ? VNRecognizeTextRequest() : nil
        textRequest?.recognitionLevel = .fast
        textRequest?.usesLanguageCorrection = false
        if #available(iOS 16.0, *) {
            textRequest?.automaticallyDetectsLanguage = true
        }

        var requests: [VNRequest] = [faceRequest]
        if let classifyRequest { requests.append(classifyRequest) }
        if let textRequest { requests.append(textRequest) }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        do {
            try handler.perform(requests)
            let faces = (faceRequest.results ?? []).count
            if let classifyRequest {
                cachedLabels = (classifyRequest.results ?? [])
                    .filter { $0.confidence >= 0.35 }
                    .prefix(6)
                    .map { $0.identifier }
            }
            if let textRequest {
                cachedRecognizedText = (textRequest.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .prefix(4)
                    .map(String.init)
            }
            let context = AgentVisualContext(
                capturedAt: Date(),
                faceCount: faces,
                labels: cachedLabels,
                recognizedText: cachedRecognizedText,
                frameWidth: width,
                frameHeight: height
            )
            DispatchQueue.main.async { [weak self] in
                self?.latestContext = context
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.statusText = "视觉分析受限"
            }
        }
    }
}

#else
final class AgentCameraController: ObservableObject {
    @Published private(set) var latestContext: AgentVisualContext?
    @Published private(set) var isRunning = false
    @Published private(set) var statusText = "当前平台没有摄像头运行时"
    init(profile: AgentCapabilityProfile) {}
    func applyComputeBudget(_ budget: AgentVisionComputeBudget) {}
    func start() {}
    func stop() {}
}
#endif
