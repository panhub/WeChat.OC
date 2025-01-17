//
//  WXWeatherRequest.m
//  WeChat
//
//  Created by Vincent on 2019/5/6.
//  Copyright © 2019 Vincent. All rights reserved.
//

#import "WXWeatherRequest.h"
#import "WXWeatherModel.h"

@interface WXWeatherRequest ()
@property (nonatomic, copy) NSString *city;
@property (nonatomic, copy) NSString *district;
@end

@implementation WXWeatherRequest
- (instancetype)initWithCity:(NSString *)city district:(NSString *)district {
    if (self = [super init]) {
        self.city = city;
        self.district = district;
        self.url = @"http://apicloud.mob.com/v1/weather/query";
        self.cachePolicy = MNURLCachePolicyNever;
    }
    return self;
}

- (void)loadData:(MNURLRequestStartCallback)startCallback completion:(MNURLRequestFinishCallback)finishCallback {
    self.query = @{@"key":MobAppKey, @"district":self.district, @"city":self.city};
    [super loadData:startCallback completion:finishCallback];
}

- (void)didSucceedWithResponseObject:(id)responseObject {
    [super didSucceedWithResponseObject:responseObject];
    NSArray *result = [NSDictionary arrayValueWithDictionary:responseObject forKey:@"result"];
    if (result.count > 0) {
        NSDictionary *dic = [result lastObject];
        WXWeatherModel *model = [WXWeatherModel modelWithDic:dic];
        [self.dataArray removeAllObjects];
        [self.dataArray addObject:model];
    }
}

@end
