//
//  PHAsset+MNAssetResource.h
//  MNKit
//
//  Created by Vicent on 2020/11/10.
//

#if __has_include(<Photos/PHAssetResource.h>)
#import <Photos/Photos.h>

NS_ASSUME_NONNULL_BEGIN

@interface PHAsset (MNAssetResource)

/**
 资源大小
 */
@property (nonatomic, readonly) CGSize pixelSize;

/**
 是否是HEIF格式资源
 */
@property (nonatomic, readonly) BOOL isHEIF;

/**
 是否是GIF格式资源
 */
@property (nonatomic, readonly) BOOL isGIF;

@end

NS_ASSUME_NONNULL_END
#endif
