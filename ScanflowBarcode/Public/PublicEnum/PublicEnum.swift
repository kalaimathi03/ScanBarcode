//
//  PublicEnum.swift
//  ScanflowBarcode
//
//  Created by Mac-OBS-46 on 14/09/22.
//

import Foundation
import AVFoundation
import ScanflowCore
public typealias CompletionHandler = (_ success: Result?) -> Void

/**
 This is public ZoomOptions containes type of zooms
 */
public enum ZoomOptions {
    case autoZoom
    case touchToZoom
    case normal
}


/**
 This string enum detection mode contains some cases
 */
public enum DetectionMode: String {
    
    case success = "Successful Detection & Decode"
    case failed = "Detection success & Decode Failed"
    case maximumZoom = "Detection success & Decode Failed & Zoom reached above eighty percent"
    case none = "No Detection"

}

extension Array {
  /// Creates a new array from the bytes of the given unsafe data.
  ///
  /// - Warning: The array's `Element` type must be trivial in that it can be copied bit for bit
  ///     with no indirection or reference-counting operations; otherwise, copying the raw bytes in
  ///     the `unsafeData`'s buffer to a new array returns an unsafe copy.
  /// - Note: Returns `nil` if `unsafeData.count` is not a multiple of
  ///     `MemoryLayout<Element>.stride`.
  /// - Parameter unsafeData: The data containing the bytes to turn into an array.
  init?(unsafeData: Data) {
    guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
    #if swift(>=5.0)
    self = unsafeData.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
    #else
    self = unsafeData.withUnsafeBytes {
      .init(UnsafeBufferPointer<Element>(
        start: $0,
        count: unsafeData.count / MemoryLayout<Element>.stride
      ))
    }
    #endif  // swift(>=5.0)
  }
}

