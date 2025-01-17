//
//  MNMovieWriter.m
//  WeChat
//
//  Created by Vicent on 2021/2/9.
//  Copyright © 2021 Vincent. All rights reserved.
//

#import "MNMovieWriter.h"
#if __has_include(<AVFoundation/AVFoundation.h>)
#import <AVFoundation/AVFoundation.h>

/**
 文件写入状态
 - MNMovieWriteStatusIdle: 闲置状态
 - MNMovieWriteStatusPreparing: 即将写入
 - MNMovieWriteStatusLocking: 等待结束
 - MNMovieWriteStatusWriting: 正在写入
 - MNMovieWriteStatusFinish: 结束
 - MNMovieWriteStatusCancelled: 取消
 - MNMovieWriteStatusFailed: 失败
 */
typedef NS_ENUM(NSInteger, MNMovieWriteStatus) {
    MNMovieWriteStatusIdle = 0,
    MNMovieWriteStatusPreparing,
    MNMovieWriteStatusLocking,
    MNMovieWriteStatusWriting,
    MNMovieWriteStatusFinish,
    MNMovieWriteStatusCancelled,
    MNMovieWriteStatusFailed
};

@interface MNMovieWriter ()
@property (nonatomic) MNMovieWriteStatus status;
@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) dispatch_queue_t writQueue;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;
@end

@implementation MNMovieWriter
- (instancetype)init {
    if (self = [super init]) {
        self.writQueue = dispatch_queue_create("com.mn.movie.write.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL delegate:(id<MNMovieWriteDelegate>)delegate {
    NSParameterAssert(URL != nil);
    if (self = [self init]) {
        self.URL = URL;
        self.delegate = delegate;
    }
    return self;
}

#pragma mark - 开始/停止
- (void)startWriting {
    __weak typeof(self) weakself = self;
    dispatch_async(self.writQueue, ^{
        __strong typeof(self) self = weakself;
        @synchronized (self) {
            if (self.status == MNMovieWriteStatusPreparing) {
                NSLog(@"⚠️⚠️⚠️Already prepared, cannot prepare again!⚠️⚠️⚠️");
                return;
            }
            if (self.status == MNMovieWriteStatusWriting) {
                NSLog(@"⚠️⚠️⚠️Moive is writing!⚠️⚠️⚠️");
                return;
            }
            if (!self.URL) {
                [self setStatus:MNMovieWriteStatusFailed error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotCreateFile userInfo:@{NSLocalizedDescriptionKey:@"无法保存文件"}]];
                return;
            }
            if (!self.URL.isFileURL) {
                [self setStatus:MNMovieWriteStatusFailed error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnsupportedURL userInfo:@{NSLocalizedDescriptionKey:@"未发现沙盒路径"}]];
                return;
            }
            if (self.URL.pathExtension.length <= 0) {
                [self setStatus:MNMovieWriteStatusFailed error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnsupportedURL userInfo:@{NSLocalizedDescriptionKey:@"不支持文件夹路径"}]];
                return;
            }
        }
        
        [NSFileManager.defaultManager removeItemAtURL:self.URL error:nil];
        if (![NSFileManager.defaultManager createDirectoryAtPath:self.URL.path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL]) {
            @synchronized (self) {
                [self setStatus:MNMovieWriteStatusFailed error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotWriteToFile userInfo:@{NSLocalizedDescriptionKey:@"无法写入文件"}]];
            }
            return;
        }
        
        NSError *error;
        AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:self.URL fileType:AVFileTypeQuickTimeMovie error:&error];
        if (error || !writer) {
            @synchronized (self) {
                [self setStatus:MNMovieWriteStatusFailed error:error];
            }
        } else {
            self.writer = writer;
            @synchronized (self) {
                [self setStatus:MNMovieWriteStatusPreparing error:nil];
            }
        }
    });
}

- (void)finishWriting {
    @synchronized (self) {
        if (self.status != MNMovieWriteStatusWriting) return;
        [self setStatus:MNMovieWriteStatusLocking error:nil];
    }
    __weak typeof(self) weakself = self;
    dispatch_async(self.writQueue, ^{
        // 有可能是在写入视频时发生了错误, 改变了状态, 这里就不再操作
        if (weakself.status != MNMovieWriteStatusLocking) return;
        [weakself.writer finishWritingWithCompletionHandler:^{
            __strong typeof(self) self = weakself;
            NSError *error = self.writer.error;
            @synchronized (self) {
                [self setStatus:(error ? MNMovieWriteStatusFailed : MNMovieWriteStatusFinish) error:error];
            }
        }];
    });
}

- (void)cancelWriting {
    @synchronized (self) {
        if (self.status != MNMovieWriteStatusWriting) return;
        [self setStatus:MNMovieWriteStatusLocking error:nil];
    }
    __weak typeof(self) weakself = self;
    dispatch_async(self.writQueue, ^{
        // 有可能是在写入视频时发生了错误, 改变了状态, 这里就不再操作
        if (weakself.status != MNMovieWriteStatusLocking) return;
        [weakself.writer cancelWriting];
        @synchronized (self) {
            [self setStatus:MNMovieWriteStatusCancelled error:nil];
        }
    });
}

#pragma mark - Sample Buffer
- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(AVMediaType)mediaType {
    
    // 缓存为空 出错
    if (sampleBuffer == NULL) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"NULL sample buffer" userInfo:nil];
        return;
    }

    // 强引用缓存数据
    CFRetain(sampleBuffer);

    dispatch_async(self.writQueue, ^{
        @autoreleasepool {

            @synchronized (self) {
                if (self.status != MNMovieWriteStatusPreparing && self.status != MNMovieWriteStatusWriting) {
                    CFRelease(sampleBuffer);
                    return;
                }
            }

            if (mediaType == AVMediaTypeVideo) {
                if (!self.videoInput) {
                    if (![self addVideoTrackWithSourceFormatDescription:CMSampleBufferGetFormatDescription(sampleBuffer)]) {
                        @synchronized (self) {
                            [self setStatus:MNMovieWriteStatusFailed error:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:@{NSLocalizedDescriptionKey:@"Can not add video input"}]];
                        }
                    }
                }

                if (self.audioInput && self.videoInput) {
                    if (![self appendVideoSampleBuffer:sampleBuffer]) {
                        @synchronized (self) {
                            [self setStatus:MNMovieWriteStatusFailed error:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:@{NSLocalizedDescriptionKey:@"Can not append video sample buffer"}]];
                        }
                    }
                }

            } else if (mediaType == AVMediaTypeAudio) {

                if (!self.audioInput) {
                    if (![self addAudioTrackWithSourceFormatDescription:CMSampleBufferGetFormatDescription(sampleBuffer)]) {
                        @synchronized (self) {
                            [self setStatus:MNMovieWriteStatusFailed error:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:@{NSLocalizedDescriptionKey:@"Can not add audio input"}]];
                        }
                    }
                }

                if (self.audioInput && self.videoInput) {
                    if (![self appendAudioSampleBuffer:sampleBuffer]) {
                        @synchronized (self) {
                            [self setStatus:MNMovieWriteStatusFailed error:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:@{NSLocalizedDescriptionKey:@"Can not append audio sample buffer"}]];
                        }
                    }
                }
            }
            
            CFRelease(sampleBuffer);
        }
        
        if (self.status == MNMovieWriteStatusPreparing && self.writer.status == AVAssetWriterStatusWriting) {
            @synchronized (self) {
                [self setStatus:MNMovieWriteStatusWriting error:nil];
            }
        }
    });
}

- (BOOL)appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
    if (self.writer.status == AVAssetWriterStatusUnknown) {
        if ([self.writer startWriting]) {
            [self.writer startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
        } else return NO;
    }
    
    if (self.writer.status == AVAssetWriterStatusWriting) {
        
        // 未准备好则放弃
        if (self.videoInput.readyForMoreMediaData) {
            
            return [self.videoInput appendSampleBuffer:sampleBuffer];
        }
        
        return YES;
    }
    
    return NO;
}

- (BOOL)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
    if (self.writer.status == AVAssetWriterStatusUnknown) {
        if ([self.writer startWriting]) {
            [self.writer startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
        } else return NO;
    }
    
    if (self.writer.status == AVAssetWriterStatusWriting) {
        
        // 未准备好则放弃
        if (self.audioInput.readyForMoreMediaData) {
            
            return [self.audioInput appendSampleBuffer:sampleBuffer];
        }
        
        return YES;
    }
    
    return NO;
}

- (BOOL)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription {
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
    NSUInteger numPixels = dimensions.width*dimensions.height;
    CGFloat bitsPerPixel = numPixels < (640*480) ? 4.05f : 10.1f;
    NSString *profileLevel = NSProcessInfo.processInfo.processorCount <= 1 ? AVVideoProfileLevelH264MainAutoLevel : AVVideoProfileLevelH264HighAutoLevel;
    NSDictionary *compression = @{AVVideoAverageBitRateKey: [NSNumber numberWithInteger:numPixels*bitsPerPixel],
                                  AVVideoExpectedSourceFrameRateKey:[NSNumber numberWithInt:self.frameRate],
                                  AVVideoMaxKeyFrameIntervalKey: [NSNumber numberWithInt:self.frameRate], AVVideoProfileLevelKey:profileLevel};
    NSDictionary *settings = @{AVVideoCodecKey:AVVideoCodecH264,
                               AVVideoWidthKey:[NSNumber numberWithInteger:dimensions.width],
                              AVVideoHeightKey:[NSNumber numberWithInteger:dimensions.height],
               AVVideoCompressionPropertiesKey:compression};
    if ([self.writer canApplyOutputSettings:settings forMediaType:AVMediaTypeVideo]) {
        AVAssetWriterInput *videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
        videoInput.expectsMediaDataInRealTime = YES;
        videoInput.transform = self.transform;
        if ([self.writer canAddInput:videoInput]) {
            [self.writer addInput:videoInput];
            self.videoInput = videoInput;
            return YES;
        }
    }
    return NO;
}

- (BOOL)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription {
    size_t aclSize = 0;
    const AudioStreamBasicDescription *currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    const AudioChannelLayout *channelLayout = CMAudioFormatDescriptionGetChannelLayout(formatDescription, &aclSize);
    NSData *dataLayout = aclSize > 0 ? [NSData dataWithBytes:channelLayout length:aclSize] : [NSData data];
    NSDictionary *settings = @{AVFormatIDKey: [NSNumber numberWithInteger: kAudioFormatMPEG4AAC],
                             AVSampleRateKey: [NSNumber numberWithFloat:currentASBD->mSampleRate],
                          AVChannelLayoutKey:dataLayout,
                       AVNumberOfChannelsKey: [NSNumber numberWithInteger:currentASBD->mChannelsPerFrame]};
    // AVEncoderBitRatePerChannelKey: [NSNumber numberWithInt: 64000]
    if ([self.writer canApplyOutputSettings:settings forMediaType:AVMediaTypeAudio]){
        AVAssetWriterInput *audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:settings];
        audioInput.expectsMediaDataInRealTime = YES;
        if ([self.writer canAddInput:audioInput]){
            [self.writer addInput:audioInput];
            self.audioInput = audioInput;
            return YES;
        }
    }
    return NO;
}

#pragma mark - 修改状态
- (void)setStatus:(MNMovieWriteStatus)status error:(NSError *)error {
    
    BOOL shouldNotifyDelegate = NO;

    if (status != _status) {
        _status = status;
        if (status >= MNMovieWriteStatusWriting) {
            shouldNotifyDelegate = YES;
            if (status >= MNMovieWriteStatusFinish) {
                self.writer = nil;
                self.audioInput = self.videoInput = nil;
                if (status >= MNMovieWriteStatusCancelled) {
                    if (self.URL) [NSFileManager.defaultManager removeItemAtURL:self.URL error:nil];
                }
            }
        }
    }
    
    if (shouldNotifyDelegate && self.delegate) {
        __weak typeof(self) weakself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) self = weakself;
            if (status == MNMovieWriteStatusWriting && [self.delegate respondsToSelector:@selector(movieWriterDidStartWriting:)]) {
                [self.delegate movieWriterDidStartWriting:self];
            } else if (status == MNMovieWriteStatusFinish && [self.delegate respondsToSelector:@selector(movieWriterDidFinishWriting:)]) {
                [self.delegate movieWriterDidFinishWriting:self];
            } else if (status == MNMovieWriteStatusCancelled && [self.delegate respondsToSelector:@selector(movieWriterDidCancelWriting:)]) {
                [self.delegate movieWriterDidCancelWriting:self];
            } else if (status == MNMovieWriteStatusFailed && [self.delegate respondsToSelector:@selector(movieWriter:didFailWithError:)]) {
                [self.delegate movieWriter:self didFailWithError:error];
            }
        });
    }
}

#pragma mark - Getter
- (BOOL)isWriting {
    @synchronized (self) {
        return self.status == MNMovieWriteStatusWriting;
    }
}

@end
#endif
