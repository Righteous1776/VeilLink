import Foundation
/// Pure metadata contract; does not imply iOS 15 runtime acceptance.
public enum VeilopolyDeploymentPolicy {
 public static let minimumIOSMajorVersion = 15
 public static let requiresIOS16SceneGeometryUpdate = false
 public static let referenceBoardDesignSize = (width: 1024, height: 940)
}
