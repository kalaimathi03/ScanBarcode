//
//  PublicEnum.swift
//  ScanflowBarcode
//
//  Created by Mac-OBS-46 on 14/09/22.
//

import Foundation

import ScanflowCore


/**
 This is public struct stores one formatted inference.
 */
public struct Inference {
    public let confidence: Float
    public let className: String
    public let rect: CGRect
    public let boundingRect:CGRect
    public let displayColor: UIColor
    public let outputImage : UIImage
    public let previewWidth : CGFloat
    public let previewHeight : CGFloat
    public var originalImage: UIImage? = nil
    public var decodedResult: String?
    public var isSelected: Bool? = nil
}

/**
 This is public struct BoundingBox holds the x,y position and width and height
 */
struct BoundingBox {
    var xPosition: Float
    var yPosition: Float
    var width: Float
    var height: Float
}

/**
 This is public struct OutScore holds the confidence level in float
 */
public struct OutScore {
    var confidenceLevel: Float
}

/**
 This is public struct DetectedBox holds its count
 */
public struct DetectedBox {
    var count: Float
}

/**
 This is public struct DetectedBoxType represents the name in float
 */
public struct DetectedBoxType {
    var detectedBoxName: Float
}

/**
 Scan flow settings module handler
 Auto Zoom, Touch to Zoom and other settings will be managed
 */
public struct SFSettings {
         
    /**
     Zoom settings
     */
    public var zoomMode: ZoomOptions!
    
    public var zoomSettings: ZoomSettings! = ZoomSettings()
    
    
    
    public var isDetectionFoundAndDecodeFailed: Bool!
    
    public var noDetectionCount: Int!

    

    public var isDetectionFound: Bool!

    /**
     Auto Zoom details
     */
    public var isAutoZoomEnabled: Bool!
    
    
    /**
     Touch to Zoom details
     */
    public var isTouchToZoomEnabled: Bool!
    
    
    /**
     Auto flash light
     */
    public var enableAutoFlashLight: Bool!
    
    /**
     Auto exposure on/off
     */
    public var enableAutoExposure: Bool!
    
    init() {
        
        self.noDetectionCount = 5
        self.isDetectionFoundAndDecodeFailed = false
        self.isDetectionFound = false
        self.isTouchToZoomEnabled = false
        self.isAutoZoomEnabled = false
        self.zoomMode = .normal
        
        self.enableAutoFlashLight = false
        self.enableAutoExposure = false
        
    }
    
    
}

/**
 This struct holds zoom settings related to zoom settings parameters
 */
public struct ZoomSettings {
    
    public var detectionWithDecodeFailedCount: Int!
    public var currentZoomLevel: CGFloat!
    public var detectionState: DetectionMode
    
    init() {
         
        self.detectionWithDecodeFailedCount = 0
        self.currentZoomLevel = 1.2
        self.detectionState = .none
        
    }
    
}

/**
 This struct SFConfig holds configuartion information of image from scanflow core
 */
public struct SFConfig {
    
    public var resetCount:Int = 0
    
    /**
     Mask details
     */
    public var maskSize: CGSize = CGSize(width: 300, height: 300)
    public var cornerLength: CGFloat = 20
    public var lineWidth: CGFloat = 3
    public var lineColor: UIColor = .white
    public var lineCap: CAShapeLayerLineCap = .round
    
    /**
     Zoom factors
     */
    public var lastZoomFactor: CGFloat = 1.2
    public let minimumZoom: CGFloat = 1.2
    public let maximumZoom: CGFloat = 10.0
    public let defaultInitialZoomFactor: CGFloat = 1.2

    
    /**
     Frame and Edge offset
     */
    public let edgeOffset: CGFloat = 2.0
    public var frameCount: Int = 0
    
    init() {
        
        //self.lastZoomFactor = 1.2
        
    }
    
    
}

/**
 This struct SFResultHandler holds result information from scanflow coew
 */
public struct SFResultHandler {
    
    /**
     These variables are related to image results after enhancements
     */
    var successfulDetectionCount: Int!
    
    var barCodeType: BarCodeType!
    
    var originalImage: UIImage!
    var originalImageTime: String!
    
    var brightnessAppliedImage: UIImage?
    var brightnessAppliedTime: String!
    
    public var resized416Image: UIImage?
    public var resized416Time: String!
    
    
    
    var croppedQRImage: UIImage?
    var croppedQRTime: String!

    var croppedBARImage: UIImage?
    var croppedBARTime: String!
    
    
    
    var superResolutionImage: UIImage?
    var superResolutionTime: String!

    
    
    var upscaledQRImage: UIImage?
    var upscaledQRTime: String!
    
    var upscaledBARImage: UIImage?
    var upscaledBARTime: String!
    
    init() {
                
        self.successfulDetectionCount = 0
        self.barCodeType = .unknown
        
    }
    
}

/**
 This is public enum BarCodeType containes type of codes and types of it's properties
 */
public enum BarCodeType {
    
    case unknown
    
    case barCode
    case qrCode
    
    case qrLongDistanceGoodLight
    case qrShortDistanceGoodLight

    case qrShortDistanceLowLight
    case qrLongDistanceLowLight
    
}

/**
 This is public struct Result containes inference array object
 */
public struct Result {
    public var inferences: [Inference]
}

public enum BoundryUpdate {
    case updatePostion
    case removeView
    case newView
    case keepPosition
    case created
}

public struct CodeDetector {
    public let result: String
    public var borderRect: CGRect
    public var tag: Int
    public var noDetectionCount: Int
    public var boundryStatus: BoundryUpdate
    public var selected: Bool?

    public init(result: String, borderRect: CGRect, tag: Int, noDetectionCount: Int, updateBoundtry: BoundryUpdate, selected: Bool? = false) {
        self.result = result
        self.borderRect = borderRect
        self.tag = tag
        self.noDetectionCount = noDetectionCount
        self.boundryStatus = updateBoundtry
        self.selected = selected
    }

}
