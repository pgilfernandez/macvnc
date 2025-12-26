#import "ScreenCaptureThread.h"
#import "ScreenCapturer.h"

@interface ScreenCaptureThread ()

@property (nonatomic, assign) CGDirectDisplayID displayID;
@property (nonatomic, strong) ScreenCapturer *capturer;
@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, assign) BOOL stopRequested;
@property (nonatomic, copy, nonnull) void (^frameHandler)(CMSampleBufferRef sampleBuffer);
@property (nonatomic, copy, nonnull) void (^errorHandler)(NSError *error);

@end

@implementation ScreenCaptureThread

- (instancetype)initWithDisplay:(CGDirectDisplayID)displayID
                   frameHandler:(void (^)(CMSampleBufferRef))frameHandler
                   errorHandler:(void (^)(NSError *))errorHandler {
    if (self = [super init]) {
        _displayID = displayID;
        _frameHandler = [frameHandler copy];
        _errorHandler = [errorHandler copy];
    }
    return self;
}

- (BOOL)start {
    if (self.thread && !self.thread.finished) {
        return YES;
    }

    self.stopRequested = NO;

    self.thread = [[NSThread alloc] initWithBlock:^{
        @autoreleasepool {
            ScreenCaptureThread *strongSelf = self;
            [[NSThread currentThread] setName:@"ScreenCaptureThread"];
            NSLog(@"[ScreenCaptureThread] Starting dedicated capture thread...");

            strongSelf.capturer = [[ScreenCapturer alloc] initWithDisplay:strongSelf.displayID
                                                             frameHandler:strongSelf.frameHandler
                                                             errorHandler:^(NSError *error) {
                NSLog(@"[ScreenCaptureThread] Failed to start ScreenCaptureKit: %@", error);
                strongSelf.errorHandler(error);
            }];

            if (!strongSelf.capturer) {
                NSLog(@"[ScreenCaptureThread] Failed to start: capturer is nil");
                return;
            }

            [strongSelf.capturer startCapture];
            NSLog(@"[ScreenCaptureThread] Successfully started on dedicated thread");

            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            int iteration = 0;
            while (!strongSelf.stopRequested &&
                   [runLoop runMode:NSDefaultRunLoopMode
                          beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]]) {
                if (iteration < 5) {
                    NSLog(@"[ScreenCaptureThread] RunLoop active (iteration %d)", iteration);
                }
                iteration++;
            }

            NSLog(@"[ScreenCaptureThread] Stopping capture thread...");
            [strongSelf.capturer stopCapture];
            strongSelf.capturer = nil;
            NSLog(@"[ScreenCaptureThread] Stopped");
        }
    }];

    [self.thread start];
    return YES;
}

- (void)stop {
    if (!self.thread || self.thread.finished) {
        return;
    }

    self.stopRequested = YES;
    [self performSelector:@selector(noop)
                 onThread:self.thread
               withObject:nil
            waitUntilDone:NO];
    while (!self.thread.finished) {
        [NSThread sleepForTimeInterval:0.05];
    }
    self.thread = nil;
}

- (void)noop {
    // intentionally empty; used to wake the run loop
}

@end
