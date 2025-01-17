//
//  MNAsset.m
//  MNKit
//
//  Created by Vincent on 2019/8/30.
//  Copyright © 2019 Vincent. All rights reserved.
//

#import "MNAsset.h"
#import "MNAssetHelper.h"
#import "NSDate+MNHelper.h"
#import "UIImage+MNAnimated.h"
#import "MNAssetPickConfiguration.h"
#import "PHAsset+MNAssetResource.h"
#import "MNAssetExporter+MNExportMetadata.h"
#if __has_include(<Photos/Photos.h>)
#import <Photos/Photos.h>
#endif

@interface MNAsset ()
@property (nonatomic) BOOL isTakeModel;
@end

@implementation MNAsset
- (instancetype)init {
    if (self = [super init]) {
#if __has_include(<Photos/Photos.h>)
        self.requestId = PHInvalidImageRequestID;
        self.downloadId = PHInvalidImageRequestID;
#else
        self.requestId = 0;
        self.downloadId = 0;
#endif
        self->_enabled = YES;
        self->_fileSizeString = @"";
        self->_status = MNAssetStatusUnknown;
        self->_source = MNAssetSourceUnknown;
    }
    return self;
}

+ (MNAsset *)takeModel {
    MNAsset *model = [MNAsset new];
    model->_isTakeModel = YES;
    model->_source = MNAssetSourceResource;
    model->_thumbnail = [MNBundle imageForResource:@"icon_takepicHL"];
    return model;
}

+ (MNAsset *)assetWithContent:(id)content {
    return [self assetWithContent:content configuration:nil];
}

+ (MNAsset *)assetWithContent:(id)content configuration:(MNAssetPickConfiguration *)configuration {
    if (!content) return nil;
    MNAsset *model = [MNAsset new];
    model->_enabled = YES;
    model->_content = content;
    model->_source = MNAssetSourceResource;
    model->_status = MNAssetStatusCompleted;
    if (configuration) model->_renderSize = configuration.renderSize;
    if ([content isKindOfClass:UIImage.class]) {
        UIImage *image = content;
        if (image.isAnimatedImage) {
            model->_type = MNAssetTypeGif;
            model->_thumbnail = [image.images.firstObject resizingToMaxPix:MAX(model.renderSize.width, model.renderSize.height)];
        } else {
            model->_type = MNAssetTypePhoto;
            model->_thumbnail = [image resizingToMaxPix:MAX(model.renderSize.width, model.renderSize.height)];
        }
        if (configuration && configuration.isAllowsDisplayFileSize) {
            NSData *imageData = [NSData dataWithImage:image];
            model->_fileSize = imageData ? imageData.length : 0;
        }
    } else if ([content isKindOfClass:NSString.class] || ([content isKindOfClass:NSURL.class] && ((NSURL *)content).isFileURL)) {
        NSString *videoPath = [content isKindOfClass:NSString.class] ? content : ((NSURL *)content).path;
        if (![NSFileManager.defaultManager fileExistsAtPath:videoPath]) return nil;
        UIImage *thumbnail = [MNAssetExporter exportThumbnailOfVideoAtPath:videoPath atSeconds:.1f maximumSize:model.renderSize];
        model->_thumbnail = thumbnail;
        model->_type = MNAssetTypeVideo;
        model->_duration = [MNAssetExporter exportDurationWithMediaAtPath:videoPath];
        model->_durationString = [NSDate timeStringWithInterval:@(model.duration)];
        if (configuration && configuration.isAllowsDisplayFileSize) {
            NSNumber *videoSize;
            NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
            [videoURL getResourceValue:&videoSize forKey:NSURLFileSizeKey error:nil];
            model->_fileSize = videoSize ? videoSize.longLongValue : 0;
        }
    } else if ([content isKindOfClass:NSClassFromString(@"PHLivePhoto")]) {
        model->_type = MNAssetTypeLivePhoto;
#if __has_include(<Photos/PHLivePhoto.h>)
        if (@available(iOS 9.1, *)) {
            NSURL *videoURL = [content valueForKey:@"videoURL"];
            NSURL *imageURL = [content valueForKey:@"imageURL"];
            if (!imageURL || !videoURL) return nil;
            model->_thumbnail = [[UIImage imageWithContentsOfFile:imageURL.path] resizingToMaxPix:MAX(model.renderSize.width, model.renderSize.height)];
            if (model->_thumbnail == nil) return nil;
            if (configuration && configuration.isAllowsDisplayFileSize) {
                NSArray<PHAssetResource *>*resources = [PHAssetResource assetResourcesForLivePhoto:model.content];
                long long fileSize = 0;
                for (PHAssetResource *resource in resources) {
                    id obj = [resource valueForKey:@"fileSize"];
                    if (obj) fileSize += [obj longLongValue];
                }
                model->_fileSize = fileSize;
            }
        }
#endif
    }
    model->_fileSizeString = model.fileSizeStringValue;
    return model;
}

- (void)cancelRequest {
    [MNAssetHelper cancelAssetRequest:self];
}

- (void)cancelDownload {
    [MNAssetHelper cancelAssetDownload:self];
}

#pragma mark - Setter
- (void)setSelected:(BOOL)selected {
    if (self.isTakeModel) return;
    _selected = selected;
    if (!selected) self.selectIndex = 0;
}

- (void)setEnabled:(BOOL)enabled {
    if (self.isTakeModel) return;
    _enabled = enabled;
}

#pragma mark - Change
- (void)updateStatus:(MNAssetStatus)status {
    _status = status;
    if (status == MNAssetStatusFailed) _progress = 0.f;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.statusChangeHandler) {
            self.statusChangeHandler(self);
        }
    });
}

- (void)updateSource:(MNAssetSourceType)source {
    _source = source;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.sourceChangeHandler) {
            self.sourceChangeHandler(self);
        }
    });
}

- (void)updateProgress:(double)progress {
    _progress = progress;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.progressChangeHandler) {
            self.progressChangeHandler(self);
        }
    });
}

- (void)updateThumbnail:(UIImage *)thumbnail {
    _thumbnail = thumbnail;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.thumbnailChangeHandler) {
            self.thumbnailChangeHandler(self);
        }
    });
}

- (void)updateFileSize:(long long)fileSize {
    _fileSize = fileSize;
    _fileSizeString = self.fileSizeStringValue;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.fileSizeChangeHandler) {
            self.fileSizeChangeHandler(self);
        }
    });
}

#pragma mark - Getter
- (NSString *)fileSizeStringValue {
    NSString *fileSize;
    long long dataLength = self.fileSize;
    if (dataLength >= 1024*1024/10) {
        fileSize = [NSString stringWithFormat:@"%.1fM",(double)dataLength/1024.f/1024.f];
    } else if (dataLength >= 1024) {
        fileSize = [NSString stringWithFormat:@"%.0fK",(double)dataLength/1024.f];
    } else {
        fileSize = [NSString stringWithFormat:@"%lldB", dataLength];
    }
    return fileSize;
}

#pragma mark - dealloc
- (void)dealloc {
    self.content = nil;
    self.statusChangeHandler = nil;
    self.sourceChangeHandler = nil;
    self.fileSizeChangeHandler = nil;
    self.progressChangeHandler = nil;
    self.thumbnailChangeHandler = nil;
    [self cancelRequest];
    [self cancelDownload];
}

@end
