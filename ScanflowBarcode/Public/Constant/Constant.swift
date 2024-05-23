//
//  Constant.swift
//  ScanflowBarcode
//
//  Created by Mac-OBS-46 on 15/09/22.
//

import Foundation


/**
 This is public enum named scanflow
 */
public enum Scanflow {
    
    /**
     This is public enum upscale qrcode and barcode correction
     */
    public enum UpScale {
        
        static let qrCodeEdgeCorrection = Int32(2)
        static let barCodeEdgeCorrection = Int32(1.5)

    }
    
    /**
     This string enum holds the code type
     */
    public enum CodeType {
        
        static let qrType = "QR Code"
        static let barType = "BAR Code"
        static let oneOfMany = "ONE OF MANY"
        static let batchInventry = "BATCH INVENTRY"
        static let pivotView = "PIVOT VIEW"

    }
    
    /**
     This is public enum Texts holds water mark information
     */
    public enum Texts {
        
        static let waterMark = "SCANFLOW"
        static let expireAlert = "The Scanflow SDK licence validation failed. \nYour licence key has expired!"
        
    }
    
    /**
     This is public enum Models holds info and name of tflight model
     */
    public enum Models {
        
        static let superResolutionModel = "Sensifai_SuperResolution_TFLite"
        static let superResolutionModelExtension = "tflite"
        
        static let modelConfidence:Float = 0.25
    }
    
    /**
     This is public enum Media holds info about sound files and path and id
     */
    public enum Media {
        
        static let alertSoundId = 1016
        static let alertBeepSoundPath = Bundle.main.path(forResource: "beep", ofType: "wav")!
        static let scannerModelPath = Bundle.main.path(forResource: "Efficientdet-lite2-1.0.5", ofType: "tflite")!

         
    }
    
    /**
     This is public enum DebugMode holds debug mode related information
     */
    public enum DebugMode {
        
        static let debugPermissionDenied = "Permission denied"
        static let debugEnableId = "DK0205198887544066622022"
        static let sampleBufferWithTestImages = false
         
    }
    
    /**
     This is public enum S3 holds info about bucket name and path url
     */
    public enum S3 {
        
        static let s3ReleaseClientName = "AppStore"
        
        static let s3BucketUrl = "http://54.235.130.26:8501/optiscan/uploadfile"
        
        static let s3FinalPathUrl = "\(s3ReleaseClientName)/iOS/PROD_"
        
    }
    
}
