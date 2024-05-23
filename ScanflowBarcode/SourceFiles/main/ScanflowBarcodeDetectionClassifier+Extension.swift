//
//  ScanflowBarcodeDetectionClassifierExtension.swift
//  ScanflowBarcode
//
//  Created by Mac-OBS-46 on 14/09/22.
//

import Foundation


/**
 This is the public protocol that contains the output function after detection of bar code / qr code
 */
public protocol ScanflowDetectionClassiifierDelegate: AnyObject {
    /**
     This is the delegate function of returns detected code and code type and results
     - Parameters:
        - result: the detected code
        - codeType: the detected code type
        - results: an array of results in string
     */
    func detected(result: String, codeType: String, results: [String])
    
}



