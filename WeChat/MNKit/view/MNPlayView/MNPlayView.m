//
//  MNPlayView.m
//  MNKit
//
//  Created by Vincent on 2018/10/12.
//  Copyright © 2018年 小斯. All rights reserved.
//

#import "MNPlayView.h"
#import "UIGestureRecognizer+MNHelper.h"
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, MNPlayViewState) {
    MNPlayViewStateNormal = 0,
    MNPlayViewStateBrightness,
    MNPlayViewStateVolume,
    MNPlayViewStateProgress
};

typedef NS_ENUM(NSUInteger, MNPlayViewDirection) {
    MNPlayViewDirectionNone = 0,
    MNPlayViewDirectionVertical,
    MNPlayViewDirectionHorizontal
};

@interface MNPlayView()
@property (nonatomic, assign) CGFloat value;
@property (nonatomic, assign) MNPlayViewState state;
@property (nonatomic, assign) MNPlayViewDirection direction;
@property (nonatomic, assign) CGFloat verticalReference;
@property (nonatomic, assign) CGFloat horizontalReference;
@property (nonatomic, strong) UIImageView *coverView;
@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@end

CGFloat const kPanDistanceKey = 30.f;
@implementation MNPlayView
+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (void)initialized {
    [self reset];
    _verticalReference = self.height_mn/3.f*2.f;
    _horizontalReference = self.width_mn/4.f*3.f;
}

- (instancetype)init {
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        
        [self initialized];
    
        self.layer.contentsGravity = kCAGravityResizeAspect;
        self.layer.backgroundColor = UIColor.blackColor.CGColor;
        
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        
        UIImageView *coverView = [[UIImageView alloc] initWithFrame:self.bounds];
        coverView.hidden = YES;
        coverView.clipsToBounds = YES;
        coverView.userInteractionEnabled = NO;
        coverView.contentMode = UIViewContentModeScaleAspectFit;
        coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self addSubview:coverView];
        self.coverView = coverView;
        
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] init];
        //tapGestureRecognizer.delegate = self;
        tapGestureRecognizer.numberOfTapsRequired = 1;
        [tapGestureRecognizer addTarget:self action:@selector(handTapEvent)];
        [self addGestureRecognizer:tapGestureRecognizer];
        self.tapGestureRecognizer = tapGestureRecognizer;
        
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc]init];
        //panGestureRecognizer.delegate = self;
        panGestureRecognizer.maximumNumberOfTouches = 1;
        [panGestureRecognizer addTarget:self action:@selector(handPanEvent:)];
        [self addGestureRecognizer:panGestureRecognizer];
        self.panGestureRecognizer = panGestureRecognizer;
    }
    return self;
}

- (void)handTapEvent {
    if ([_delegate respondsToSelector:@selector(playViewDidClicked:)]) {
        [_delegate playViewDidClicked:self];
    }
}

- (void)handPanEvent:(UIPanGestureRecognizer *)panRecognizer {
    switch (panRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        {
            [self reset];
        } break;
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [panRecognizer translationInView:panRecognizer.view];
            if (_direction == MNPlayViewDirectionNone) {
                if (fabs(translation.x) >= kPanDistanceKey) {
                    _direction = MNPlayViewDirectionHorizontal;
                    if ([_delegate respondsToSelector:@selector(playViewShouldChangeProgress)]) {
                        //获取进度
                        _state = MNPlayViewStateProgress;
                        _value = [_delegate playViewShouldChangeProgress];
                    }
                    [panRecognizer setTranslation:CGPointZero inView:panRecognizer.view];
                } else if (fabs(translation.y) >= kPanDistanceKey) {
                    _direction = MNPlayViewDirectionVertical;
                    CGPoint location = [panRecognizer locationInView:panRecognizer.view];
                    if (location.x >= panRecognizer.view.bounds.size.width/2.f) {
                        //亮度
                        _state = MNPlayViewStateBrightness;
                        _value = [UIScreen mainScreen].brightness;
                    } else {
                        //音量
                        _state = MNPlayViewStateVolume;
                        _value = [AVAudioSession sharedInstance].outputVolume;
                    }
                    [panRecognizer setTranslation:CGPointZero inView:panRecognizer.view];
                }
            } else {
                if (_state == MNPlayViewStateProgress) {
                    _value += translation.x/_horizontalReference;
                    _value = MIN(MAX(_value, 0.f), 1.f);
                    [_delegate playViewDidChangeProgress:_value];
                } else {
                    _value += -translation.y/_verticalReference;
                    _value = MIN(MAX(_value, 0.f), 1.f);
                    if (_state == MNPlayViewStateBrightness) {
                        [[UIScreen mainScreen] setBrightness:_value];
                    } else {
                        [[UISlider volumeSlider] setValue:_value];
                        [[UISlider volumeSlider] sendActionsForControlEvents:UIControlEventTouchUpInside];
                    }
                }
                [panRecognizer setTranslation:CGPointZero inView:panRecognizer.view];
            }
        } break;
        case UIGestureRecognizerStateEnded:
        {
            if ([_delegate respondsToSelector:@selector(playViewDidEndInteracting:)]) {
                [_delegate playViewDidEndInteracting:self];
            }
            [self reset];
        } break;
        default:
        {
            [self reset];
        } break;
    }
}

- (void)layoutSubviews {
    _horizontalReference = self.width_mn/4.f*3.f;
    _verticalReference = self.height_mn/3.f*2.f;
}

- (void)reset {
    _value = 0.f;
    _state = MNPlayViewStateNormal;
    _direction = MNPlayViewDirectionNone;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    self.layer.backgroundColor = backgroundColor.CGColor;
}

@end
