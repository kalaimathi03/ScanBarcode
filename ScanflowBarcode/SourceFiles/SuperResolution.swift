//
//  SuperResolution.swift
//  ScanflowBarcodeReader
//
//
import ScanflowCore

/// Information about a model file or labels file.
typealias SRFileInfo = (name: String, model_extension: String)


/// Information about the detection model.
enum SRInfo {
    static let modelInfo: SRFileInfo = (name: Scanflow.Models.superResolutionModel,
                                        model_extension: Scanflow.Models.superResolutionModelExtension)
}

import UIKit
import CoreImage
import Accelerate
import opencv2
import TensorFlowLiteC
import CoreML

class SuperResolution: NSObject {
    
    
    private var interpreter: Interpreter?
    private var results:[Float] = []
    private let inputWidth = 512
    private let inputHeight = 512
    
    static let shared = SuperResolution()
    
    func convertImgToSRImg(inputImage: UIImage) -> UIImage? {
        SFManager.shared.print(message: "SR Started", function: .superResolutionStart)
        
        var srcImgWidth:CGFloat?// = 0.0
        var srcImgHeight:CGFloat?// = 0.0
        
        let bundle = Bundle(for: type(of: self))
        guard let modelPath = bundle.path(forResource: SRInfo.modelInfo.name, ofType: SRInfo.modelInfo.model_extension) else {
            print("Failed to load the model file with name: \(SRInfo.modelInfo.name).")
            return nil
        }
        
        let outputTensor: Tensor?
        
        do {
            
            SFManager.shared.print(message: "Model Interpreter started", function: .superResolutionStart)
            interpreter = try Interpreter(modelPath: modelPath)
            
            /// Enable dynamic test image
            ///
            let imageOld = inputImage
            
            /// Enable local test image
                        
            srcImgWidth = imageOld.size.width
            srcImgHeight = imageOld.size.height
            
            let src = Mat(uiImage: imageOld)
            
            let dst = Mat()
            //
            SFManager.shared.print(message: "Before image resize to 512", function: .superResolutionStart)

            Imgproc.resize(src: src, dst: dst, dsize: Size2i(width: 512, height: 512))

            SFManager.shared.print(message: "After image resize to 512", function: .superResolutionStart)
            
            let _ = dst.toUIImage()
            
            
            let image: CGImage = dst.toCGImage()// Your input image
            guard let context = CGContext(
                data: nil,
                width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            ) else {
                return nil
            }
            
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            
            guard let imageData = context.data else { return nil }

            SFManager.shared.print(message: "Before image data for loop", function: .superResolutionStart)
            let details = OpenCVWrapper().processedData(context.width, imageData: imageData)
            guard let inputData = details as? Data else {
                return nil
            }
            
            SFManager.shared.print(message: "After image data for loop", function: .superResolutionStart)


            try interpreter?.allocateTensors()
            
            do {
                try interpreter?.copy(inputData, toInputAt: 0)
                
            } catch let error {
                print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
            }
            
            try interpreter?.invoke()
            
            // Get the output `Tensor` to process the inference results.
            outputTensor = try interpreter?.output(at: 0)
            
            SFManager.shared.print(message: "Interpreter response", function: .superResolutionStart)
            
        } catch let error {
            print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
            return nil
        }
        
        //        output = [Float32](unsafeData: outputTensor?.data ?? Data()) ?? []
        //        let formattedArray = outputTensor?.shape.dimensions ?? []
        let output: [Float32]
        
        output = [Float32](unsafeData: outputTensor?.data ?? Data()) ?? []
        //        let formattedArray = outputTensor?.shape.dimensions ?? []
        
        //let _ = [SuperResolutionModel](unsafeData: outputTensor!.data)!
        
        let imageWidth = 512
        let imageHeight = 512
        let imageSize = imageWidth * imageHeight
        
        
        guard let minValue = output.min() else { return nil}
        guard let maxValue = output.max() else { return nil}
        
        SFManager.shared.print(message: "min_value \(minValue) max_vale \(maxValue)", function: .superResolutionStart)
        
        //TODO: Interval mapping
        
        let pixelsOutput = self.intervalMapping(outputArray: output, fromMin: minValue, fromMax: maxValue, toMin: 0, toMax: 255.0)
        
        var pixels = [PixelData]()
        
        SFManager.shared.print(message: "Pixel data for loop start", function: .superResolutionStart)

        // Inorder to improve performance, instead of using for loop. Here we are using filter
        let _ = stride(from: 0, to: imageSize * 3 , by: 3).map { value in
            pixels.append(PixelData(alpha: 255, red: UInt8(pixelsOutput[value]), green: UInt8(pixelsOutput[value+1]), blue: UInt8(pixelsOutput[value+2])))
        }
        
        //TODO: Check with yuvaraj

//        for i in stride(from: 0, to: imageSize * 3 , by: 3) {
//            let pixelValue = PixelData(a: 255, r: UInt8(pixelsOutput[i]), g: UInt8(pixelsOutput[i+1]), b: UInt8(pixelsOutput[i+2]))
//            pixels.append(pixelValue)
//        }
        
        SFManager.shared.print(message: "Pixel data for loop end", function: .superResolutionStart)

        
        let _ = CGSize(width: srcImgWidth!, height: srcImgHeight!)
        
        let whiteImage = UIImage.from(color: .white)
        
        var finalSRImg = whiteImage.imageFromARGB32Bitmap(pixels: pixels, width: imageWidth, height: imageHeight)
        
        let src = Mat(uiImage: finalSRImg)
        
        let dst = Mat()
        
        SFManager.shared.print(message: "Image resize", function: .superResolutionStart)
        
        Imgproc.resize(src: src, dst: dst, dsize: Size2i(width: Int32(srcImgWidth!) * 2, height: Int32(srcImgHeight!) * 2))
        
        SFManager.shared.print(message: "Before dst toUIImage", function: .superResolutionStart)
        
        let imgSRreSize = dst.toUIImage()//self.resizeImage(image: finalSRImg, targetSize: srcImg2xSize)
        
        SFManager.shared.print(message: "Before gamma", function: .superResolutionStart)
        
         
        
        SFManager.shared.print(message: "Native Gamma adjust start", function: .superResolutionStart)

        let context = CIContext(options: nil)
        
        if let currentFilter = CIFilter(name: "CIGammaAdjust") {
            let inputImage = CIImage(image: imgSRreSize)
            currentFilter.setValue(inputImage, forKey: kCIInputImageKey)
            currentFilter.setValue(2, forKey: "inputPower")

            if let output = currentFilter.outputImage {
                if let cgimg = context.createCGImage(output, from: output.extent) {
                    let processedImage = UIImage(cgImage: cgimg)
                    finalSRImg = processedImage
                     
                    SFManager.shared.print(message: "Native Gamma adjust completed", function: .superResolutionStart)

                }
            } else {
                SFManager.shared.print(message: "Native Gamma adjust failed", function: .superResolutionStart)

            }
            
        } else {
            SFManager.shared.print(message: "Native Gamma adjust failed", function: .superResolutionStart)

        }
        
        SFManager.shared.print(message: "Native Gamma adjust finish", function: .superResolutionStart)

        //let finalSRImg1 = self.applyGammaCorrection(to: imgSRreSize)!

        SFManager.shared.print(message: "Final", function: .superResolutionStart)

        return finalSRImg
             

        
    }
    
    func intervalMapping(outputArray:[Float],fromMin:Float,fromMax:Float, toMin:Float, toMax:Float) -> [Float] {
        
        var resultArray:[Float] = []
        let fromRange:Float = fromMax - fromMin
        let toRange = toMax - toMin
        
        ///New while loop approach

//        var i = 0
//        while i < outputArray.count {
//            let val:Float = outputArray[i]
//            let elementUpdate = NSNumber(value: (((val - from_min) / from_range) * to_range) + to_min).floatValue
//            resultArray.append(elementUpdate)
//            i = i+1
//        }
        
        //Instaed of used loops like above and below, if we using this filter methods our performance gets increase and delay will be reduced
        let _ = outputArray.map { element in
            resultArray.append(NSNumber(value: (((element - fromMin) / fromRange) * toRange) + toMin).floatValue)
        }
        
        ///Old for loop approach
//        for i in 0..<outputArray.count {
//            let val:Float = outputArray[i]
//            let elementUpdate = NSNumber(value: (((val - from_min) / from_range) * to_range) + to_min).floatValue
//            resultArray.append(elementUpdate)
//        }
        
        return resultArray
        
    }
    
    
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    func applyGammaCorrection(to image: UIImage) -> UIImage? {
        
        guard let cgImage = image.cgImage else { return nil }
        
        // Redraw image for correct pixel format
        var colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        var bytesPerRow = width * 4
        
        let imageData = UnsafeMutablePointer<Pixel>.allocate(capacity: width * height)
        
        guard let imageContext = CGContext(
            data: imageData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        imageContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let pixels = UnsafeMutableBufferPointer<Pixel>(start: imageData, count: width * height)
        
        // constant value curve
        let maxSize = 256
        let maxValueDbl = 255.0
        let maxValueInt = 255
        let reverse = 1.0
        
        // gamma arrays
        var gammaR = [Int]()
        var gammaG = [Int]()
        var gammaB = [Int]()
        
        // setting values for every gamma channels
        for pixel in 0...maxSize {
            
            gammaR.append(min(maxValueInt, Int((maxValueDbl * pow(Double(pixel) / maxValueDbl, reverse/0.6) + 0.5))))
            
            gammaG.append(min(maxValueInt, Int((maxValueDbl * pow(Double(pixel) / maxValueDbl, reverse/0.6) + 0.5))))
            
            gammaB.append(min(maxValueInt, Int((maxValueDbl * pow(Double(pixel) / maxValueDbl, reverse/0.6) + 0.5))))
            
        }
        
        for row in 0..<height {
            for col in 0..<width {
                let index = row * width + col
                var pixel = pixels[index]
                
                let redPixel = Int(pixel.red)
                let greenPixel = Int(pixel.green)
                let bluePixel = Int(pixel.blue)
                let alphaPixel = Int(pixel.alpha)
                
                pixel.alpha = UInt8(alphaPixel)
                pixel.red = UInt8(gammaR[redPixel])
                pixel.blue = UInt8(gammaB[bluePixel])
                pixel.green = UInt8(gammaG[greenPixel])
                
                pixels[index] = pixel
            }
        }
        
        colorSpace = CGColorSpaceCreateDeviceRGB()
        bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        
        bytesPerRow = width * 4
        
        guard let context = CGContext(
            data: pixels.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            releaseCallback: nil,
            releaseInfo: nil
        ) else { return nil }
        
        guard let newCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: newCGImage)
        
    }
    
}


/**
 This is the public struct pixel data that holds RGB pixels
 */
public struct PixelData {
    var alpha: UInt8
    var red: UInt8
    var green: UInt8
    var blue: UInt8
}

public extension UIImage {
    
    static func from(color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 512, height: 512)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context!.setFillColor(color.cgColor)
        context!.fill(rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img!
    }
    
    func imageFromARGB32Bitmap(pixels:[PixelData], width: Int, height: Int) -> UIImage {
        
        let bitsPerComponent:Int = 8
        let bitsPerPixel:Int = 32
        
        //        assert(pixels.count == Int(width * height) * 3)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue)
        
        var data = pixels // Copy to mutable []
        guard
            let providerRef = CGDataProvider(
                data: Data(bytes: &data, count: data.count * MemoryLayout<PixelData>.size) as CFData
            )
        else { fatalError("fail in image convert") }
        
        guard
            let cgim = CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerPixel,
                bytesPerRow: width * MemoryLayout<PixelData>.size,
                space: rgbColorSpace,
                bitmapInfo: bitmapInfo,
                provider: providerRef,
                decode: nil,
                shouldInterpolate: true,
                intent: CGColorRenderingIntent.defaultIntent
            )
        else { fatalError("fail in image convert 2")}
        return UIImage(cgImage: cgim)
    }
    
    
}


struct SuperResolutionModel {
    var red: Float
    var green: Float
    var blue: Float
}

extension UIImage {
    var data : Data? {
        return cgImage?.dataProvider?.data as Data?
    }
}

