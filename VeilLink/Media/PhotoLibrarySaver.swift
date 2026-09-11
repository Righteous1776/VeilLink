import Foundation
import Photos
import UniformTypeIdentifiers

enum PhotoLibrarySaveError: LocalizedError {
    case denied
    case unsupportedType
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .denied: return "没有添加到照片图库的权限。"
        case .unsupportedType: return "这种图片编码无法保存到系统照片。"
        case .saveFailed: return "图片没有成功保存到照片。"
        }
    }
}

enum PhotoLibrarySaver {
    static func save(data: Data, mimeType: String) async throws {
        guard let uti = uniformTypeIdentifier(for: mimeType) else { throw PhotoLibrarySaveError.unsupportedType }
        let status = await requestAddOnlyAuthorization()
        guard status == .authorized || status == .limited else { throw PhotoLibrarySaveError.denied }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = uti
                request.addResource(with: .photo, data: data, options: options)
            } completionHandler: { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume(returning: ()) }
                else { continuation.resume(throwing: PhotoLibrarySaveError.saveFailed) }
            }
        }
    }

    private static func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func uniformTypeIdentifier(for mimeType: String) -> String? {
        switch mimeType.lowercased() {
        case "image/jpeg": return UTType.jpeg.identifier
        case "image/heic": return UTType.heic.identifier
        case "image/png": return UTType.png.identifier
        default: return nil
        }
    }
}
