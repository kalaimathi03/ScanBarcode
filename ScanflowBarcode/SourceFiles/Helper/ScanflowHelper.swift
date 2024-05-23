//
//  ScanflowHelper.swift
//  ScanflowBarcode
//
//  Created by Mac-OBS-46 on 15/09/22.
//

import Foundation
import Vision
import UIKit
import ScanflowCore

/**
This is the public class  ScanflowHelper contains some scanflow settings,results,configurations
 */
public class ScanflowHelper {

    /**
    This is the variables used to scanflow settings,results,configuration and result array properties
     */
    static public let shared = ScanflowHelper()
    
    let sequenceHandler = VNSequenceRequestHandler()

    public var settings: SFSettings! = SFSettings()

    public var isDebugModeEnabled: Bool! = false
    
   public var results: SFResultHandler! = SFResultHandler()
    
    public var config: SFConfig! = SFConfig()
    
    public var resultArray: [SFResultHandler] = []
    

    init() {
        
    }
    
    /**
    This is the process of set initial zoom settings
     
     - Parameters:
        - zoomSettings: Have to configure zoom mode here - auto / touch /default
     
     */
    public func initalZoomSettings(_ zoomSettings: ZoomOptions) {
        
        self.settings.zoomMode = zoomSettings
        self.config.lastZoomFactor = 1.2
        
        self.settings.zoomSettings.currentZoomLevel = 1.2
        self.settings.zoomSettings.detectionWithDecodeFailedCount = 0
        self.settings.zoomSettings.detectionState = .none
        
    }
    
    /**
    This is the process of enabling debug mode
     
     - Parameters:
        - enable: have to input true or false
     
     */
   
    public func enbleDebugMode(enable: Bool) {
        self.isDebugModeEnabled = enable
    }
    
    
    /**
    This is the process of set auto zoom setup
     */
   
    public func initialAutoZoomSetup() {
        
        self.settings.isDetectionFound = false
        self.settings.isAutoZoomEnabled = true
        self.settings.noDetectionCount = 5
        self.settings.isTouchToZoomEnabled = false
    }
    
    /**
    This is the process of set touch zoom setup
     */
    public func initialTouchToZoomSetup() {
        
        self.settings.isAutoZoomEnabled = false
        self.settings.isTouchToZoomEnabled = false
        self.settings.isDetectionFound = false
        self.settings.noDetectionCount = 5
        
    }
    
    private func saveValidImages(_ image: UIImage?) {
        if let validImage = image {
            UIImageWriteToSavedPhotosAlbum(validImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
    
    @objc
    private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            print(message: error.localizedDescription, function: .longDistance)
        } else {
            print(message: "Your image has been saved to your photos. \(contextInfo.debugDescription)", function: .imageSaved)
        }
    }
    
    /**
    This is the fucntion of printing  messages
     - Parameters:
        - message: input message to be print
        - function: FUNTIONTYPE relevant to message
     */
    public func print(message: String, function: FUNTIONTYPE) {
         
        switch isDebugModeEnabled {
        case true:
            Swift.print("\(getCurrentMillis()): \(function.rawValue): \(message)")
            
        default:
            break
        }
        
    }
    
    /**
    This is the process of reset touch zoom
     */
    func resetTouchToZoom() {
        self.settings.isTouchToZoomEnabled = false
        self.settings.isDetectionFound = false
    }
    
    /**
    This is the function of getting current time stamp as string format
     */

    public func getCurrentMillis() -> String {
        
        let dateFormatter : DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MMM-dd HH:mm:ss.SSSS"
        let date = Date()
        let dateString = dateFormatter.string(from: date)
        return dateString
        
    }
    
    /**
    This is the function of return beep sound file name
     */
    func manageBeepSound() -> String? {
       return Bundle.main.path(forResource: "beep", ofType: "wav")
    }
    
    func cropImage(_ inputImage: UIImage, toRect cropRect: CGRect, viewWidth: CGFloat, viewHeight: CGFloat, apperance: OverlayViewApperance) -> UIImage?

        {

            let imageViewWidthScale = (inputImage.size.width / viewWidth)
            let imageViewHeightScale = inputImage.size.height / viewHeight



            // Scale cropRect to handle images larger than shown-on-screen size

            let cropZone = CGRect(x:cropRect.origin.x * (imageViewWidthScale).rounded(.up),

                                  y:cropRect.origin.y * imageViewHeightScale,

                                  width:cropRect.size.width * (imageViewWidthScale).rounded(.down),

                                  height:cropRect.size.height * imageViewHeightScale)



            // Perform cropping in Core Graphics

            if let cutImageRef: CGImage = inputImage.cgImage?.cropping(to:cropZone) {

                // Return image to UIImage

                let croppedImage: UIImage = UIImage(cgImage: cutImageRef)

                return croppedImage

            } else {

                guard let ciImage = inputImage.ciImage else {return nil}

                let context = CIContext(options: nil)

                guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {return nil}

                let croppedImage: UIImage = UIImage(cgImage: cgImage)

                return croppedImage

            }

       }

    
}
