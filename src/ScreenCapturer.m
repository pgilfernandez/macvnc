#import "ScreenCapturer.h"

@interface ScreenCapturer ()

@property (nonatomic, assign) CGDirectDisplayID displayID;
@property (nonatomic, strong) SCStream *stream;
@property (nonatomic, assign) BOOL hasReceivedFrames;
@property (nonatomic, strong) NSTimer *permissionCheckTimer;

// handlers
@property (nonatomic, copy, nonnull) void (^frameHandler)(CMSampleBufferRef sampleBuffer);
@property (nonatomic, copy, nonnull) void (^errorHandler)(NSError *error);

@end


@implementation ScreenCapturer

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

- (void)startCapture {
    NSLog(@"[ScreenCapturer] Starting capture for display ID: %d", self.displayID);
    NSLog(@"[ScreenCapturer] Requesting screen capture permissions...");

    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent *content, NSError *error) {
        if (error) {
            NSLog(@"[ScreenCapturer] Error getting shareable content: %@", error);
            self.errorHandler(error);
            return;
        }
        NSLog(@"[ScreenCapturer] Successfully got shareable content with %lu displays", (unsigned long)content.displays.count);

        SCDisplay *display = content.displays[[content.displays indexOfObjectPassingTest:^BOOL(SCDisplay *_Nonnull d, NSUInteger idx, BOOL *_Nonnull stop) {
                    return d.displayID == self.displayID;
                }]];

        if (!display) {
            NSLog(@"[ScreenCapturer] Display ID %d not found in shareable content", self.displayID);
            NSError *noDisplayError = [NSError errorWithDomain:@"ScreenCapturerErrorDomain"
                                                          code:1
                                                      userInfo:@{NSLocalizedDescriptionKey : @"Display not available for capture"}];
            self.errorHandler(noDisplayError);
            return;
        }
        size_t pixelWidth = CGDisplayPixelsWide(self.displayID);
        size_t pixelHeight = CGDisplayPixelsHigh(self.displayID);
        NSLog(@"[ScreenCapturer] Found display, starting stream with size %dx%d (pixels)", (int)pixelWidth, (int)pixelHeight);
        if (pixelWidth != display.width || pixelHeight != display.height) {
            NSLog(@"[ScreenCapturer] Retina/scaled display detected: SCDisplay reports %dx%d points", (int)display.width, (int)display.height);
        }

        SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
        // can later be adjusted for server-side scaling
        config.width = pixelWidth;
        config.height = pixelHeight;
        // set max frame rate to 60 FPS
        config.minimumFrameInterval = CMTimeMake(1, 60);
        config.pixelFormat = kCVPixelFormatType_32BGRA;

        SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:(display) excludingWindows:(@[])];
        self.stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:self];

        NSError *addOutputError = nil;
        [self.stream addStreamOutput:self
                                type:SCStreamOutputTypeScreen
                  sampleHandlerQueue:dispatch_queue_create("libvncserver.examples.mac", NULL)
                               error:&addOutputError];
        if (addOutputError) {
            self.errorHandler(addOutputError);
            return;
        }

        [self.stream startCaptureWithCompletionHandler:^(NSError * _Nullable startError) {
            if (startError) {
                NSLog(@"[ScreenCapturer] Error starting capture: %@", startError);
                self.errorHandler(startError);
            } else {
                NSLog(@"[ScreenCapturer] Capture started successfully");

                // Check for frames after 3 seconds
                self.permissionCheckTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                                             repeats:NO
                                                                               block:^(NSTimer * _Nonnull timer) {
                    if (!self.hasReceivedFrames) {
                        NSLog(@"[ScreenCapturer] WARNING: Stream started but no frames received after 3 seconds!");
                        NSLog(@"[ScreenCapturer] This usually means Screen Recording permission is missing.");
                        NSLog(@"[ScreenCapturer] Please grant Screen Recording permission in:");
                        NSLog(@"[ScreenCapturer] System Settings > Privacy & Security > Screen Recording");
                        fprintf(stderr, "\n*** PERMISSION ERROR ***\n");
                        fprintf(stderr, "Screen Recording permission is required but not granted.\n");
                        fprintf(stderr, "Please go to: System Settings > Privacy & Security > Screen Recording\n");
                        fprintf(stderr, "And enable permission for Terminal (or the app running macVNC).\n");
                        fprintf(stderr, "Then restart this application.\n");
                        fprintf(stderr, "************************\n\n");
                    }
                }];
            }
        }];
    }];
}

- (void)stopCapture {
    [self.stream stopCaptureWithCompletionHandler:^(NSError * _Nullable stopError) {
        if (stopError) {
            self.errorHandler(stopError);
        }
        self.stream = nil;
    }];
}


/*
  SCStreamDelegate methods
*/

- (void) stream:(SCStream *) stream didStopWithError:(NSError *) error {
    self.errorHandler(error);
}


/*
  SCStreamOutput methods
*/

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    static int frameCount = 0;
    if (type == SCStreamOutputTypeScreen) {
        if (!self.hasReceivedFrames) {
            self.hasReceivedFrames = YES;
            NSLog(@"[ScreenCapturer] ✓ SUCCESS: Receiving frames! Screen Recording permission is working.");
        }
        if (frameCount++ < 5) {
            NSLog(@"[ScreenCapturer] Received frame #%d", frameCount);
        }
        self.frameHandler(sampleBuffer);
    }
}

@end
