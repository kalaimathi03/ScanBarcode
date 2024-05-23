//
//  GammaCorrection.swift
//  ScanflowBarcodeReader
//
//


import Foundation
import opencv2

extension UIImage{
    
    func doGamma() -> UIImage {
        var resultImage:UIImage?
        let src = Mat(uiImage: self)
        src.convert(to: src, rtype: -1, alpha: 1.0, beta: 1.5)
        resultImage = src.toUIImage()
        return resultImage ?? self
    }
    

    func doGammaAndroid(red: Double, green: Double, blue: Double) -> UIImage{
        // create output image
        var bmOut = UIImage()
        // get image size
        let width = self.size.width
        let height = self.size.height
        // color information
        var alpha = Int()
        var processingRed = Int()
        var processingGreen = Int()
        var processingBlue = Int()
        var pixel = Int()
        // constant value curve
        let maxSize = 256
        let maxValueDbl = 255.0
        let maxValueInt = 255
        let REVERSE = 1.0
        
        // gamma arrays
        var gammaR = [Int]()
        var gammaG = [Int]()
        var gammaB = [Int]()
        
        // setting values for every gamma channels
        for channel in 0...maxSize {
            
            gammaR.append(min(maxValueInt, Int((maxValueDbl * pow(Double(channel) / maxValueDbl, REVERSE/red) + 0.5))))
            
            gammaG.append(min(maxValueInt, Int((maxValueDbl * pow(Double(channel) / maxValueDbl, REVERSE/green) + 0.5))))
            
            gammaB.append(min(maxValueInt, Int((maxValueDbl * pow(Double(channel) / maxValueDbl, REVERSE/blue) + 0.5))))
            
        }
        
//        var pixels = [PixelData]()
        
        // apply gamma table
        for row in 0...Int(width) {
            for column in 0...Int(height) {
//                // get pixel color
                let pixelValue = self.getPixelColor(xPosition: row, yPosition: column)
            }
        }
        
        
        var pixels: [PixelData] = .init(repeating: .init(alpha: 0, red: 0, green: 0, blue: 0), count: Int(width * height))

        
        for pixel in 0...gammaB.count-1 {
            let pixelValue = PixelData(alpha: 255, red: UInt8(gammaR[pixel]), green: UInt8(gammaG[pixel]), blue: UInt8(gammaB[pixel]))
            
            
            pixels.append(pixelValue)
        }
        

        bmOut = UIImage(pixels: pixels, width: Int(width), height: Int(height))!

        
        return bmOut
    }
    
}

extension CGImage {
    func colors(at: [CGPoint]) -> [UIColor]? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo),
            let ptr = context.data?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        return at.map { pixel in
            let pixelColorReference = bytesPerRow * Int(pixel.y) + bytesPerPixel * Int(pixel.x)

            let alpha = CGFloat(ptr[pixelColorReference + 3]) / 255.0
            let red = (CGFloat(ptr[pixelColorReference]) / alpha) / 255.0
            let green = (CGFloat(ptr[pixelColorReference + 1]) / alpha) / 255.0
            let blue = (CGFloat(ptr[pixelColorReference + 2]) / alpha) / 255.0

            return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        }
    }
}

extension UIImage {
    convenience init?(pixels: [PixelData], width: Int, height: Int) {
        guard width > 0 && height > 0, pixels.count == width * height else { return nil }
        var data = pixels
        guard let providerRef = CGDataProvider(data: Data(bytes: &data, count: data.count * MemoryLayout<PixelData>.size) as CFData)
            else { return nil }
        guard let cgim = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * MemoryLayout<PixelData>.size,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)
        else { return nil }
        self.init(cgImage: cgim)
    }
}

extension UIImage {
    func getPixelColor (xPosition: Int, yPosition: Int) -> UIColor? {
        guard xPosition >= 0 && xPosition < Int(size.width) && yPosition >= 0 && yPosition < Int(size.height),
            let cgImage = cgImage,
            let provider = cgImage.dataProvider,
            let providerData = provider.data,
            let data = CFDataGetBytePtr(providerData) else {
            return nil
        }

        let numberOfComponents = 4
        let pixelData = ((Int(size.width) * yPosition) + xPosition) * numberOfComponents

        let red = CGFloat(data[pixelData]) / 255.0
        let green = CGFloat(data[pixelData + 1]) / 255.0
        let blue = CGFloat(data[pixelData + 2]) / 255.0
        let alpha = CGFloat(data[pixelData + 3]) / 255.0

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
}


/**
 This is the public struct pixel data that holds RGB value in UIInt8 format
 */
public struct Pixel {
    public var value: UInt32
    
    public var red: UInt8 {
        get {
            return UInt8(value & 0xFF)
        } set {
            value = UInt32(newValue) | (value & 0xFFFFFF00)
        }
    }
    
    public var green: UInt8 {
        get {
            return UInt8((value >> 8) & 0xFF)
        } set {
            value = (UInt32(newValue) << 8) | (value & 0xFFFF00FF)
        }
    }
    
    public var blue: UInt8 {
        get {
            return UInt8((value >> 16) & 0xFF)
        } set {
            value = (UInt32(newValue) << 16) | (value & 0xFF00FFFF)
        }
    }
    
    public var alpha: UInt8 {
        get {
            return UInt8((value >> 24) & 0xFF)
        } set {
            value = (UInt32(newValue) << 24) | (value & 0x00FFFFFF)
        }
    }
}

