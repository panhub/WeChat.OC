//
//  MNEmojiKeyboard.m
//  MNKit
//
//  Created by Vincent on 2019/1/31.
//  Copyright © 2019年 小斯. All rights reserved.
//

#import "MNEmojiKeyboard.h"
#import "MNScrollView.h"
#import "MNEmojiInputView.h"
#import "MNEmojiPacketView.h"

@interface MNEmojiKeyboard ()<MNEmojiInputViewDelegate, MNPageControlDelegate, MNEmojiPacketViewDelegate, UIInputViewAudioFeedback, MNEmojiPacketViewDataSource, MNEmojiInputViewDataSource>
@property (nonatomic, strong) MNPageControl *pageControl;
@property (nonatomic, strong) MNEmojiInputView *inputView;
@property (nonatomic, strong) MNEmojiPacketView *packetView;
@property (nonatomic, strong) NSArray <MNEmojiPacket *>*emojiPackets;
@property (nonatomic, strong) MNEmojiKeyboardConfiguration *configuration;
@end

@implementation MNEmojiKeyboard
#pragma mark - Instance
+ (MNEmojiKeyboard *)keyboard {
    return [[MNEmojiKeyboard alloc] initWithKeyboardHeight:(MN_TAB_SAFE_HEIGHT + 260.f)];
}

- (instancetype)init {
    return [self initWithKeyboardHeight:(MN_TAB_SAFE_HEIGHT + 260.f)];
}

- (instancetype)initWithKeyboardHeight:(CGFloat)height {
    CGRect frame = UIScreen.mainScreen.bounds;
    frame.size.height = MAX(height, MN_TAB_SAFE_HEIGHT + 150.f);
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = self.configuration.backgroundColor;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(emojiUpdateNotification:) name:MNEmojiUpdateNotificationName object:nil];
    }
    return self;
}

- (BOOL)createView {
    
    MNEmojiPacketView *packetView = [[MNEmojiPacketView alloc] initWithConfiguration:self.configuration];
    if (self.configuration.style == MNEmojiKeyboardStyleRegular) {
        packetView.bottom_mn = self.height_mn;
        packetView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
    } else {
        packetView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
    }
    packetView.delegate = self;
    packetView.dataSource = self;
    [self addSubview:packetView];
    self.packetView = packetView;
    
    MNEmojiInputView *inputView = [[MNEmojiInputView alloc] initWithFrame:CGRectMake(0.f, 0.f, self.width_mn, 0.f) configuration:self.configuration];
    if (self.configuration.style == MNEmojiKeyboardStyleRegular) {
        inputView.height_mn = self.configuration.isAllowsUseEmojiPackets ? packetView.top_mn : self.height_mn;
        inputView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
    } else {
        if (self.configuration.isAllowsUseEmojiPackets) {
            inputView.top_mn = packetView.bottom_mn;
            inputView.height_mn = self.height_mn - packetView.bottom_mn;
        } else {
            inputView.height_mn = self.height_mn;
        }
        inputView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
    }
    inputView.delegate = self;
    inputView.dataSource = self;
    [self addSubview:inputView];
    self.inputView = inputView;
    
    if (self.configuration.style == MNEmojiKeyboardStyleRegular) {
        MNPageControl *pageControl = [[MNPageControl alloc] initWithFrame:CGRectMake(0.f, 0.f, self.width_mn, self.configuration.pageIndicatorHeight)];
        pageControl.delegate = self;
        pageControl.pageSize = CGSizeMake(7.f, 7.f);
        pageControl.pageOffset = UIOffsetMake(0.f, (pageControl.height_mn - 7.f)*-1.f);
        pageControl.pageInterval = 10.f;
        pageControl.direction = MNPageControlDirectionHorizontal;
        pageControl.touchInset = UIEdgeInsetsMake(-5.f, 0.f, 0.f, 0.f);
        pageControl.pageTouchInset = UIEdgeInsetsMake(-5.f, -5.f, -5.f, -5.f);
        pageControl.pageIndicatorTintColor = self.configuration.pageIndicatorColor;
        pageControl.currentPageIndicatorTintColor = self.configuration.currentPageIndicatorColor;
        pageControl.bottom_mn = self.configuration.isAllowsUseEmojiPackets ? packetView.top_mn : (self.height_mn - MN_TAB_SAFE_HEIGHT);
        pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
        [self addSubview:pageControl];
        self.pageControl = pageControl;
        
        inputView.contentInset = UIEdgeInsetsMake(0.f, 0.f, (self.configuration.isAllowsUseEmojiPackets ? pageControl.height_mn : (self.height_mn - pageControl.top_mn)), 0.f);
    }
    
    return YES;
}

#pragma mark - DidMoveToSuperview
- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    if (!self.inputView && [self createView]) {
        [self.inputView reloadData];
        [self.packetView reloadData];
    }
}

#pragma mark - MNEmojiInputViewDelegate & MNEmojiInputViewDataSource
- (void)emojiInputViewDidDisplayEmojiView:(MNEmojiView *)emojiView {
    self.pageControl.hidden = emojiView.numberOfPages <= 1;
    self.pageControl.numberOfPages = emojiView.numberOfPages;
    self.pageControl.currentPageIndex = emojiView.currentPageIndex;
    [self.packetView selectPacketOfIndex:emojiView.index];
}

- (void)emojiInputViewDidScrollToPageOfIndex:(NSUInteger)pageIndex {
    self.pageControl.currentPageIndex = pageIndex;
}

- (void)emojiInputViewEmojiButtonTouchUpInside:(MNEmoji *)emoji {
    if (emoji.type == MNEmojiTypeFavorites) {
        if ([self.delegate respondsToSelector:@selector(emojiKeyboardFavoritesButtonTouchUpInside:)]) {
            [self.delegate emojiKeyboardFavoritesButtonTouchUpInside:self];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(emojiKeyboard:emojiButtonTouchUpInside:)]) {
            [[UIDevice currentDevice] playInputClick];
            [self.delegate emojiKeyboard:self emojiButtonTouchUpInside:emoji];
        }
    }
}

- (void)emojiDeleteButtonTouchUpInside {
    if ([self.delegate respondsToSelector:@selector(emojiKeyboardDeleteButtonTouchUpInside:)]) {
        [[UIDevice currentDevice] playInputClick];
        [self.delegate emojiKeyboardDeleteButtonTouchUpInside:self];
    }
}

- (NSArray <MNEmojiPacket *>*)emojiPacketsOfInputView {
    return self.emojiPackets;
}

#pragma mark - MNEmojiPacketViewDelegate & MNEmojiPacketViewDataSource
- (void)emojiPacketViewDidSelectPacketOfIndex:(NSUInteger)index {
    [self.inputView displayPageOfIndex:index];
}

- (void)emojiReturnButtonTouchUpInside {
    if ([self.delegate respondsToSelector:@selector(emojiKeyboardReturnButtonTouchUpInside:)]) {
        [[UIDevice currentDevice] playInputClick];
        [self.delegate emojiKeyboardReturnButtonTouchUpInside:self];
    }
}

- (void)emojiPacketAddButtonTouchUpInside {
    if ([self.delegate respondsToSelector:@selector(emojiKeyboardPacketButtonTouchUpInside:)]) {
        [self.delegate emojiKeyboardPacketButtonTouchUpInside:self];
    }
}

- (NSArray <MNEmojiPacket *>*)emojiPacketsOfPacketView {
    return self.emojiPackets;
}

#pragma mark - MNPageControlDelegate
- (void)pageControl:(MNPageControl *)pageControl didSelectPageOfIndex:(NSUInteger)index {
    [self.inputView displayCurrentPageOfIndex:index];
}

#pragma mark - UIInputViewAudioFeedback<键盘音支持>
- (BOOL)enableInputClicksWhenVisible {
    return self.configuration.isAllowsSoundWhenInputClicks;
}

#pragma mark - Notification
- (void)emojiUpdateNotification:(NSNotification *)notify {
    if (!_inputView || _emojiPackets.count <= 0) return;
    [self.inputView reloadEmojis];
}

#pragma mark - Getter
- (MNEmojiKeyboardConfiguration *)configuration {
    if (!_configuration) {
        _configuration = MNEmojiKeyboardConfiguration.new;
    }
    return _configuration;
}

- (NSArray<MNEmojiPacket *>*)emojiPackets {
    if (!_emojiPackets) {
        _emojiPackets = MNEmojiManager.defaultManager.packets.copy;
    }
    return _emojiPackets;
}

#pragma mark - dealloc
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end
