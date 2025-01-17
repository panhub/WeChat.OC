//
//  MNAssetPickController.m
//  MNKit
//
//  Created by Vincent on 2019/8/30.
//  Copyright © 2019 Vincent. All rights reserved.
//

#import "MNAssetPickController.h"
#import "MNAssetPickConfiguration.h"
#import "MNImageCropController.h"
#import "MNVideoTailorController.h"
#import "MNCameraController.h"
#import "MNAssetTouchController.h"
#import "MNAssetPreviewController.h"
#import "MNAlbumSelectControl.h"
#import "MNAssetToolBar.h"
#import "MNAlbumView.h"
#import "MNAssetHelper.h"
#import "MNAssetCollection.h"
#import "MNAssetCell.h"
#import "MNAssetBrowser.h"
#import <Photos/Photos.h>
#import "MNAuthenticator.h"

#ifdef NSFoundationVersionNumber_iOS_9_0
#import "MNAssetTouchController.h"
@interface MNAssetPickController ()<MNAssetCellDelegate, MNImageCropDelegate, MNAlbumViewDelegate, MNAssetToolDelegate, MNCameraControllerDelegate, MNAssetBrowseDelegate, MNAssetTouchDelegate, MNAssetPreviewDelegate, MNImageCropDelegate, MNVideoTailorDelegate, UIViewControllerPreviewingDelegate, PHPhotoLibraryChangeObserver>
#else
@interface MNAssetPickController ()<MNAssetCellDelegate, MNImageCropDelegate, MNAlbumViewDelegate, MNAssetToolDelegate, MNCameraControllerDelegate, MNAssetBrowseDelegate, MNAssetTouchDelegate, MNAssetPreviewDelegate, MNImageCropDelegate, MNVideoTailorDelegate, PHPhotoLibraryChangeObserver>
#endif
@property (nonatomic, strong) NSIndexPath *touchIndexPath;
@property (nonatomic, strong) MNAlbumView *albumView;
@property (nonatomic, strong) MNAssetCollection *collection;
@property (nonatomic, strong) MNAssetToolBar *assetToolBar;
@property (nonatomic, strong) MNAlbumSelectControl *albumToolBar;
@property (nonatomic, strong) MNAssetPickConfiguration *configuration;
@property (nonatomic, strong) NSMutableArray <MNAsset *>*selectedAssets;
@property (nonatomic, strong) NSMutableArray <MNAssetCollection *>*collections;
@end

@implementation MNAssetPickController
- (instancetype)init {
    return [self initWithConfiguration:[MNAssetPickConfiguration new]];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithConfiguration:[MNAssetPickConfiguration new]];
}
#pragma clang diagnostic pop

- (instancetype)initWithConfiguration:(MNAssetPickConfiguration *)configuration {
    if (self = [super init]) {
        self.configuration = configuration;
        self.collections = @[].mutableCopy;
        self.selectedAssets = @[].mutableCopy;
    }
    return self;
}

- (void)createView {
    [super createView];
    
    self.navigationBar.translucent = NO;
    self.navigationBar.shadowView.hidden = YES;
    self.navigationBar.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = UIColorWithSingleRGB(240.f);
    
    self.collectionView.frame = self.contentView.bounds;
    self.collectionView.scrollsToTop = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.backgroundColor = self.contentView.backgroundColor;
    [self.collectionView registerClass:[MNAssetCell class] forCellWithReuseIdentifier:MNCollectionElementCellReuseIdentifier];
    
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    
    UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0.f, layout.sectionInset.top, self.contentView.width_mn, self.contentView.height_mn - layout.sectionInset.top - layout.sectionInset.bottom)];
    backgroundView.userInteractionEnabled = YES;
    backgroundView.backgroundColor = self.contentView.backgroundColor;
    UIImageView *emptyView = [UIImageView imageViewWithFrame:CGRectMake(0.f, 0.f, (backgroundView.width_mn)/3.f, (backgroundView.width_mn)/3.f) image:[MNBundle imageForResource:@"empty_photo"]];
    emptyView.center_mn = backgroundView.bounds_center;
    [backgroundView addSubview:emptyView];
    [self.contentView insertSubview:backgroundView belowSubview:self.collectionView];
    
    if (self.configuration.isAllowsPickingAlbum) {
        MNAlbumView *albumView = [[MNAlbumView alloc] initWithFrame:backgroundView.frame];
        albumView.delegate = self;
        [self.contentView addSubview:albumView];
        self.albumView = albumView;
    }
    
    // 底部工具栏
    if (self.configuration.maxPickingCount > 1) {
        MNAssetToolBar *assetToolBar = [[MNAssetToolBar alloc] initWithFrame:CGRectMake(0.f, 0.f, self.view.width_mn, layout.sectionInset.bottom)];
        assetToolBar.delegate = self;
        assetToolBar.assets = self.selectedAssets;
        assetToolBar.bottom_mn = self.view.height_mn;
        assetToolBar.configuration = self.configuration;
        [self.view addSubview:assetToolBar];
        self.assetToolBar = assetToolBar;
        // 支持滑动选择
        if (self.configuration.isAllowsGlidePicking && self.configuration.isAllowsMultiplePickingPhoto && self.configuration.isAllowsMultiplePickingVideo && self.configuration.isAllowsMultiplePickingGif && self.configuration.isAllowsMultiplePickingLivePhoto) {
            self.collectionView.bounces = NO;
            UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
            panRecognizer.maximumNumberOfTouches = 1;
            [self.contentView addGestureRecognizer:panRecognizer];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // 监听相册变动代理
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    // 注册3DTouch
    if (self.configuration.isAllowsPreviewing) {
#ifdef __IPHONE_9_0
        if (@available(iOS 9.0, *)) {
            if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
                [self registerForPreviewingWithDelegate:self sourceView:self.collectionView];
            }
        }
#endif
    }
}

- (void)loadData {
    __weak typeof(self) weakself = self;
    self.navigationController.view.userInteractionEnabled = NO;
    [MNAuthenticator requestAlbumAuthorizationStatusWithHandler:^(BOOL allowed) {
        if (allowed) {
            [weakself.contentView showActivityDialog:@"加载中"];
            [MNAssetHelper fetchAssetCollectionsWithConfiguration:self.configuration completion:^(NSArray<MNAssetCollection *>*dataArray) {
                [weakself.collections removeAllObjects];
                [weakself.collections addObjectsFromArray:dataArray];
                weakself.albumToolBar.hidden = dataArray.count <= 0;
                weakself.albumToolBar.selectEnabled = dataArray.count > 1;
                weakself.collectionView.hidden = dataArray.count <= 0;
                if (dataArray.count) weakself.collection = dataArray.firstObject;
                if (weakself.albumView) weakself.albumView.dataArray = weakself.collections;
                [weakself.contentView closeDialog];
                weakself.navigationController.view.userInteractionEnabled = YES;
            }];
        } else {
            weakself.collectionView.hidden = YES;
            weakself.navigationController.view.userInteractionEnabled = YES;
            [[MNAlertView alertViewWithTitle:@"权限不足" message:@"请前往“设置-隐私-照片”打开应用的相册访问权限" handler:nil ensureButtonTitle:@"确定" otherButtonTitles:nil] showInView:weakself.navigationController.view];
        }
    }];
}

- (void)reloadData {
    // 标注处理
    if (self.configuration.showPickingNumber) {
        [self.selectedAssets enumerateObjectsUsingBlock:^(MNAsset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.selectIndex = idx + 1;
        }];
    }
    // 判断是否超过限制
    if (self.selectedAssets.count >= self.configuration.maxPickingCount) {
        // 达到最大限制, 不可再选
        NSArray <MNAsset *>*assets = [self.collection.assets filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.selected == NO && self.enabled == YES"]];
        [assets setValue:@(NO) forKey:@"enabled"];
    } else {
        // 可以继续再选择
        NSArray <MNAsset *>*assets = [self.collection.assets filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.selected == NO && self.enabled == NO"]];
        [assets setValue:@(YES) forKey:@"enabled"];
        // 再进行类型限制
        if (self.selectedAssets.count > 0 && !self.configuration.isAllowsMixPicking) {
            MNAssetType type = self.selectedAssets.firstObject.type;
            if (type == MNAssetTypeVideo) {
                NSArray <MNAsset *>*assets = [self.collection.assets filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.selected == NO && self.type != %ld", type]];
                [assets setValue:@(NO) forKey:@"enabled"];
            } else {
                NSArray <MNAsset *>*assets = [self.collection.assets filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.selected == NO && self.type == %ld", MNAssetTypeVideo]];
                [assets setValue:@(NO) forKey:@"enabled"];
            }
        }
    }
    // 更新视图
    if (self.assetToolBar) [self.assetToolBar updateSubviews];
    [self.collectionView reloadData];
}

#pragma mark - Event
- (void)pan:(UIPanGestureRecognizer *)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
        {
            self.touchIndexPath = nil;
        } break;
        case UIGestureRecognizerStateChanged:
        {
            if (self.collectionView.isHidden) return;
            CGPoint location = [recognizer locationInView:self.contentView];
            CGPoint point = [self.contentView convertPoint:location toView:self.collectionView];
            NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];
            if (!indexPath || (self.touchIndexPath && indexPath.item == self.touchIndexPath.item) || indexPath.item >= self.collection.assets.count) return;
            self.touchIndexPath = indexPath;
            MNAsset *asset = self.collection.assets[indexPath.item];
            if (!asset.isEnabled || asset.isTakeModel) return;
            [self didSelectAsset:asset];
        } break;
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:
        {
            self.touchIndexPath = nil;
        } break;
        default:
            break;
    }
}

#pragma mark - UICollectionViewDelegate & UICollectionViewDataSource
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.collection.assets.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MNAssetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:MNCollectionElementCellReuseIdentifier forIndexPath:indexPath];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(MNAssetCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    [cell didEndDisplaying];
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(MNAssetCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    cell.asset = self.collection.assets[indexPath.item];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= self.collection.assets.count) return;
    MNAsset *model = self.collection.assets[indexPath.item];
    if (!model.isEnabled || model.status == MNAssetStatusDownloading) return;
    if (model.isTakeModel) {
        // 拍摄
        MNCameraController *vc = [MNCameraController new];
        vc.delegate = self;
        vc.configuration = self.configuration;
        [self.navigationController pushViewController:vc animated:YES];
    } else if (self.configuration.maxPickingCount == 1 || (model.type == MNAssetTypePhoto && self.configuration.allowsMultiplePickingPhoto == NO) || (model.type == MNAssetTypeVideo && self.configuration.allowsMultiplePickingVideo == NO) || (model.type == MNAssetTypeGif && self.configuration.allowsMultiplePickingGif == NO) || (model.type == MNAssetTypeLivePhoto && self.configuration.allowsMultiplePickingLivePhoto == NO)) {
        if (self.configuration.isAllowsPreviewing) {
            // 预览
            MNAssetPreviewController *vc = [[MNAssetPreviewController alloc] initWithAssets:@[model]];
            vc.delegate = self;
            vc.allowsAutoPlaying = YES;
            vc.cleanAssetWhenDealloc = YES;
            vc .events = MNAssetPreviewEventDone;
            [self.navigationController pushViewController:vc animated:YES];
        } else if (model.type == MNAssetTypePhoto && self.configuration.isAllowsEditing) {
            // 图片裁剪
            [self cropImageAsset:model removed:YES];
        } else if (model.type == MNAssetTypeVideo && self.configuration.isAllowsEditing) {
            // 视频裁剪 不判断时长是因为导入时不符合时长的资源已隐藏
            [self tailorVideoAsset:model];
        } else {
            // 确认选择
            [self didFinishPickingAssets:@[model]];
        }
    } else if (self.configuration.isAllowsPreviewing) {
        // 预览
        NSArray <MNAsset *>*assets = [self.collection.assets filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.isTakeModel == NO"]];
        if (assets.count <= 0) return;
        MNAssetBrowser *browser = [MNAssetBrowser new];
        browser.assets = assets;
        browser.delegate = self;
        browser.allowsAutoPlaying = YES;
        browser.cleanAssetWhenDealloc = YES;
        browser.backgroundColor = UIColor.blackColor;
        [browser presentInView:self.contentView fromIndex:[assets indexOfObject:model] animated:YES completion:nil];
    } else {
        // 确认选择
        [self didSelectAsset:model];
    }
}

#pragma mark - 裁剪图片
- (void)cropImageAsset:(MNAsset *)asset removed:(BOOL)isRemoved {
    __weak typeof(self) weakself = self;
    [self.navigationController.view showActivityDialog:@"请稍后"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [MNAssetHelper requestAssetContent:asset configuration:nil completion:^(MNAsset *obj) {
            UIImage *image = obj.content;
            if (isRemoved && obj.asset) obj.content = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakself.navigationController.view closeDialogWithCompletionHandler:^{
                    if (image) {
                        MNImageCropController *v = [[MNImageCropController alloc] initWithImage:image];
                        v.delegate = weakself;
                        v.cropScale = weakself.configuration.cropScale;
                        [weakself.navigationController pushViewController:v animated:YES];
                    } else {
                        [[MNAlertView alertViewWithTitle:@"获取图片失败" message:@"请检查网络后重试" handler:nil ensureButtonTitle:@"确定" otherButtonTitles:nil] showInView:weakself.navigationController.view];
                    }
                }];
            });
        }];
    });
}

#pragma mark - 裁剪视频
- (void)tailorVideoAsset:(MNAsset *)asset {
    __weak typeof(self) weakself = self;
    [self.navigationController.view showActivityDialog:@"请稍后"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [MNAssetHelper requestAssetContent:asset configuration:nil completion:^(MNAsset *obj) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakself.navigationController.view closeDialogWithCompletionHandler:^{
                    if (obj.content) {
                        MNVideoTailorController *v = [[MNVideoTailorController alloc] initWithVideoPath:obj.content];
                        v.delegate = weakself;
                        v.outputPath = weakself.configuration.exportURL.path;
                        v.allowsResizeSize = weakself.configuration.allowsResizeVideoSize;
                        v.minTailorDuration = weakself.configuration.minExportDuration;
                        v.maxTailorDuration = weakself.configuration.maxExportDuration;
                        [weakself.navigationController pushViewController:v animated:YES];
                    } else {
                        [[MNAlertView alertViewWithTitle:@"获取视频失败" message:@"请检查网络后重试" handler:nil ensureButtonTitle:@"确定" otherButtonTitles:nil] showInView:weakself.navigationController.view];
                    }
                }];
            });
        }];
    });
}

#pragma mark - 选择内容完成
- (void)didFinishPickingAssets:(NSArray <MNAsset *>*)assets {
    __weak typeof(self) weakself = self;
    self.navigationController.view.userInteractionEnabled = NO;
    [MNAssetHelper requestContentWithAssets:assets configuration:self.configuration progress:^(NSInteger total, NSInteger index) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg = [NSString stringWithFormat:@"正在下载%@/%@", @(index + 1), @(total)];
            if (![weakself.navigationController.view updateDialogMessage:msg]) {
                [weakself.navigationController.view showActivityDialog:msg];
            }
        });
    } completion:^(NSArray<MNAsset *> * _Nullable models) {
        // 判断是否有下载失败项<通常为下载iCloud文件失败>
        NSMutableArray <MNAsset *>*succAssets = assets.mutableCopy;
        NSArray <MNAsset *>*failAssets = [succAssets filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.status != %@", @(MNAssetStatusCompleted)]];
        if (failAssets.count) [succAssets removeObjectsInArray:failAssets];
        dispatch_async(dispatch_get_main_queue(), ^{
            weakself.navigationController.view.userInteractionEnabled = YES;
            [weakself.navigationController.view closeDialogWithCompletionHandler:^{
                if (failAssets.count <= 0) {
                    // 获取资源成功
                    [weakself finishPickingAssets:succAssets];
                } else if (!succAssets || succAssets.count <= 0 || succAssets.count < weakself.configuration.minPickingCount) {
                    // 仅有一个资源且获取失败或者成功的数量小于最小限制
                    [[MNAlertView alertViewWithTitle:@"iCloud资源下载失败" message:@"请检查网络后重试" handler:nil ensureButtonTitle:@"确定" otherButtonTitles:nil] showInView:weakself.navigationController.view];
                } else {
                    // 有获取失败项
                    [[MNAlertView alertViewWithTitle:@"iCloud资源下载失败" message:nil handler:^(MNAlertView *alertView, NSInteger buttonIndex) {
                        if (buttonIndex == alertView.ensureButtonIndex) {
                            [weakself finishPickingAssets:succAssets];
                        }
                    } ensureButtonTitle:@"确定" otherButtonTitles:@"取消", nil] showInView:weakself.navigationController.view];
                }
            }];
        });
    }];
}

- (void)finishPickingAssets:(NSArray <MNAsset *>*)assets {
    NSArray <MNAsset *>*array = (assets && assets.count > 0) ? assets.copy : nil;
    if ([self.configuration.delegate respondsToSelector:@selector(assetPicker:didFinishPickingAssets:)]) {
        [self.configuration.delegate assetPicker:kTransform(MNAssetPicker *, self.navigationController) didFinishPickingAssets:array];
    }
}

#pragma mark - MNAssetBrowseDelegate
- (void)assetBrowserWillPresent:(MNAssetBrowser *)assetBrowser {
    [UIView animateWithDuration:MNAssetBrowsePresentAnimationDuration animations:^{
        self.navigationBar.alpha = self.assetToolBar.alpha = 0.f;
    }];
}

- (void)assetBrowserWillDismiss:(MNAssetBrowser *)assetBrowser {
    [UIView animateWithDuration:MNAssetBrowseDismissAnimationDuration animations:^{
        self.navigationBar.alpha = self.assetToolBar.alpha = 1.f;
    }];
}

#pragma mark - MNAssetCellDelegate
- (MNAssetPickConfiguration *)assetCellShouldUsingConfiguration {
    return self.configuration;
}

#pragma mark - Common Delegate
- (void)didSelectAsset:(MNAsset *)model {
    // 这里把 maxPickingCount == 1 情况, 因为不会到这里
    if (model.isSelected) {
        model.selected = NO;
        [self.selectedAssets removeObject:model];
    } else {
        model.selected = YES;
        [self.selectedAssets addObject:model];
    }
    // 刷新数据
    [self reloadData];
}

#pragma mark - MNAlbumViewDelegate
- (void)albumView:(MNAlbumView *)albumView didSelectAlbum:(MNAssetCollection *)album {
    if (album && album != self.collection) self.collection = album;
    self.albumToolBar.selected = NO;
    [albumView dismiss];
}

#pragma mark - MNAlbumSelectEvent
- (void)albumToolBarClicked:(MNAlbumSelectControl *)toolBar {
    if (self.collections.count <= 1) return;
    toolBar.selected = !toolBar.selected;
    if (toolBar.selected) {
        [self.albumView show];
    } else {
        [self.albumView dismiss];
    }
}

#pragma mark - MNAssetToolDelegate
- (void)assetToolBarLeftBarItemClicked:(MNAssetToolBar *)toolBar {
    MNAssetPreviewController *vc = [[MNAssetPreviewController alloc] initWithAssets:self.selectedAssets];
    vc.delegate = self;
    vc.events = MNAssetPreviewEventDone|MNAssetPreviewEventSelect;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)assetToolBarClearButtonClicked:(MNAssetToolBar *)toolBar {
    [[MNAlertView alertViewWithTitle:nil message:@"确定清空所选内容?" handler:^(MNAlertView *alertView, NSInteger buttonIndex) {
        if (buttonIndex != alertView.ensureButtonIndex) return;
        [self.selectedAssets removeAllObjects];
        [self.collections enumerateObjectsUsingBlock:^(MNAssetCollection * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj.assets setValue:@(NO) forKey:@"selected"];
            [obj.assets setValue:@(YES) forKey:@"enabled"];
        }];
        [self.collectionView reloadData];
        [toolBar updateSubviews];
        if (self.albumToolBar.selected) [self.albumView reloadData];
    } ensureButtonTitle:@"确定" otherButtonTitles:@"取消", nil] showInView:self.navigationController.view];
}

- (void)assetToolBarRightBarItemClicked:(MNAssetToolBar *)toolBar {
    /// 判断是否允许退出
    NSUInteger minCount = self.configuration.minPickingCount;
    if (minCount > 0 && self.selectedAssets.count < minCount) {
        [[MNAlertView alertViewWithTitle:nil message:[NSString stringWithFormat:@"请至少选择%@项素材", @(minCount).stringValue] handler:nil ensureButtonTitle:@"确定" otherButtonTitles:nil] show];
        return;
    }
    [self didFinishPickingAssets:self.selectedAssets.copy];
}

#pragma mark - MNCameraControllerDelegate
- (void)cameraControllerDidCancel:(MNCameraController *)cameraController {
    [cameraController.navigationController popViewControllerAnimated:UIApplication.sharedApplication.applicationState == UIApplicationStateActive];
}

- (void)cameraController:(MNCameraController *)cameraController didFinishWithContents:(id)contents {
    __weak typeof(cameraController) vc = cameraController;
    [vc.view showActivityDialog:@"请稍后"];
    if (self.configuration.isAllowsWritToAlbum) {
        [MNAssetHelper writeAssets:@[contents] toAlbum:self.collection.collection.localizedTitle completion:^(NSArray<NSString *> * _Nullable identifiers, NSError * _Nullable error) {
            if (error || identifiers.count <= 0) {
                [vc.view showInfoDialog:([contents isKindOfClass:UIImage.class] ? @"图片保存失败" : @"文件保存失败")];
            } else {
                [vc.view closeDialogWithCompletionHandler:^{
                    [vc.navigationController popViewControllerAnimated:YES];
                }];
            }
        }];
    } else {
        [self insertContents:contents completion:^(BOOL result) {
            if (result) {
                [vc.view closeDialogWithCompletionHandler:^{
                    [vc.navigationController popViewControllerAnimated:YES];
                }];
            } else {
                [vc.view showInfoDialog:@"操作失败"];
            }
        }];
    }
}

- (void)insertContents:(id)contents completion:(void(^)(BOOL))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        id content = contents;
        if ([content isKindOfClass:UIImage.class]) content = ((UIImage *)content).compressImage;
        MNAsset *asset = [MNAsset assetWithContent:content configuration:self.configuration];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!asset) {
                if (completion) completion(NO);
                return;
            }
            if (self.configuration.isSortAscending) {
                [self.collection addAsset:asset];
            } else {
                [self.collection insertAssetAtFront:asset];
            }
            self.collection = self.collection;
            if (completion) completion(YES);
        });
    });
}

#pragma mark - MNImageCropDelegate
- (void)imageCropControllerDidCancel:(MNImageCropController *)controller {
    [controller.navigationController popViewControllerAnimated:YES];
}

- (void)imageCropController:(MNImageCropController *)controller didCroppingImage:(UIImage *)image {
    if (!self.configuration.isOriginalExporting && self.configuration.isAllowsOptimizeExporting) image = image.compressImage;
    MNAsset *asset = [MNAsset assetWithContent:image configuration:self.configuration];
    if (!asset) {
        [controller.view showInfoDialog:@"图片裁剪失败"];
        return;
    }
    [self didFinishPickingAssets:@[asset]];
}

#pragma mark - MNVideoTailorDelegate
- (void)videoTailorControllerDidCancel:(MNVideoTailorController *)tailorController {
    [tailorController.navigationController popViewControllerAnimated:YES];
}

- (void)videoTailorController:(MNVideoTailorController *)tailorController didTailoringVideoAtPath:(NSString *)videoPath {
    MNAsset *asset = [MNAsset assetWithContent:videoPath configuration:self.configuration];
    if (!asset) {
        [tailorController.view showInfoDialog:@"视频裁剪失败"];
        return;
    }
    [self didFinishPickingAssets:@[asset]];
}

#pragma mark - MNAssetPreviewDelegate
- (void)previewController:(MNAssetPreviewController *)previewController rightBarItemTouchUpInside:(UIControl *)sender {
    if (sender.tag == MNAssetPreviewEventDone) {
        NSArray <MNAsset *>*assets = previewController.assets;
        if (assets.count == 1) {
            MNAsset *asset = assets.firstObject;
            if (asset.type == MNAssetTypePhoto && self.configuration.isAllowsEditing) {
                // 裁剪图片
                [self cropImageAsset:asset removed:NO];
            } else if (asset.type == MNAssetTypeVideo && self.configuration.isAllowsEditing) {
                // 裁剪视频 不判断时长是因为导入时不符合时长的资源已隐藏
                [self tailorVideoAsset:asset];
            } else {
                // 完成选择
                [self didFinishPickingAssets:@[asset]];
            }
        } else {
            // 完成选择
            [self didFinishPickingAssets:assets];
        }
    } else {
        // 资源选择状态更新
        [self didSelectAsset:previewController.assets[previewController.currentDisplayIndex]];
    }
}

#pragma mark - MNAssetTouchDelegate
- (void)touchController:(MNAssetTouchController *)touchController rightBarItemTouchUpInside:(UIControl *)sender {
    if (sender.tag == MNAssetTouchEventSelect) {
        [self didSelectAsset:touchController.asset];
    } else {
        MNAsset *asset = touchController.asset;
        if (asset.type == MNAssetTypePhoto && self.configuration.isAllowsEditing) {
            // 裁剪图片
            [self cropImageAsset:asset removed:NO];
        } else if (asset.type == MNAssetTypeVideo && self.configuration.isAllowsEditing) {
            // 裁剪视频 不判断时长是因为导入时不符合时长的资源已隐藏
            [self tailorVideoAsset:asset];
        } else {
            // 结束选择
            [self didFinishPickingAssets:@[asset]];
        }
    }
}

#pragma mark - UIViewControllerPreviewingDelegate
#ifdef NSFoundationVersionNumber_iOS_9_0
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
- (UIViewController *)previewingContext:(id <UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    if (self.collection.assets.count <= 0) return nil;
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
    if (!indexPath) return nil;
    MNAsset *model = self.collection.assets[indexPath.item];
    if (model.isTakeModel || !model.thumbnail || model.status == MNAssetStatusDownloading) return nil;
    UIPreviewAction *action = [UIPreviewAction actionWithTitle:@"取消" style:UIPreviewActionStyleDefault handler:^(UIPreviewAction *action, UIViewController *previewViewController) {
        NSLog(@"===取消===");
    }];
    MNAssetTouchController *vc = [MNAssetTouchController new];
    vc.asset = model;
    vc.actions = @[action];
    vc.cleanAssetWhenDealloc = YES;
    vc.events = MNAssetTouchEventDone;
    if (self.configuration.maxPickingCount > 1) {
        vc.events |= MNAssetTouchEventSelect;
    }
    return vc;
}

- (void)previewingContext:(id <UIViewControllerPreviewing>)previewingContext commitViewController:(MNAssetTouchController *)viewController {
    viewController.delegate = self;
    viewController.state = MNAssetTouchStateWeight;
    [self showViewController:viewController sender:self];
}
#pragma clang diagnostic pop
#endif

#pragma mark - PHPhotoLibraryChangeObserver
- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.navigationController.view.userInteractionEnabled == NO || self.collectionView.isDragging) return;
        self.navigationController.view.userInteractionEnabled = NO;
        __block BOOL shouldReloadData = NO;
        [self.collectionView showActivityDialog:@"请稍后"];
        NSMutableArray <MNAsset *>*selectedAssets = @[].mutableCopy;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self.collections.copy enumerateObjectsUsingBlock:^(MNAssetCollection * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (!obj.result || !obj.collection) return;
                PHFetchResultChangeDetails *details = [changeInstance changeDetailsForFetchResult:obj.result];
                if (!details || (details.removedObjects.count + details.insertedObjects.count <= 0)) return;
                shouldReloadData = YES;
                NSArray <MNAsset *>*selecteds = [obj.assets filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.selected == YES"]];
                [selectedAssets addObjectsFromArray:selecteds];
                [self.selectedAssets removeObjectsInArray:selecteds];
                MNAssetCollection *collection = [MNAssetHelper fetchAssetCollection:obj.collection configuration:self.configuration];
                [self.collections replaceObjectAtIndex:idx withObject:collection];
                [selectedAssets.copy enumerateObjectsUsingBlock:^(MNAsset * _Nonnull ast, NSUInteger idx, BOOL * _Nonnull stop) {
                    NSArray <MNAsset *>*result = [collection.assets.copy filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.asset.localIdentifier == %@", ast.asset.localIdentifier]];
                    if (result.count) {
                        MNAsset *asset = result.firstObject;
                        asset.selected = YES;
                        asset.selectIndex = ast.selectIndex;
                        [selectedAssets removeObject:ast];
                        [self.selectedAssets addObject:asset];
                    }
                }];
                if (obj == self.collection) self->_collection = collection;
            }];
            // 对选择资源排序
            if (shouldReloadData && self.configuration.showPickingNumber && self.selectedAssets.count) {
                NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"selectIndex" ascending:YES];
                NSArray <MNAsset *>*result = [self.selectedAssets sortedArrayUsingDescriptors:@[descriptor]];
                [self.selectedAssets removeAllObjects];
                [self.selectedAssets addObjectsFromArray:result];
            }
            // 主线程刷新UI
            dispatch_async(dispatch_get_main_queue(), ^{
                if (shouldReloadData) {
                    [self reloadData];
                    if (self.albumView) [self.albumView reloadData];
                }
                [self.collectionView closeDialog];
                self.navigationController.view.userInteractionEnabled = YES;
            });
        });
    });
}

#pragma mark - MNNavigationBarDelegate
- (BOOL)navigationBarShouldDrawBackBarItem {
    return NO;
}

- (void)navigationBarDidCreateBarItem:(MNNavigationBar *)navigationBar {
    UIImageView *blurEffect = [UIImageView imageViewWithFrame:navigationBar.bounds image:[UIImage imageWithColor:UIColorWithAlpha([UIColor whiteColor], .97f) size:navigationBar.size_mn]];
    blurEffect.userInteractionEnabled = YES;
    [navigationBar insertSubview:blurEffect atIndex:0];
    MNAlbumSelectControl *albumToolBar = [MNAlbumSelectControl new];
    albumToolBar.hidden = YES;
    albumToolBar.center_mn = navigationBar.titleView.bounds_center;
    albumToolBar.touchInset = UIEdgeInsetsMake(-10.f, 0.f, -10.f, 0.f);
    [albumToolBar addTarget:self action:@selector(albumToolBarClicked:) forControlEvents:UIControlEventTouchUpInside];
    [navigationBar.titleView addSubview:albumToolBar];
    self.albumToolBar = albumToolBar;
}

- (UIView *)navigationBarShouldCreateRightBarItem {
    UIButton *rightBarItem = [UIButton buttonWithFrame:CGRectMake(0.f, 0.f, 40.f, 30.f) image:nil title:@"取消" titleColor:[UIColor darkTextColor] titleFont:UIFontRegular(17.f)];
    [rightBarItem addTarget:self action:@selector(navigationBarRightBarItemTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
    return rightBarItem;
}

- (void)navigationBarRightBarItemTouchUpInside:(UIView *)rightBarItem {
    if ([self.configuration.delegate respondsToSelector:@selector(assetPickerDidCancel:)]) {
        [self.configuration.delegate assetPickerDidCancel:(MNAssetPicker *)self.navigationController];
    } else if (self.configuration.isAllowsAutoDismiss && self.navigationController.presentingViewController) {
        [self.navigationController dismissViewControllerAnimated:(UIApplication.sharedApplication.applicationState == UIApplicationStateActive) completion:nil];
    }
}

#pragma mark - Setter
- (void)setCollection:(MNAssetCollection *)collection {
    /// 处理不可选
    [collection.assets setValue:@(YES) forKey:@"enabled"];
    if (self.configuration.maxPickingCount > 1 && collection.assets.count > 0) {
        if (self.selectedAssets.count >= self.configuration.maxPickingCount) {
            NSArray <MNAsset *>*assets = [collection.assets filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.isSelected == NO"]];
            [assets setValue:@(NO) forKey:@"enabled"];
        } else if (self.selectedAssets.count > 0 && !self.configuration.isAllowsMixPicking) {
            MNAssetType type = self.selectedAssets.firstObject.type;
            if (type == MNAssetTypeVideo) {
                NSArray <MNAsset *>*assets = [collection.assets filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.isSelected == NO && self.type != %ld", type]];
                [assets setValue:@(NO) forKey:@"enabled"];
            } else {
                NSArray <MNAsset *>*assets = [collection.assets filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.isSelected == NO && self.type == %ld", MNAssetTypeVideo]];
                [assets setValue:@(NO) forKey:@"enabled"];
            }
        }
    }
    /// 更新数据
    _collection = collection;
    _albumToolBar.title = collection.title;
    [self.collectionView reloadData];
    self.collectionView.hidden = collection.assets.count <= 0;
    if (collection.assets.count > 0 && self.configuration.isSortAscending) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:collection.assets.count - 1 inSection:0];
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionTop
                                            animated:NO];
    }
}

#pragma mark - Super
- (MNListViewType)listViewType {
    return MNListViewTypeGrid;
}

- (MNContentEdges)contentEdges {
    return MNContentEdgeNone;
}

- (BOOL)isRootViewController {
    return NO;
}

- (UICollectionViewLayout *)collectionViewLayout {
    CGFloat wh = (self.contentView.width_mn - (self.configuration.numberOfColumns - 1)*5.f)/self.configuration.numberOfColumns;
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumLineSpacing = 5.f;
    layout.minimumInteritemSpacing = 5.f;
    layout.sectionInset = UIEdgeInsetsZero;
    layout.headerReferenceSize = CGSizeZero;
    layout.footerReferenceSize = CGSizeZero;
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.itemSize = CGSizeMake(floor(wh), floor(wh));
    CGFloat bottom = self.configuration.maxPickingCount > 1 ? MN_TAB_SAFE_HEIGHT + 50.f : MN_TAB_SAFE_HEIGHT;
    layout.sectionInset = UIEdgeInsetsMake(self.navigationBar.height_mn, 0.f, bottom, 0.f);
    return layout;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}

#pragma mark - didReceiveMemoryWarning
- (void)didReceiveMemoryWarning {
    self.view.userInteractionEnabled = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.collections.copy enumerateObjectsUsingBlock:^(MNAssetCollection * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSArray <MNAsset *>*assets = [obj.assets filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.isSelected == NO"]];
            if (assets && assets.count) [obj removeAssets:assets];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadList];
            self.view.userInteractionEnabled = YES;
        });
    });
}

#pragma mark - dealloc
- (void)dealloc {
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

@end
