//
//  MNAssetPreviewController.m
//  MNKit
//
//  Created by Vincent on 2019/9/11.
//  Copyright © 2019 XiaoSi. All rights reserved.
//

#import "MNAssetPreviewController.h"
#import "MNAsset.h"
#import "MNAssetSelectButton.h"
#import "MNAssetBrowseCell.h"
#import "MNAssetSelectView.h"

@interface MNAssetPreviewController ()<MNAssetSelectViewDelegate, MNAssetBrowseCellDelegate, UIGestureRecognizerDelegate>
@property (nonatomic) NSInteger currentDisplayIndex;
@property (nonatomic, strong) MNAssetSelectView *selectView;
@property (nonatomic, strong) MNAssetSelectButton *selectButton;
@property (nonatomic, getter=isStatusBarHidden) BOOL statusBarHidden;
@end

#define kAssetInteritemSpacing  15.f

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@implementation MNAssetPreviewController
- (instancetype)initWithAssets:(NSArray <MNAsset *>*)asset {
    if (self = [super init]) {
        self.assets = asset;
        self.allowsAutoPlaying = YES;
        self.currentDisplayIndex = NSIntegerMin;
        self.events = MNAssetPreviewEventNone;
        self.statusBarHidden = UIApplication.sharedApplication.isStatusBarHidden;
    }
    return self;
}

- (void)createView {
    [super createView];
    
    self.navigationBar.translucent = NO;
    self.navigationBar.shadowView.hidden = YES;
    self.navigationBar.backItemColor = UIColor.whiteColor;
    self.navigationBar.backgroundColor = UIColor.clearColor;
    self.navigationBar.backgroundImage = [MNBundle imageForResource:@"mask_top"];
    self.navigationBar.layer.contentsGravity = kCAGravityResizeAspectFill;
    self.navigationBar.clipsToBounds = YES;
    
    self.contentView.clipsToBounds = YES;
    self.contentView.backgroundColor = UIColor.blackColor;
    
    self.collectionView.frame = CGRectMake(-kAssetInteritemSpacing/2.f, 0.f, self.contentView.width_mn + kAssetInteritemSpacing, self.contentView.height_mn);
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.scrollsToTop = NO;
    self.collectionView.pagingEnabled = YES;
    self.collectionView.delaysContentTouches = NO;
    self.collectionView.canCancelContentTouches = YES;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    [self.collectionView registerClass:[MNAssetBrowseCell class]
       forCellWithReuseIdentifier:MNCollectionElementCellReuseIdentifier];
    [self.collectionView reloadData];
    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:NO];
    
    if (self.assets.count > 1) {
        MNAssetSelectView *selectView = [[MNAssetSelectView alloc] initWithFrame:CGRectMake(0.f, 0.f, self.contentView.width_mn, 100.f) assets:self.assets];
        selectView.height_mn += MN_TAB_SAFE_HEIGHT + MNAssetSelectBottomMinMargin;
        selectView.bottom_mn = self.contentView.height_mn;
        [self.contentView addSubview:selectView];
        self.selectView = selectView;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.contentView addGestureRecognizer:doubleTap];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTap:)];
    singleTap.delegate = self;
    singleTap.numberOfTapsRequired = 1;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.contentView addGestureRecognizer:singleTap];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:(self.navigationBar.bottom_mn <= 0.f) withAnimation:UIStatusBarAnimationFade];
    if (self.isFirstAppear) [self updateCurrentPageIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:self.isStatusBarHidden withAnimation:UIStatusBarAnimationFade];
    [[self cellForItemAtCurrentDisplayIndex] endDisplaying];
}

#pragma mark - UICollectionViewDelegate && UICollectionViewDataSource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.assets.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MNAssetBrowseCell *cell = (MNAssetBrowseCell *)[collectionView dequeueReusableCellWithReuseIdentifier:MNCollectionElementCellReuseIdentifier forIndexPath:indexPath];
    cell.delegate = self;
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(MNAssetBrowseCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    [cell didEndDisplaying];
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(MNAssetBrowseCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    cell.asset = self.assets[indexPath.item];
    [cell setPlayToolBarVisible:(self.navigationBar.top_mn >= 0.f) animated:NO];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (decelerate) return;
    [self scrollViewDidEndDecelerating:scrollView];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self updateCurrentPageIfNeeded];
}

#pragma mark - MNAssetBrowseCellDelegate
- (BOOL)assetBrowseCellShouldAutoPlaying:(MNAssetBrowseCell *)cell {
    return self.isAllowsAutoPlaying;
}

#pragma mark - 更新当前页
- (void)updateCurrentPageIfNeeded {
    NSInteger currentDisplayIndex = self.collectionView.contentOffset.x/self.collectionView.width_mn;
    if (currentDisplayIndex == self.currentDisplayIndex) return;
    self.currentDisplayIndex = currentDisplayIndex;
    [[self cellForItemAtCurrentDisplayIndex] didBeginDisplaying];
    if (self.selectButton) [self.selectButton updateAsset:self.assets[currentDisplayIndex]];
    if (self.selectView) self.selectView.selectIndex = currentDisplayIndex;
}

#pragma mark - Event
- (void)singleTap:(UITapGestureRecognizer *)recognizer {
    BOOL isStatusBarHidden = UIApplication.sharedApplication.isStatusBarHidden;
    [UIView animateWithDuration:UIApplication.sharedApplication.statusBarOrientationAnimationDuration animations:^{
        self.navigationBar.top_mn = isStatusBarHidden ? 0.f : -self.navigationBar.height_mn;
        if (self.selectView) self.selectView.alpha = isStatusBarHidden ? 1.f : 0.f;
        [UIApplication.sharedApplication setStatusBarHidden:!isStatusBarHidden animated:UIStatusBarAnimationFade];
    }];
    [[self cellForItemAtCurrentDisplayIndex] setPlayToolBarVisible:isStatusBarHidden animated:YES];
}

- (void)doubleTap:(UITapGestureRecognizer *)recognizer {
    MNAssetBrowseCell *cell = [self cellForItemAtCurrentDisplayIndex];
    if (cell.scrollView.zoomScale > 1.f) {
        [cell.scrollView setZoomScale:1.f animated:YES];
    } else {
        CGPoint touchPoint = [recognizer locationInView:cell.scrollView];
        CGFloat newZoomScale = cell.scrollView.maximumZoomScale;
        CGFloat xsize = cell.scrollView.width_mn/newZoomScale;
        CGFloat ysize = cell.scrollView.height_mn/newZoomScale;
        [cell.scrollView zoomToRect:CGRectMake(touchPoint.x - xsize/2.f, touchPoint.y - ysize/2.f, xsize, ysize) animated:YES];
    }
}

#pragma mark - MNAssetSelectViewDelegate
- (void)selectView:(MNAssetSelectView *)selectView didSelectItemAtIndex:(NSInteger)index {
    if (index == self.currentDisplayIndex) return;
    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:NO];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.1f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateCurrentPageIfNeeded];
    });
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return ![touch.view.superview isKindOfClass:UICollectionViewCell.class];
}

#pragma mark - MNNavigationBarDelegate
- (void)navigationBarDidCreateBarItem:(MNNavigationBar *)navigationBar {
    UIImageView *shadowView = [UIImageView imageViewWithFrame:navigationBar.bounds image:[MNBundle imageForResource:@"shadow_line_top"]];
    shadowView.userInteractionEnabled = NO;
    shadowView.contentMode = UIViewContentModeScaleToFill;
    [navigationBar insertSubview:shadowView atIndex:0];
}

- (UIView *)navigationBarShouldCreateRightBarItem {
    UIView *rightBarItem = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, 0.f, 25.f)];
    if (self.events & MNAssetPreviewEventSelect) {
        // 选择
        MNAssetSelectButton *selectButton = [[MNAssetSelectButton alloc] initWithFrame:CGRectMake(0.f, 0.f, 0.f, rightBarItem.height_mn)];
        selectButton.centerY_mn = rightBarItem.height_mn/2.f;
        selectButton.tag = MNAssetPreviewEventSelect;
        [selectButton addTarget:self action:@selector(navigationBarRightBarItemTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
        [rightBarItem addSubview:selectButton];
        self.selectButton = selectButton;
        rightBarItem.width_mn = selectButton.right_mn;
    }
    if (self.events & MNAssetPreviewEventDone) {
        // 确定
        UIButton *doneButton = [UIButton buttonWithFrame:CGRectZero image:nil title:@"确定" titleColor:UIColor.whiteColor titleFont:[UIFont systemFontOfSize:16.5f]];
        [doneButton sizeToFit];
        doneButton.height_mn = rightBarItem.height_mn;
        doneButton.left_mn = rightBarItem.width_mn + 15.f;
        doneButton.centerY_mn = rightBarItem.height_mn/2.f;
        doneButton.tag = MNAssetPreviewEventDone;
        [doneButton addTarget:self action:@selector(navigationBarRightBarItemTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
        [rightBarItem addSubview:doneButton];
        rightBarItem.width_mn = doneButton.right_mn + 15.f;
    }
    return rightBarItem;
}

- (void)navigationBarRightBarItemTouchUpInside:(UIControl *)rightItem {
    if ([self.delegate respondsToSelector:@selector(previewController:rightBarItemTouchUpInside:)]) {
        if (rightItem.tag != MNAssetPreviewEventSelect) {
            [[self cellForItemAtCurrentDisplayIndex] endDisplaying];
        }
        [self.delegate previewController:self rightBarItemTouchUpInside:rightItem];
        if (rightItem.tag == MNAssetPreviewEventSelect) {
            MNAsset *asset = self.assets[self.currentDisplayIndex];
            [kTransform(MNAssetSelectButton *, rightItem) updateAsset:asset];
        }
    }
}

#pragma mark - Getter
- (MNAssetBrowseCell *)cellForItemAtCurrentDisplayIndex {
    return (MNAssetBrowseCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:self.currentDisplayIndex inSection:0]];
}

#pragma mark - Super
- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (MNContentEdges)contentEdges {
    return MNContentEdgeNone;
}

- (UICollectionViewLayout *)collectionViewLayout {
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumLineSpacing = kAssetInteritemSpacing;
    layout.minimumInteritemSpacing = 0.f;
    layout.sectionInset = UIEdgeInsetsMake(0.f, kAssetInteritemSpacing/2.f, 0.f, kAssetInteritemSpacing/2.f);
    layout.headerReferenceSize = CGSizeZero;
    layout.footerReferenceSize = CGSizeZero;
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = self.contentView.size_mn;
    return layout;
}

- (void)dealloc {
    if (self.isCleanAssetWhenDealloc) {
        NSArray <MNAsset *>*result = [self.assets.copy filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.asset != nil"]];
        [result setValue:nil forKey:@"content"];
        [result makeObjectsPerformSelector:@selector(cancelRequest)];
    }
}

@end
#pragma clang diagnostic pop
