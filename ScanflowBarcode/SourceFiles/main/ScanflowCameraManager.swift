//
//  ScanflowCameraManager.swift
//  ScanflowBarcode
//
//  Created by Mac-OBS-46 on 13/09/22.
//

import Foundation
import UIKit
import ScanflowCore
import opencv2
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/**
This is the public class of scanflow camera manager
 */
@objc(ScanflowBarCodeManager)
public class ScanflowBarCodeManager: ScanflowCameraManager {
    
    private let threshold: Float = 0.25
    private let batchSize = 1
    private let inputChannels = 3
    private let inputWidth = 448.0
    private let inputHeight = 448.0
    
    /**
     image mean and std for floating model, should be consistent with parameters used in model training
     */
    private let imageMean: Float = 127.5
    private let imageStd:  Float = 127.5
    private var labels: [String] = []
    
    private var interpreter: Interpreter?
    var pathFile: String = ""
    
    private var originalBufferImage: UIImage?
    private var resizedBufferImage: UIImage?
    private var selectedResults: [String] = []
    private var batchedInternces:[String] = []
    private var threadCount = 1
    private var previousBoundRect: CGFloat = 0
    private var detectedResult: [CodeDetector] = []
    private var noDetectionThresHoldForRemovebounding: Int = 6
    private var previewViewCenter: CGPoint = .zero
    public var scanerTypeData: Int = 1
    /**
     Initializes a bar code manager function which configures all camera related function and Camera configurations..
     
     - Parameters:
        - previewView: A view which is used to show camera frames.
        - installedDate: We have to get app installed date
        - scannerType: Scanner type is like 'qrcode' 'barcode' and etc
        - overCropNeed: Which means it will get outimage as cropped image with respect to overlay frame
        - overlayApperance: This represents overlay apperance like 'rectangle' 'square' are 'hide'
     
     */
    @objc(init:::::::::)
    public override init(previewView: UIView, scannerMode: ScannerMode, overlayApperance: OverlayViewApperance, overCropNeed: Bool = false, leftTopArc: UIColor = .topLeftArrowColor, leftDownArc: UIColor = .bottomLeftArrowColor, rightTopArc: UIColor = .topRightArrowColor, rightDownArc: UIColor = .bottomRightArrowColor, locationNeed: Bool = false) {
        super.init(previewView: previewView, scannerMode: scannerMode, overlayApperance: overlayApperance, overCropNeed: overCropNeed, leftTopArc: leftTopArc, leftDownArc: leftDownArc, rightTopArc: rightTopArc, rightDownArc: rightDownArc, locationNeed: locationNeed)
        if ScanflowPermissionManger.shared.attemptToCameraConfigureSession() == .success {
            toBeSendInDelegate = false
            if scannerType != .oneOfMany && scannerType != .batchInventory {
              updateWaterMarkLabel()
            }
            setupFiles()
        } else {
            return
        }
        captureDelegate = self
        selectedDelegate = self
        if scannerType == .pivotView || scannerType == .barcode || scannerType == .qrcode || scannerType == .any {
            let bundle = Bundle(for: type(of: self))
            if let imageString = bundle.path(forResource: "pivot", ofType: "png"){
                
                let image =  UIImage(named: "pivot")
                let imageView = UIImageView(frame: CGRect(x: self.outterWhiteRectView.frame.origin.x,
                                                          y: ((self.outterWhiteRectView.frame.origin.y) + (self.outterWhiteRectView.frame.height / 2)),
                                                          width: self.outterWhiteRectView.frame.width,
                                                          height: 10))
                imageView.image = (UIImage(contentsOfFile: imageString)?.withRenderingMode(.alwaysTemplate))!
                
                previewView.addSubview(imageView)
                previewView.bringSubviewToFront(imageView)
                previewViewCenter = self.previewView.center
            }

        }
    }
    
    /**
     This is the function of detection classifier handler need to pass some inputs to detect the qr/barcode
     
     - Parameters:
        - imagePixelBuffer: pixel buffer that contains qr/barcode image
        - detectionDetail: Code info detail about input data
     */
    public func detectionClassiferHandler(_ imagePixelBuffer: CVPixelBuffer, _ detectionDetail: inout CodeInfo, previewSize: CGSize) {
            self.executeModel(onFrame: imagePixelBuffer, previewSize: previewSize) { result in
            
            guard let displayResult = result else {
                self.isFrameProcessing = false
                SFManager.shared.print(message: "FRAMES: No results", function: .processResults)
                return
            }
            
            if displayResult.inferences.count == 0 {
                SFManager.shared.settings.noDetectionCount += 1
                SFManager.shared.settings.zoomSettings.detectionState = .none
                let currentCoordinates = self.currentCoordinates
                switch self.scannerType {

                    case .qrcode:
                        self.delegate?.capturedOutput(result: "", codeType: self.scannerType, results: nil, processedImage: nil, location: currentCoordinates)
                        break
                    case .barcode:
                        self.delegate?.capturedOutput(result: "", codeType: self.scannerType, results: nil, processedImage: nil, location: currentCoordinates)
                        break
                    case .oneOfMany:
                        self.delegate?.capturedOutput(result: "", codeType: self.scannerType, results: self.selectedResults, processedImage: nil, location: currentCoordinates)
                        break
                    case .batchInventory:
                        self.delegate?.capturedOutput(result: "", codeType: self.scannerType, results: self.batchedInternces, processedImage: nil, location: currentCoordinates)
                        break
                    case .pivotView:
                        self.delegate?.capturedOutput(result: "", codeType: self.scannerType, results: nil, processedImage: nil, location: currentCoordinates)
                        break
                    default:
                        self.delegate?.capturedOutput(result: "", codeType: self.scannerType, results: nil, processedImage: nil, location: currentCoordinates)
                        break
                }
                // When we our QR frame get failure we have to proceed zoom

                if SFManager.shared.settings.isAutoZoomEnabled == true && SFManager.shared.settings.noDetectionCount == 5 {
                    SFManager.shared.settings.noDetectionCount = 0
                    self.enableZoom(.autoZoom)
                }

                self.drawAfterPerformingCalculations(onInferences: displayResult.inferences, withImageSize: CGSize.zero, isValidResult: false)
                return
            } else {
                SFManager.shared.print(message: "FRAMES: Inferences available", function: .processResults)
                SFManager.shared.settings.noDetectionCount = 0
                
            }
            
            if SFManager.shared.settings.isTouchToZoomEnabled == true {
                self.enableZoom(.touchToZoom)
            }                  
                print("=======switch self.scannerType=======")

                switch self.scannerType {
                case .oneOfMany, .batchInventory, .pivotView, .any:
                    print("=======neOfMany, .batchInventory, .pivotView, .an=======")

                    var tempInfernce:[Inference] = []

                    if displayResult.inferences.count != 0 {
                        let inferences = displayResult.inferences
                        if self.scannerType == .qrcode {
                            tempInfernce = displayResult.inferences.filter({$0.className == "QR"})
                            self.processResultForMultipleImages(inference: tempInfernce)
                        } else {
                            self.processResultForMultipleImages(inference: inferences)
                        }
                    }
                case .qrcode:
                    print("=======.qrcode=======")

                    var tempInfernce:[Inference] = []
                    
                    if displayResult.inferences.count != 0 {
                        tempInfernce = displayResult.inferences.filter({$0.className == "QR"})
                        self.processResultForMultipleImages(inference: tempInfernce)
                        
                    }
                case .barcode:
                    print("=======.barcode=======")

                    var tempInfernce:[Inference] = []
                    
                    if displayResult.inferences.count != 0 {
                        tempInfernce = displayResult.inferences.filter({$0.className != "QR"})
                        self.processResultForMultipleImages( inference: tempInfernce)
                        
                    }
                    

                    
                default:
                    print("=======.default=======")

                    var tempInfernce:[Inference] = []

                        switch self.scannerType {
                        case .qrcode:
                            tempInfernce = displayResult.inferences.filter({$0.className == "QR"})
                        case .barcode:
                            tempInfernce = displayResult.inferences.filter({$0.className == "BAR"})
                        default:
                            tempInfernce = displayResult.inferences
                    }
                    if tempInfernce.count != 0 {
                        for inference in tempInfernce {
                            self.processResult(cropImage: inference.outputImage,
                                          previewWidth: inference.previewWidth,
                                          previewHeight: inference.previewHeight,
                                          inference: inference,
                                          detectionDetail: &detectionDetail)
                        }
                    } else {
                        self.isFrameProcessing = false
                    }
            }
            

    }
    }
    
    /**
     this is function of processing image
     - Parameters:
        - cropImage: The input image that is going to be process
        - previewWidth: We have to pass image view width
        - previewHeight: We have to pass image view height
        - inference: Inference data
        - detectionDetail: Code info detail about input image
     */
    public func processResult(cropImage: UIImage,
                                previewWidth: CGFloat,
                                previewHeight: CGFloat,
                                inference: Inference,
                                detectionDetail: inout CodeInfo) {
print("processResult")
        if inference.className == "QR" {
            detectionDetail.codeType = .qr

            var resultImage = UIImage()
            if isQrLongDistance(image: cropImage,
                                previewWidth: previewWidth,
                                previewHeight: previewHeight) {

                //print("QR Long Distance")
                resultImage = cropImage.upscaleQRcode()

                ///Test results
                detectionDetail.distance = .long
                detectionDetail.upscaledQRImage = resultImage

                resultImage = SuperResolution.shared.convertImgToSRImg(inputImage: resultImage) ?? UIImage()

                ///Test results
                detectionDetail.srAppliedQRImage = resultImage

            } else {
                resultImage = cropImage
                detectionDetail.distance = .short
                detectionDetail.croppedQRImage = resultImage

            }


            let imgSize = __CGSizeEqualToSize(resultImage.size, .zero)

            if !imgSize {
                let points = NSMutableArray()
                let mat = Mat.init(uiImage: resultImage)
                let result = WeChatQRCode().detectAndDecode(img: mat, points: points)
                SFManager.shared.print(message: "WECHAT RESULT: \n \(result), \(result.count)", function: .processResults)

                if result.first != nil && result.first != "" {
                    SFManager.shared.playBeep(forCode: .normal)
                    self.delegate?.capturedOutput(result: result.first ?? "", codeType: scannerType, results: nil, processedImage: resultImage, location: currentCoordinates)
                    var tempData = inference
                    tempData.decodedResult = result.first
                    self.drawAfterPerformingCalculations(onInferences: [tempData], withImageSize: CGSize.zero, isValidResult: true)
                    ///Internal Purpose
                    SFManager.shared.print(message: "QR RESULT IN: \(SFManager.shared.getCurrentMillis())", function: .processResults)

                    if SFManager.shared.settings.isAutoZoomEnabled || SFManager.shared.settings.isTouchToZoomEnabled {
                        SFManager.shared.settings.isDetectionFound = true
                    }

                } else {
                    let rotatedImage = self.processImage(image: resultImage ?? UIImage())

                    decodeZxing(image: rotatedImage, inference: inference, detectionDetail: &detectionDetail)

                }

            } else {
                self.delegate?.captured(originalframe: resultImage.toPixelBuffer(), overlayFrame: .zero, croppedImage: resultImage)
                print("S3 Failed images upload")
                ///S3 Failed images upload
                detectionDetail.decodeFailedQRImage = resultImage
                SFManager.shared.uploadFailedImagesToS3(resultImage, detectionDetail)

                switch scannerType {

                case .qrcode:
                    self.delegate?.capturedOutput(result: "", codeType: scannerType, results: nil, processedImage: resultImage, location: currentCoordinates)
                case .barcode:
                    self.delegate?.capturedOutput(result: "", codeType: scannerType, results: nil, processedImage: resultImage, location: currentCoordinates)
                case .oneOfMany:
                    self.delegate?.capturedOutput(result: "", codeType: scannerType, results: nil, processedImage: resultImage, location: currentCoordinates)
                case .batchInventory:
                    self.delegate?.capturedOutput(result: "", codeType: scannerType, results: nil, processedImage: resultImage, location: currentCoordinates)
                case .pivotView:
                    self.delegate?.capturedOutput(result: "", codeType: scannerType, results: nil, processedImage: resultImage, location: currentCoordinates)
                default:
                    self.delegate?.capturedOutput(result: "", codeType: scannerType, results: nil, processedImage: resultImage, location: currentCoordinates)
                }

                self.drawAfterPerformingCalculations(onInferences: [inference],
                                                     withImageSize: resultImage.size,
                                                     isValidResult: false)

                ///Internal Purpose
                SFManager.shared.settings.zoomSettings.detectionState = .failed

            }

        } else {
            
            detectionDetail.codeType = .bar
            
            let resultImage:UIImage?
            
            if isBarcodeLongDistance(image: cropImage, previewWidth: previewWidth, previewHeight: previewHeight) {
                
                resultImage = cropImage.upscaleBarcode()
                
                detectionDetail.distance = .long
                detectionDetail.upscaledBARImage = resultImage
                
            } else {
                
                resultImage = cropImage
                
                detectionDetail.distance = .short
                detectionDetail.croppedBARImage = resultImage
                
            }
            
            if  let result =  detectCode39Barcodes(in: resultImage!) {
                var tempinfer = inference
                tempinfer.decodedResult = result
                self.drawAfterPerformingCalculations(onInferences: [tempinfer],
                                                     withImageSize: resultImage!.size,
                                                     isValidResult: result == "" ? false : true)
            } else {
                let rotatedImage = processImage(image: resultImage ?? UIImage())
                self.decodeZxing(image: rotatedImage, inference: inference, detectionDetail: &detectionDetail)
            }
            
        }
    }
    

    func calculateShadowLevel(of image: UIImage) -> Double? {
        guard let cgImage = image.cgImage else {
            print("Unable to get CGImage from UIImage")
            return nil
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // Allocate array for pixel data
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        // Create context to draw the image
        let context = CGContext(data: &pixelData,
                                width: width,
                                height: height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        
        guard let imageContext = context else {
            print("Unable to create CGContext")
            return nil
        }
        
        imageContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var totalLuminance: Double = 0.0
        let pixelCount = width * height
        
        // Iterate through pixel data to calculate total luminance
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let red = Double(pixelData[i])
            let green = Double(pixelData[i + 1])
            let blue = Double(pixelData[i + 2])
            
            // Calculate luminance (weighted average of RGB components)
            let luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255.0
            
            totalLuminance += luminance
        }
        
        // Calculate average luminance
        let averageLuminance = totalLuminance / Double(pixelCount)
        
        return averageLuminance
    }

    
    func detectCode39Barcodes(in image: UIImage)  -> String? {
        var result:String? = nil
        guard let ciImage = CIImage(image: image) else {
            fatalError("Unable to create CIImage from UIImage")
        }

        let barcodeRequest = VNDetectBarcodesRequest { request, error in
            guard let observations = request.results as? [VNBarcodeObservation] else {
                fatalError("Failed to obtain barcode observations")
            }

            for observation in observations {
                guard let payload = observation.payloadStringValue else { continue }
                print("Detected barcode: \(payload)")
                self.delegate?.capturedOutput(result: payload, codeType: self.scannerType, results: nil, processedImage: image, location: self.currentCoordinates)
                result = payload
                

            }
           
        }
       
        let barcodeRequestHandler = VNImageRequestHandler(ciImage: ciImage, orientation: .up)
        
        do {
            try barcodeRequestHandler.perform([barcodeRequest])
        } catch {
            
        }
    return result
    }

    func saveImageToDocumentsDirectory(image: UIImage, tag: String) {
        if let imageData = image.pngData() { // Convert image to PNG data
            let fileManager = FileManager.default
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let imagePath = documentsPath.appendingPathComponent("\(tag)\(Int.random(in: 0..<10000)).png") // File name for the saved image

            do {
                try imageData.write(to: imagePath)
                print("Image saved successfully at \(imagePath)")
            } catch {
                print("Error saving image: \(error)")
            }
        }
    }
    
    /**
     this is function of decode image and inference using zxing
     - Parameters:
        - image: The input image that is going to be process
        - inference: Inference data
        - detectionDetail: Code info detail about input image
     */
    func decodeZxing(image: UIImage, inference: Inference, detectionDetail: inout CodeInfo) {

        let source: ZXLuminanceSource = ZXCGImageLuminanceSource(cgImage: image.cgImage)
        let binazer = ZXHybridBinarizer(source: source)
        let bitmap = ZXBinaryBitmap(binarizer: binazer)
        let reader = ZXMultiFormatReader()

        if let result = try? reader.decode(bitmap) {

            let formate = result.barcodeFormat.rawValue
            let codeType = getValidBarCode(Int(formate))

            self.delegate?.capturedOutput(result: result.text ?? "", codeType: scannerType, results: nil, processedImage: image, location: currentCoordinates)
            if result.text != "" || result.text != nil {
                SFManager.shared.playBeep(forCode: .normal)
            }
            if inference.className == "QR" {
                SFManager.shared.print(message: "QR RESULT IN", function: .processResults)
            } else {
                SFManager.shared.print(message: "BAR RESULT IN", function: .processResults)
            }
            
            var tempinfer = inference
            tempinfer.decodedResult =  result.text
            self.drawAfterPerformingCalculations(onInferences: [tempinfer],
                                                 withImageSize: image.size,
                                                 isValidResult: true)

            ///Internal Purpose
            if SFManager.shared.settings.isAutoZoomEnabled || SFManager.shared.settings.isTouchToZoomEnabled {
                SFManager.shared.settings.isDetectionFound = true
            }
            SFManager.shared.settings.zoomSettings.detectionState = .success


        } else {
            ///Internal Purpose
            SFManager.shared.settings.zoomSettings.detectionState = .failed

            // When we our QR frame get failure we have to proceed zoom
            if SFManager.shared.settings.isAutoZoomEnabled == true {
                self.enableZoom(.autoZoom)
            }

            ///S3 Failed images upload
            if inference.className == "QR" {
                detectionDetail.decodeFailedQRImage = image
            } else {
                detectionDetail.decodeFailedBARImage = image
            }

            SFManager.shared.uploadFailedImagesToS3(image, detectionDetail)
            self.delegate?.capturedOutput(result: "", codeType: scannerType, results: nil, processedImage: image, location: currentCoordinates)
           
            self.drawAfterPerformingCalculations(onInferences: [inference],
                                                 withImageSize: image.size,
                                                 isValidResult: false)

        }

    }
    
 

    
    /**
     this is function of process and rotate image
     - Parameters:
        - image: The input image that is going to be process
     */
    func processImage(image: UIImage) -> UIImage {

        let inputImageMat = Mat.init(uiImage: image)
        let lines:Mat = initMatSetup(bitmap: image)
        let angleResult = detectRotationAngle(binaryImage: lines)
        let rotatedImage = rotateImage(imageMat: inputImageMat, angle: angleResult)
        return rotatedImage

    }
    
    /**
     this is function of rotate image
     - Parameters:
        - imageMat: Mat object of image
        - angle: rotation angle in double
        - Returns: Rotated UIImage
     */
    private func rotateImage(imageMat: Mat, angle: Double) -> UIImage {

        SFManager.shared.print(message: "ACTUAL DEGREE -->>> \(angle)", function: .rotateImage)

        var image = imageMat.toUIImage()

        if imageMat.size().height > imageMat.size().width {

            SFManager.shared.print(message: "ACTUAL DEGREE Size -->>> \(imageMat.size())", function: .rotateImage)
            let size = imageMat.size()
            let height = Double(size.height)

            DispatchQueue.main.async {

                let imageV = UIImageView(frame: CGRect(x: 0, y: 0, width: height, height: height))
                imageV.backgroundColor = .white
                imageV.image = image
                imageV.contentMode = .center
                image = UIImage(view: imageV)
            }

            SFManager.shared.print(message: "ACTUAL DEGREE Size after conversion -->>> \(image.size)", function: .rotateImage)

        } else {

            let size = imageMat.size()
            let width = Double(size.width)

            DispatchQueue.main.async {

                let imageV = UIImageView(frame: CGRect(x: 0, y: 0, width: width, height: width))
                imageV.backgroundColor = .white
                imageV.image = image
                imageV.contentMode = .center
                image = UIImage(view: imageV)

            }


            SFManager.shared.print(message: "ACTUAL DEGREE Size after conversion -->>> \(image.size)", function: .rotateImage)

        }


        let locImageMat = Mat.init(uiImage: image)

        //Get the rotation matrix

        let imgCenter = Point2f(x: Float(locImageMat.cols()) / 2, y: Float(locImageMat.rows()) / 2)

        SFManager.shared.print(message: "ROTATION PERFORM", function: .rotateImage)

        let rotMtx = Imgproc.getRotationMatrix2D(center: imgCenter, angle: angle, scale: 1.0)

        Imgproc.warpAffine(src: locImageMat, dst: locImageMat, M: rotMtx, dsize: Size2i(width:Int32(image.size.width) , height: Int32(image.size.height)))

        let img = locImageMat.toUIImage()

        return img


    }
    
    /**
     this is function of converting image to mat
     - Parameters:
        - bitmap: input image in uiimage
        - Returns: Mat object equvalant to the input
     */
    private func initMatSetup(bitmap: UIImage) -> Mat {


        let mat = Mat.init(uiImage: bitmap)
        var rgbMat = mat
        let grayMat = mat
        var destination:Mat = Mat(rows: rgbMat.rows(), cols: rgbMat.cols(), type: rgbMat.type())
        Imgproc.cvtColor(src: rgbMat, dst: grayMat, code: ColorConversionCodes.COLOR_BGR2GRAY)

        destination = grayMat
        let element = Imgproc.getStructuringElement(shape: MorphShapes.MORPH_RECT, ksize: Size2i(width: 5, height: 5))
        Imgproc.erode(src: grayMat, dst: destination, kernel: element)

        rgbMat = destination
        let element1 = Imgproc.getStructuringElement(shape: MorphShapes.MORPH_RECT, ksize: Size2i(width: 5, height: 5))
        Imgproc.dilate(src: rgbMat, dst: destination, kernel: element1)

        //Detecting the edges
        let edges = mat
        Imgproc.Canny(image: destination, edges: edges, threshold1: 50.0, threshold2: 200.0)
        //Detecting the hough lines from (canny)
        let lines = mat
        Imgproc.HoughLinesP(image: edges, lines: lines, rho: 0.8, theta: .pi / 360, threshold: 50, minLineLength: 50.0, maxLineGap: 10.0)
        return lines

    }
    
    /**
     this is function of detect rotation angle from mat
     - Parameters:
        - binaryImage: need to pass an input Mat object
        - Returns: rotation angle in double
     */
    private func detectRotationAngle(binaryImage: Mat) -> Double {
        
        var angle:Double = 0.0
        let debugImage:Mat = binaryImage.clone()
        for col in 0..<binaryImage.cols(){
            var vec = [Double]()
            vec = binaryImage.get(row: 0, col: col)
            let x1:Double = vec[0]
            let y1:Double = vec[1]
            let x2:Double = vec[2]
            let y2:Double = vec[3]
            let start :Point2i = Point2i(x: Int32(x1), y: Int32(y1))
            let end : Point2i = Point2i(x: Int32(x2), y: Int32(y2))
            
            //Draw line on the "debug" image for visualization
            Imgproc.line(img: debugImage, pt1: start, pt2: end, color: Scalar(255.0, 255.0, 0), thickness: 5)
            
            //Calculate the angle we need
            angle = calculateAngleFromPoints(start: start, end: end);
        }
        return angle;
    }

    /**
     this is function of calculation of angle from start and end points
     - Parameters:
        - start: need to pass an starting point in Point2i format
        - end: need to pass an ending point in Point2i format
     */

    private func calculateAngleFromPoints(start: Point2i, end: Point2i) -> Double {

        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let atan:Double = atan2(Double(deltaY), Double(deltaX))
        let val = atan * (180 / .pi)
        return val

    }
    
    //    //MARK: - Draw Bounding Box
    
    internal func processResultForMultipleImages(inference: [Inference]) {
        decodeZxingMultiple(inference: inference)
    }

    /**
     this is function of decoding multiple codes
     - Parameters:
        - inference: need to pass an Array of inference objects
     */
    func decodeZxingMultiple(inference: [Inference]) {
        var sortedInternces:[Inference] = []
        for var infer in inference {
            let resultImage = infer.outputImage
            let resultBuffer = resultImage.toPixelBuffer()
            let barcodeDetails = SFManager.shared.extractQRCode(fromFrame: resultBuffer)
            if let barcodeResult = barcodeDetails.0, let barcodeType = barcodeDetails.1 {

                let image = resultImage ?? UIImage()
                let removeCodeTypePrefix = barcodeType.replacingOccurrences(of: "VNBarcodeSymbology", with: "")

//                infer.decodedResult = "\(barcodeResult) - \(removeCodeTypePrefix.replacingOccurrences(of: " ", with: ""))"
                infer.decodedResult = barcodeResult

            } else {


                let source: ZXLuminanceSource = ZXCGImageLuminanceSource(cgImage: infer.outputImage.cgImage)
                let binazer = ZXHybridBinarizer(source: source)
                let bitmap = ZXBinaryBitmap(binarizer: binazer)
                let reader = ZXMultiFormatReader()


                if let result = try? reader.decode(bitmap) {
                    let formate = result.barcodeFormat.rawValue
                    let codeType = getValidBarCode(Int(formate))

//                    infer.decodedResult = ("\(result.text ?? "" ) - \(codeType.replacingOccurrences(of: " ", with: ""))")
                    infer.decodedResult = result.text ?? ""
                }
            }
            let mainFrame = infer.boundingRect

            if let result = infer.decodedResult {

                switch scannerType {
                    case .oneOfMany:
                        if let touchedPostion = touchedPosition, mainFrame.contains(touchedPostion) == true {

                            if selectedResults.contains(result), let postion = selectedResults.firstIndex(of: result) {
                                infer.isSelected = false
                                selectedResults.remove(at: postion)
                            } else {
                                selectedResults.append(result)
                                infer.isSelected = true
                                SFManager.shared.playBeep(forCode: .oneOfMany)
                            }
                            self.touchedPosition = nil
                        }
                        if selectedResults.contains(infer.decodedResult ?? "") {
                            infer.isSelected = true
                        }
                        if inference.count == 1 {
                            infer.isSelected = true
                        }
                        sortedInternces.append(infer)
                case .pivotView, .qrcode, .any, .barcode:

                    if mainFrame.contains(self.previewViewCenter) == true {
                                SFManager.shared.playBeep(forCode: .normal)
                                sortedInternces.append(infer)
                                
                            
                        }

//                    case .qrcode:
//                        sortedInternces = [infer]
                    
                    default: //BatchInventry
                        if let result = infer.decodedResult {
                            if !batchedInternces.contains(result) {
                                batchedInternces.append(result)
                                SFManager.shared.playBeep(forCode: .normal)
                            }
                            sortedInternces.append(infer)
                        }


                }
                

            }
        }
        print("previewView scannerType \(sortedInternces)")
        switch scannerType {
            case .oneOfMany:
                if sortedInternces.count == 1 {
//                    if !selectedResults.contains(sortedInternces.first?.decodedResult ?? "") {
//                        selectedResults.append(sortedInternces.first?.decodedResult ?? "")
//                    }
                    self.delegate?.capturedOutput(result: sortedInternces.first?.decodedResult ?? "",
                                                  codeType: (sortedInternces.first?.className == "QR" ? .qrcode : .barcode),
                                                  results: selectedResults, processedImage: nil, location: currentCoordinates)
                } else if selectedResults.count == 0 || selectedResults.isEmpty == true {
                    self.delegate?.capturedOutput(result: "", codeType: scannerType, results: selectedResults, processedImage: nil, location: currentCoordinates)
                } else if selectedResults.count != 0 || selectedResults.isEmpty == false {
                    self.delegate?.capturedOutput(result: selectedResults.description, codeType: scannerType, results: selectedResults, processedImage: nil, location: currentCoordinates)
                }
            case .pivotView, .any:

                self.delegate?.capturedOutput(result: sortedInternces.first?.decodedResult ?? "", codeType: scannerType, results: nil, processedImage: nil, location: currentCoordinates)

            case .qrcode:
            self.delegate?.capturedOutput(result: sortedInternces.first?.decodedResult ?? "", codeType: .qrcode, results: nil, processedImage: nil, location: currentCoordinates)
            
        case .barcode:
        self.delegate?.capturedOutput(result: sortedInternces.first?.decodedResult ?? "", codeType: .barcode, results: nil, processedImage: nil, location: currentCoordinates)

            default:
                self.delegate?.capturedOutput(result: "", codeType: scannerType, results: batchedInternces, processedImage: nil, location: currentCoordinates)


        }

        drawAfterPerformingCalculations(onInferences: sortedInternces, withImageSize: CGSize.zero, isValidResult: true)

    }

    public func clearBatchresult() {
        batchedInternces.removeAll()
    }

    private func isSingleScan() -> Bool {
        return scannerType == .qrcode || scannerType == .barcode || scannerType == .any || scannerType == .pivotView
    }
    /**
     this is function of draw overlay using inference value array
     - Parameters:
        - inferences: The input inference array
        - withImageSize: We have to pass image size Width * height
        - isValidResult: need to pass true or false
     */
    public func drawAfterPerformingCalculations(onInferences inferences: [Inference],
                                                withImageSize imageSize: CGSize,
                                                isValidResult: Bool) {

        DispatchQueue.main.async {
            for inference in inferences {
                // adding new rect resilt code
                if inference.decodedResult != nil {

                    guard let result = inference.decodedResult  else {return}
                    if !self.detectedResult.contains(where: {$0.result == result}) {
                      
                        self.detectedResult.append(CodeDetector(result: inference.decodedResult ?? "", borderRect: inference.boundingRect, tag: self.isSingleScan() ? 1 :(self.detectedResult.last?.tag ?? 0) + 1, noDetectionCount: 0, updateBoundtry: .newView))
                        if self.scannerType == .any || self.scannerType == .barcode || self.scannerType == .qrcode || self.scannerType == .pivotView {
                            break
                        }
                    }
                }
            }

            if self.isSingleScan() {
                if let tempResult = self.detectedResult.last {
                    var result = tempResult
                    self.detectedResult.removeAll()
                    if let existedView = self.previewView.subviews.filter({ $0.tag == 1 }).last {
                        result.boundryStatus = .updatePostion
                    }
                    self.detectedResult = [result]
                }
            }

            let viewsToBeCreated = self.detectedResult.filter({ $0.boundryStatus == .newView })

            var tempCount  = 0
            for viewUpdate in viewsToBeCreated {

                var tempView = UIView(frame: viewUpdate.borderRect)
                tempView.tag = viewUpdate.tag
                var viewColor: UIColor = .optiScanMultiBoundingBoxSelectedColor.withAlphaComponent(0.3)
                if self.scannerType == .oneOfMany {
                    if self.selectedResults.contains(where: { $0 == viewUpdate.result}) {
                        viewColor = .optiScanMultiBoundingBoxSelectedColor.withAlphaComponent(0.3)
                    } else {
                        viewColor = .optiScanMultiBoundingBoxBackcolor
                    }
                }

                tempView.backgroundColor = viewColor
                self.previewView.addSubview(tempView)
                let _ = self.detectedResult.enumerated().filter({$0.element.result == viewUpdate.result}).map({self.detectedResult[$0.offset].boundryStatus = .created})
                tempCount = tempCount + 1
            }

            // checking wether existing codes detected in current frame
            var tempCountData = 0
            for res in self.detectedResult {
                if inferences.contains(where: {$0.decodedResult == res.result}) {
                    // check xposition and update
                    let inferResult = inferences.filter({ $0.decodedResult == res.result}).first
                    if (inferResult?.boundingRect.minX)! >= (res.borderRect.minX  + 10) || (inferResult?.boundingRect.minX)! <= (res.borderRect.minX - 10) {
                        self.detectedResult[tempCountData].borderRect = inferResult?.boundingRect ?? .zero
                        self.detectedResult[tempCountData].boundryStatus = .updatePostion
                        self.detectedResult[tempCountData].noDetectionCount = 0

                    }
                } else {
                    // updateing no detection Count
                    self.detectedResult[tempCountData].noDetectionCount += 1
                    self.detectedResult[tempCountData].boundryStatus = .keepPosition
                }

                tempCountData += 1
            }

            // view updated postion based on threshold
            let viewsToBeUpdated = self.detectedResult.filter({ $0.boundryStatus == .updatePostion })

            var countdata = 0
            for viewUpdate in viewsToBeUpdated {
                if let boundView = self.previewView.subviews.filter( {$0.tag == viewUpdate.tag} ).first {
                    UIView.animate(withDuration: 0.7) {
                        boundView.frame = viewUpdate.borderRect
                        self.detectedResult[countdata].boundryStatus = .keepPosition
                    }
                }
                countdata += 1

            }

            //clear View which has not detected for 10 times
            let viewsToBeCleadred = self.detectedResult.filter({ $0.noDetectionCount > 10 })
            var tempCou = 0
            for viewUpdate in viewsToBeCleadred {
                let boundView = self.previewView.subviews.filter( {$0.tag == viewUpdate.tag} )
                //self.detectedResult[tempCou].boundryStatus = .removeView
                self.detectedResult.removeAll(where: {$0.tag == viewUpdate.tag})
                for removeView in boundView {
                    removeView.removeFromSuperview()
                }
                tempCou += 1
            }
            self.isFrameProcessing = false

        }


    }

    public func setupFiles() {
        setupModelFiles()
        threadCount = 1

        // Specify the options for the `Interpreter`.
        var options = Interpreter.Options()
        options.threadCount = threadCount
        do {
            // Create the `Interpreter`.
            interpreter = try Interpreter(modelPath: pathFile, options: options)
            // Allocate memory for the model's input `Tensor`s.
            try interpreter?.allocateTensors()
        } catch let error {
            SFManager.shared.print(message: "Failed to create the interpreter with error: \(error.localizedDescription)", function: .initializeModel)
            return
        }

    }
    
    
    private func setupModelFiles()  {
        var fullData = Data()
        for modelId in 1...12 {
            let bundle = Bundle(for: type(of: self))
            guard let litePath = bundle.path(forResource: "barcodeModel\(modelId)", ofType: "tflite") else {
                return
            }
            if let splitedData = try? Data(contentsOf: URL(fileURLWithPath: litePath)) {
                if modelId != 12 {
                    fullData.append(splitedData)
                } else {
                    if let lastData = decryptFile(key: "d5a423f64b607ea7c65b311d855dc48f36114b227bd0c7a3d403f6158a9e4412", nonce: "131348c0987c7eece60fc0bc", data: splitedData) {
                        fullData.append(lastData)
                    }
                }
            }
            
        }
        createPath(fileName: "DetectionModel", splitedData: fullData)
    }
    
    private func createPath(fileName: String, splitedData: Data) {
        let documentDirectoryUrl = try! FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        
        let fileUrl = documentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("tflite")
        do {
            try splitedData.write(to: fileUrl)
            pathFile = fileUrl.absoluteString.split(separator: ":").last!.description
        } catch let error as NSError {
            print (error)
        }
    }

    /**
     This is the public function of execute tflight model
     - Parameters:
        - pixelBuffer: need to give input pixel buffer
        - previewSize: size of an image
        - completionHandler: On completion it gives Result object
     */
    public func executeModel(onFrame pixelBuffer: CVPixelBuffer,  previewSize: CGSize, completionHandler: CompletionHandler) {
        originalBufferImage = pixelBuffer.toImage()
        //UIImageWriteToSavedPhotosAlbum(originalBufferImage!, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)

        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(sourcePixelFormat == kCVPixelFormatType_32ARGB ||
               sourcePixelFormat == kCVPixelFormatType_32BGRA ||
               sourcePixelFormat == kCVPixelFormatType_32RGBA)
        
        SFManager.shared.print(message: "Start Runmodel", function: .runModel)
        
        let imageChannels = 4

        assert(imageChannels >= inputChannels)
        
        resizedBufferImage = originalBufferImage
        
        // Crops the image to the biggest square in the center and scales it down to model dimensions.
        
        SFManager.shared.print(message: "BEFORE RESIZE", function: .runModel)
        
        let scaledSize = CGSize(width: inputWidth, height: inputHeight)
        
        guard let scaledPixelBuffer = pixelBuffer.resized(to: scaledSize) else {
            return
        }
        
        ///Test results
        SFManager.shared.results.resized416Image = scaledPixelBuffer.toImage()
        SFManager.shared.results.resized416Time = getCurrentMillis()
        
        SFManager.shared.print(message: "AFTER RESIZE", function: .runModel)
        
        let detectedBoxPosition: Tensor
        let confidenceLevelOfDetectedBox: Tensor
        let numberOfBoxDetected: Tensor
        let detectedBoundaryType: Tensor
        do {
            SFManager.shared.print(message: "MODEL STARTED", function: .runModel)

            let inputTensor = try interpreter?.input(at: 0)
            
            SFManager.shared.print(message: "BEFORE RGB RESIZE", function: .runModel)
            
            // Remove the alpha component from the image buffer to get the RGB data.
            guard let rgbData = rgbDataFromBuffer(
                scaledPixelBuffer,
                byteCount: batchSize * Int(inputWidth) * Int(inputHeight) * inputChannels,
                isModelQuantized: inputTensor?.dataType == .uInt8,
                imageMean: imageMean,
                imageStd: imageStd
            ) else {
                SFManager.shared.print(message: "Failed to convert the image buffer to RGB data.", function: .runModel)
                return
            }
            
            SFManager.shared.print(message: "AFTER RGB SIZE", function: .runModel)
            // Copy the RGB data to the input `Tensor`.
            try interpreter?.copy(rgbData, toInputAt: 0)
            
            // Run inference by invoking the `Interpreter`.
            try interpreter?.invoke()
            detectedBoxPosition = try interpreter?.output(at: 1) as! Tensor // POSTION OF DETECTEDBOX
            confidenceLevelOfDetectedBox = try interpreter?.output(at: 0) as! Tensor // CONFIDANCELEVEL OF DETECTED BOUNDING
            numberOfBoxDetected = try interpreter?.output(at: 2) as! Tensor // TOTAL NUMBER OF BOUDINGBOX DETECTED
            detectedBoundaryType = try interpreter?.output(at: 3) as! Tensor // BARCODE OR QR CODE
            
            
            SFManager.shared.print(message: "After response", function: .runModel)

        } catch let error {
            SFManager.shared.print(message: "Failed to invoke the interpreter with error: \(error.localizedDescription)", function: .runModel)
            return
        }
        
        let outputcount: Int = detectedBoxPosition.shape.dimensions[1]
        let boundingPositions = [BoundingBox](unsafeData: detectedBoxPosition.data)!
        let confidenceLevel = [OutScore](unsafeData: confidenceLevelOfDetectedBox.data)!
        let detectedCount = [DetectedBox](unsafeData: numberOfBoxDetected.data)!
        let cateforyOfDetectedBox = [DetectedBoxType](unsafeData: detectedBoundaryType.data)!

        let resultArray = formatResultsNew(boundingBox: boundingPositions,
                                           outputClasses: confidenceLevel,
                                           categoryType: cateforyOfDetectedBox,
                                           outputCount: outputcount,
                                           width: CGFloat(imageWidth),
                                           height: CGFloat(imageHeight),
                                           previewSize: previewSize)
        let result = Result(inferences: resultArray)
        completionHandler(result)
        
    }
    
    /**
     This is the function of formatting results of bounding box
     - Parameters:
        - boundingBox: An array of bounding boxes
        - outputClasses: An array of OutScore Objects
        - categoryType: An array of detection code type objects
        - outputCount: a count of outputs
        - previewSize: preview size
        - width: preview width
        - height: preview height
        - Returns: returns array of inference
     */
    func formatResultsNew(boundingBox: [BoundingBox], outputClasses: [OutScore],categoryType: [DetectedBoxType],
                       outputCount: Int, width: CGFloat,
                       height: CGFloat, previewSize: CGSize) -> [Inference] {
        
        SFManager.shared.print(message: "PREVIEW SIZE: \(previewSize)", function: .formatResults)
        var resultsArray: [Inference] = []
        if (outputCount == 0) {
            return resultsArray
        }

        SFManager.shared.print(message: "BEFORE OUTPUT ARRAY", function: .formatResults)
        
        /// getting bounding box dimentions
        let boudingBoxAboveThresHold = outputClasses.enumerated().filter({$0.element.confidenceLevel > threshold }).map({ boundingBox[$0.offset]})

        if (boudingBoxAboveThresHold.count == 0) {
            return resultsArray
        }

        /// getting bounding box type(Qr or Bar code) above thresholdValue
        let boudingBoxTypeAboveThresHold = outputClasses.enumerated().filter({$0.element.confidenceLevel > threshold }).map({ categoryType[$0.offset]})
        
        let _ = boudingBoxTypeAboveThresHold.enumerated().map { detectedBoundingBox in
            switch detectedBoundingBox.element.detectedBoxName {
            case 0: //QR Code
               
                let boundingBox = boudingBoxAboveThresHold[detectedBoundingBox.offset]
                let croppeedFrame =  CGRect(x: (CGFloat(boundingBox.yPosition) * originalBufferImage!.size.width),
                                            y: (CGFloat(boundingBox.xPosition) * originalBufferImage!.size.height),
                                            width: (CGFloat(boundingBox.height) * originalBufferImage!.size.width) - (CGFloat(boundingBox.yPosition) * originalBufferImage!.size.width),
                                            height: ((CGFloat(boundingBox.width) * originalBufferImage!.size.height) - (CGFloat(boundingBox.xPosition) * originalBufferImage!.size.height)))
                let boundingFrame =  CGRect(x: (CGFloat(boundingBox.yPosition) * previewSize.width),
                                            y: (CGFloat(boundingBox.xPosition) * previewSize.height),
                                            width: (CGFloat(boundingBox.height) * previewSize.width) - (CGFloat(boundingBox.yPosition) * previewSize.width),
                                            height: (((CGFloat(boundingBox.width) * previewSize.height) - (CGFloat(boundingBox.xPosition) * previewSize.height)) * (ratioCalculation(viewSize: previewSize) == true ? 2 : 1)))
                let croppedBar = self.originalBufferImage?.cropImage(frame: croppeedFrame) ?? UIImage()
                
                let inference = Inference(confidence: threshold,
                                          className: "QR",
                                          rect: croppeedFrame, boundingRect: boundingFrame,
                                          displayColor: UIColor.red, outputImage: croppedBar,previewWidth: width,previewHeight: height)
                resultsArray.append(inference)
                
                break
            case 1: //BAR code
                let boundingBox = boudingBoxAboveThresHold[detectedBoundingBox.offset]
                let croppeedFrame =  CGRect(x: (CGFloat(boundingBox.yPosition) * originalBufferImage!.size.width),
                                            y: (CGFloat(boundingBox.xPosition) * originalBufferImage!.size.height),
                                            width: ((CGFloat(boundingBox.height) * originalBufferImage!.size.width) + 30) - (CGFloat(boundingBox.yPosition) * originalBufferImage!.size.width),
                                            height: ((CGFloat(boundingBox.width) * originalBufferImage!.size.height) - (CGFloat(boundingBox.xPosition) * originalBufferImage!.size.height)))
                let croppedBar = self.resizedBufferImage?.cropImage(frame: croppeedFrame) ?? UIImage()
                let boundingFrame =  CGRect(x: (CGFloat(boundingBox.yPosition) * previewSize.width),
                                            y: (CGFloat(boundingBox.xPosition) * previewSize.height),
                                            width: ((CGFloat(boundingBox.height) * previewSize.width)) - (CGFloat(boundingBox.yPosition) * previewSize.width),
                                            height: (((CGFloat(boundingBox.width) * previewSize.height) - (CGFloat(boundingBox.xPosition) * previewSize.height)) * (ratioCalculation(viewSize: previewSize) == true ? 2 : 1)))
                
                let inference = Inference(confidence: Float(threshold),
                                          className: "BAR",
                                          rect: croppeedFrame, boundingRect: boundingFrame,
                                          displayColor: UIColor.green, outputImage: croppedBar,previewWidth: width,previewHeight: height)
               
                resultsArray.append(inference)
                break
            default:
                break
            }
            
        }
        SFManager.shared.print(message: "Progress completed: \(previewSize)", function: .formatResults)
        return resultsArray
        
    }

    func ratioCalculation(viewSize: CGSize) -> Bool {
        let aspectRatio = viewSize.width / viewSize.height

        return aspectRatio > 0.9
    }

}


extension ScanflowBarCodeManager : CaptureDelegate {
    
    public func readData(originalframe: CVPixelBuffer, croppedFrame: CVPixelBuffer) {

        var detectionDetails = CodeInfo()
        self.detectionClassiferHandler(originalframe, &detectionDetails, previewSize: previewSize!)
    }
    
}

extension ScanflowBarCodeManager: UpdateSeclectedResultDelegate {

    public func updateTouchBasedResult() {
     
     
            if let touchedResult = detectedResult.filter( {$0.borderRect.contains(touchedPosition!)} ).first {
                if touchedResult.selected != true {
                    let _ = self.detectedResult.enumerated().filter({$0.element.result == touchedResult.result}).map({
                        self.detectedResult[$0.offset].selected = true
                    })
     
                    if let touchedView = previewView.subviews.filter({$0.tag == touchedResult.tag}).first {
                        touchedView.backgroundColor = .optiScanMultiBoundingBoxSelectedColor.withAlphaComponent(0.3)
                    }
                    SFManager.shared.playBeep(forCode: .normal)
                    print("SFManager.shared.playBeep(forCode: .normal)");
     
                } else {
                    let _ = self.detectedResult.enumerated().filter({$0.element.result == touchedResult.result}).map({
                        self.detectedResult[$0.offset].selected = false
                    })
                    if let touchedView = previewView.subviews.filter({$0.tag == touchedResult.tag}).first {
                        touchedView.backgroundColor = .optiScanMultiBoundingBoxBackcolor
                    }
                }
            }
     
     
        }

}
