//
//  OpenCVWrapper.h
//  TestOpenCV
//
//  Created by MAC-OBS-20 on 01/01/23.
//
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
//#include <opencv2/core/core_c.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject

- (NSData *)processedData:(NSInteger)contWIdth imageData:(void *)imageData ;

@end

NS_ASSUME_NONNULL_END
