#pragma once

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>

@interface ScreenCaptureThread : NSObject

- (instancetype)initWithDisplay:(CGDirectDisplayID)displayID
                   frameHandler:(void (^)(CMSampleBufferRef sampleBuffer))frameHandler
                   errorHandler:(void (^)(NSError *error))errorHandler;

- (BOOL)start;
- (void)stop;

@end
