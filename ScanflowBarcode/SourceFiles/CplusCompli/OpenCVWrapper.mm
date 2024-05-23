//
//  OpenCVWrapper.m
//  TestOpenCV
//
//  Created by MAC-OBS-20 on 01/01/23.
//

#import "OpenCVWrapper.h"

@implementation OpenCVWrapper

- (NSData *)processedData:(NSInteger)contWIdth imageData:(void *)imageData {
    NSMutableData *inputData = [NSMutableData data];
    
    for (int row = 0; row < 512; ++row) {
        for (int col = 0; col < 512; ++col) {
            
            long offset = 4 * (row * contWIdth + col);
            // (Ignore offset 0, the unused alpha channel)
            uint8_t red = *((uint8_t *)imageData + offset + 1);
            uint8_t green = *((uint8_t *)imageData + offset + 2);
            uint8_t blue = *((uint8_t *)imageData + offset + 3);
            
            float normalizedRed = (float)(red - 127.5) / 1.0;
            float normalizedGreen = (float)(green - 127.5) / 1.0;
            float normalizedBlue = (float)(blue - 127.5) / 1.0;
            
            // Append normalized values to Data object in RGB order.
            const size_t elementSize = sizeof(normalizedRed);
            char bytes[elementSize];
            memcpy(bytes, &normalizedRed, elementSize);
            [inputData appendBytes:bytes length:elementSize];
            memcpy(bytes, &normalizedGreen, elementSize);
            [inputData appendBytes:bytes length:elementSize];
            memcpy(bytes, &normalizedBlue, elementSize);
            [inputData appendBytes:bytes length:elementSize];
        }
    }
    return [inputData copy];
}


@end
