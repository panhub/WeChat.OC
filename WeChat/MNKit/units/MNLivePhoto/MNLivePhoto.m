//
//  MNLivePhoto.m
//  MNKit
//
//  Created by Vincent on 2019/12/14.
//  Copyright © 2019 Vincent. All rights reserved.
//

#import "MNLivePhoto.h"
#if __has_include(<Photos/PHLivePhoto.h>)
#import "MNJPEG.h"
#import "MNQuickTime.h"
#import <Photos/PHLivePhoto.h>

@implementation MNLivePhoto
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_1
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
+ (void)requestLivePhotoWithVideoFileAtPath:(NSString *)videoPath
                              completionHandler:(void(^)(MNLivePhoto *livePhoto))completionHandler
{
    [self requestLivePhotoWithVideoFileAtPath:videoPath stillSeconds:0.01f stillDuration:0.7f progressHandler:nil completionHandler:completionHandler];
}

+ (void)requestLivePhotoWithVideoFileAtPath:(NSString *)videoPath
                                  stillSeconds:(NSTimeInterval)seconds
                                    stillDuration:(Float64)duration
                                progressHandler:(void(^)(float  progress))progressHandler
                              completionHandler:(void(^)(MNLivePhoto *livePhoto))completionHandler
{
    [self requestLivePhotoWithVideoAtPath:videoPath stillSeconds:seconds stillDuration:duration progressHandler:^(float progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (progressHandler) progressHandler(MIN(.99f, progress));
        });
    } completionHandler:^(NSString *jpgPath, NSString *movPath) {
        if (jpgPath && movPath) {
            [PHLivePhoto requestLivePhotoWithResourceFileURLs:@[[NSURL fileURLWithPath:jpgPath], [NSURL fileURLWithPath:movPath]] placeholderImage:[UIImage imageWithContentsOfFile:jpgPath] targetSize:CGSizeZero contentMode:PHImageContentModeAspectFit resultHandler:^(PHLivePhoto * _Nullable livePhoto, NSDictionary * _Nonnull info) {
                if (livePhoto) {
                    if ([[info objectForKey:@"PHLivePhotoInfoIsDegradedKey"] boolValue]) return;
                    NSURL *videoURL = [livePhoto valueForKey:@"videoURL"];
                    if (!videoURL) {
                        videoURL = [NSURL fileURLWithPath:movPath];
                        [livePhoto setValue:videoURL forKey:@"videoURL"];
                    }
                    NSURL *imageURL = [livePhoto valueForKey:@"imageURL"];
                    if (!imageURL) {
                        imageURL = [NSURL fileURLWithPath:jpgPath];
                        [livePhoto setValue:imageURL forKey:@"imageURL"];
                    }
                    MNLivePhoto *photo = [MNLivePhoto new];
                    photo->_videoURL = videoURL;
                    photo->_imageURL = imageURL;
                    photo->_content = livePhoto;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (progressHandler) progressHandler(1.f);
                        if (completionHandler) completionHandler(photo);
                    });
                } else {
                    [NSFileManager.defaultManager removeItemAtPath:jpgPath error:nil];
                    [NSFileManager.defaultManager removeItemAtPath:movPath error:nil];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completionHandler) completionHandler(nil);
                    });
                }
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandler) completionHandler(nil);
            });
        }
    }];
}
#pragma clang diagnostic pop
#endif

+ (void)requestLivePhotoWithVideoAtPath:(NSString *)videoPath
                    completionHandler:(void(^)(NSString *jpgPath, NSString *movPath))completionHandler
{
    [self requestLivePhotoWithVideoAtPath:videoPath stillSeconds:0.01f stillDuration:0.7f progressHandler:nil completionHandler:completionHandler];
}

+ (void)requestLivePhotoWithVideoAtPath:(NSString *)videoPath
                           stillSeconds:(NSTimeInterval)seconds
                              stillDuration:(Float64)duration
                      progressHandler:(void(^)(float  progress))progressHandler
                    completionHandler:(void(^)(NSString *jpgPath, NSString *movPath))completionHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        BOOL isDirectory = NO;
        if (![NSFileManager.defaultManager fileExistsAtPath:videoPath isDirectory:&isDirectory] || isDirectory) {
            NSLog(@"video path error");
            if (completionHandler) completionHandler(nil, nil);
            return;
        }
        // 获取截图
        AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:videoPath] options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@(YES)}];
        __block CGSize naturalSize = CGSizeZero;
        [videoAsset.tracks enumerateObjectsUsingBlock:^(AVAssetTrack * _Nonnull track, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([track.mediaType isEqualToString:AVMediaTypeVideo]) {
                naturalSize = CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform);
                naturalSize.width = fabs(naturalSize.width);
                naturalSize.height = fabs(naturalSize.height);
                *stop = YES;
            }
        }];
        if (CGSizeEqualToSize(naturalSize, CGSizeZero)) {
            NSLog(@"video natural size error");
            if (completionHandler) completionHandler(nil, nil);
            return;
        }
        // 获取封面图片
        AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:videoAsset];
        generator.appliesPreferredTrackTransform = YES;
        generator.requestedTimeToleranceBefore = kCMTimeZero;
        generator.requestedTimeToleranceAfter = kCMTimeZero;
        generator.maximumSize = naturalSize;
        
        CGImageRef imageRef = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(MAX(0.01f, MIN(CMTimeGetSeconds(videoAsset.duration), seconds)), videoAsset.duration.timescale) actualTime:NULL error:NULL];
        if (!imageRef) {
            NSLog(@"video thumbnail error");
            if (completionHandler) completionHandler(nil, nil);
            return;
        }
        UIImage *stillImage = [UIImage imageWithCGImage:imageRef];
        // 标识
        NSString *identifier = [[NSNumber numberWithLongLong:NSDate.date.timeIntervalSince1970*1000] stringValue];
        // JPG图片
        NSString *jpgPath = [MNLivePhoto generateFilePathWithName:identifier extension:@"jpg"];
        MNJPEG *JPEG = [[MNJPEG alloc] initWithImage:stillImage];
        if ([JPEG writeToFile:jpgPath withIdentifier:identifier] == NO) {
            NSLog(@"write jpeg error");
            if (completionHandler) completionHandler(nil, nil);
            return;
        }
        // MOV视频
        NSString *movPath = [MNLivePhoto generateFilePathWithName:identifier extension:@"mov"];
        MNQuickTime *QuickTime = [[MNQuickTime alloc] initWithVideoAsset:videoAsset];
        QuickTime.identifier = identifier;
        QuickTime.outputPath = movPath;
        QuickTime.stillDuration = duration;
        [QuickTime exportAsynchronouslyWithProgressHandler:progressHandler completionHandler:^(MNMovExportStatus status, NSError * _Nullable error) {
            BOOL succeed = status == MNMovExportStatusCompleted;
            if (completionHandler) if (completionHandler) completionHandler(succeed ? jpgPath : nil, succeed ? movPath : nil);
        }];
    });
}

+ (NSString *)generateFilePathWithName:(NSString *)name extension:(NSString *)extension {
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [directories.lastObject stringByAppendingPathComponent:[NSString stringWithFormat:@"MNLivePhoto/%@.%@", name, extension]];
}

- (void)removeFiles {
    if (self.videoURL) [NSFileManager.defaultManager removeItemAtURL:self.videoURL error:nil];
    if (self.imageURL) [NSFileManager.defaultManager removeItemAtURL:self.imageURL error:nil];
    self->_videoURL = nil;
    self->_videoURL = nil;
}

@end
#endif
