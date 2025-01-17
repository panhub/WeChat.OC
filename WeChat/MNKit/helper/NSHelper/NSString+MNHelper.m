//
//  NSString+MNHelper.m
//  MNKit
//
//  Created by Vincent on 2017/11/14.
//  Copyright © 2017年 小斯. All rights reserved.
//

#import "NSString+MNHelper.h"
#import "NSString+MNCoding.h"
#if __has_include(<CoreLocation/CLLocation.h>)
#import <CoreLocation/CLLocation.h>
#endif

@implementation NSString (MNEmptying)
#pragma mark - 是否为空字符串
+ (BOOL)isEmptyString:(NSString *)string {
    /** !string 等价于 (string == nil || string == NULL)*/
    if (!string ||
        [string length] <= 0 ||
        [string isKindOfClass:[NSNull class]] ||
        [string isEqual:[NSNull null]] ||
        [string isEqualToString:@""] ||
        [string isEqualToString:@"(null)"] ||
        [[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]==0) {
        return YES;
    }
    return NO;
}

BOOL NSStringIsEmpty(NSString *string) {
    return [NSString isEmptyString:string];
}

#pragma mark - 修改空字符串
+ (void)replacingEmptyString:(NSString **)string {
    [self replacingEmptyString:string withString:@""];
}

void NSStringReplacingEmpty (NSString **string) {
    [NSString replacingEmptyString:string];
}

#pragma mark - 设置默认字符串
+ (void)replacingEmptyString:(NSString **)string withString:(NSString *)replaceString {
    if ([self isEmptyString:*string]) {
        *string = replaceString;
    }
}

void NSStringReplacingEmptyWith (NSString **string, NSString *replaceString) {
    [NSString replacingEmptyString:string withString:replaceString];
}

#pragma mark - 返回不为空的字符串
+ (NSString *)replacingEmptyCharacters:(NSString *)string {
    return [self replacingEmptyCharacters:string withCharacters:@""];
}

+ (NSString *)replacingEmptyCharacters:(NSString *)aCharacters withCharacters:(NSString *)bCharacters {
    return [self isEmptyString:aCharacters] ? bCharacters : aCharacters;
}

#pragma mark - 编辑字符串
- (NSString *)stringByInsertString:(NSString *)aString atIndex:(NSUInteger)loc {
    if (!aString || aString.length <= 0) return self;
    NSMutableString *string = self.mutableCopy;
    if (self.length <= loc) {
        [string appendString:aString];
    } else {
        [string insertString:aString atIndex:loc];
    }
    return string.copy;
}

- (NSString *)stringByInsertString:(NSString *)aString afterString:(NSString *)bString {
    if (aString.length <= 0 || bString.length <= 0) return self;
    NSRange range = [self rangeOfString:bString];
    if (range.location == NSNotFound) return self;
    return [self stringByInsertString:aString atIndex:NSMaxRange(range)];
}

- (NSString *)stringByDeleteCharactersInRange:(NSRange)range {
    if (range.location == NSNotFound || self.length < range.location) return self;
    NSMutableString *string = self.mutableCopy;
    [string deleteCharactersInRange:range];
    return string.copy;
}

- (NSString *)stringByAppendString:(NSString *)aString {
    if (!aString || aString.length <= 0) return self;
    NSMutableString *string = self.mutableCopy;
    [string appendString:aString];
    return string.copy;
}

@end


@implementation NSString (MNSize)
#pragma mark - 获取字符串的size
+ (CGSize)stringSize:(NSString *)string fontSize:(CGFloat)fontSize {
    if (fontSize <= .0f || [self isEmptyString:string]) return CGSizeZero;
    return [string sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:fontSize]}];
}

- (CGSize)sizeWithFontSize:(CGFloat)fontSize {
    return [NSString stringSize:self fontSize:fontSize];
}

CGSize NSStringSizeWithFontSize (NSString *string, CGFloat fontSize) {
    return [NSString stringSize:string fontSize:fontSize];
}

+ (CGSize)stringSize:(NSString *)string font:(UIFont *)font {
    if (!font || [self isEmptyString:string]) return CGSizeZero;
    return [string sizeWithAttributes:@{NSFontAttributeName: font}];
}

- (CGSize)sizeWithFont:(UIFont *)font {
    return [NSString stringSize:self font:font];
}

CGSize NSStringSizeWithFont (NSString *string, UIFont *font) {
    return [NSString stringSize:string font:font];
}

#pragma mark - 获取字符串边界大小
+ (CGSize)boundingSizeWithString:(NSString *)string
                            size:(CGSize)size
                      attributes:(NSDictionary *)attributes {
    if (CGSizeEqualToSize(size, CGSizeZero) || NSStringIsEmpty(string)) return CGSizeZero;
    if (!attributes) attributes = @{NSFontAttributeName:[UIFont systemFontOfSize:15.f]};
    return [string boundingRectWithSize:size
                                options:NSStringDrawingUsesFontLeading|NSStringDrawingUsesLineFragmentOrigin
                             attributes:attributes
                                context:nil].size;
}

- (CGSize)boundingSize:(CGSize)size attributes:(NSDictionary *)attributes {
    return [NSString boundingSizeWithString:self size:size attributes:attributes];
}

CGSize NSStringBoundingSize (NSString *string, CGSize size, NSDictionary *attributes) {
    return [NSString boundingSizeWithString:string size:size attributes:attributes];
}

@end


@implementation NSString (MNHelper)
#pragma mark - 唯一字符串
+ (NSString *)identifier {
    //设备UUID
    NSString *identifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    //当前时空UUID
    NSString *uuidString = [[NSUUID UUID] UUIDString];
    //拼接文件名
    NSString *fileName = [NSString stringWithFormat:@"%@-%@-%@-%@", identifier, uuidString, [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970]*1000], @(__COUNTER__)];
    return fileName.md5String32;
}

#pragma mark - 自身长度
- (NSRange)rangeOfAll {
    return NSMakeRange(0, self.length);
}

#pragma mark - 图片
- (UIImage *)image {
    return [UIImage imageNamed:self];
}

#pragma mark - 富文本
- (NSAttributedString *)attributedString {
    return [[NSAttributedString alloc] initWithString:self];
}

#pragma mark - 是否数字字符串
- (BOOL)isNumberString {
    NSScanner *scanner = [[NSScanner alloc] initWithString:self];
    scanner.charactersToBeSkipped = NSCharacterSet.new;
    return ([scanner scanInt:NULL] && [scanner isAtEnd]);
}

+ (BOOL)isNumberString:(NSString *)string {
    if ([self isEmptyString:string]) return NO;
    return string.isNumberString;
}

#pragma mark - 倒序字符串
- (NSString *)reversedString {
    NSMutableString *string = @"".mutableCopy;
    for (int i = 0; i < self.length; i ++) {
        [string insertString:[self substringWithRange:NSMakeRange(i, 1)] atIndex:0];
    }
    return string.copy;
}

#pragma mark - 获取字符串
NSString * NSStringFromNumber (NSNumber *number) {
    if (!number) return @"";
    return [NSString stringWithFormat:@"%@",number];
}

#if __has_include(<CoreLocation/CLLocation.h>)
NSString * NSStringFromCoordinate2D(CLLocationCoordinate2D coordinate) {
    if (!CLLocationCoordinate2DIsValid(coordinate)) return @"";
    NSString *latitude = [[NSNumber numberWithDouble:coordinate.latitude] stringValue];
    NSString *longitude = [[NSNumber numberWithDouble:coordinate.longitude] stringValue];
    NSArray <NSString *>*components = @[[@"latitude:" stringByAppendingString:latitude], [@"longitude:" stringByAppendingString:longitude]];
    return [NSString stringWithFormat:@"[%@]", [components componentsJoinedByString:@" , "]];
}

- (CLLocationCoordinate2D)coordinate2DValue {
    if (![self hasPrefix:@"["] || ![self hasSuffix:@"]"]) return kCLLocationCoordinate2DInvalid;
    NSString *string = [[self stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
    NSArray <NSString *>*components = [string componentsSeparatedByString:@" , "];
    if (components.count != 2) return kCLLocationCoordinate2DInvalid;
    NSString *latitude = components.firstObject;
    NSString *longitude = components.lastObject;
    if (![latitude hasPrefix:@"latitude:"] || ![longitude hasPrefix:@"longitude:"]) return kCLLocationCoordinate2DInvalid;
    return CLLocationCoordinate2DMake([[latitude stringByReplacingOccurrencesOfString:@"latitude:" withString:@""] doubleValue], [[longitude stringByReplacingOccurrencesOfString:@"longitude:" withString:@""] doubleValue]);
}

#endif
#pragma mark - UUID
+ (NSString *)UUIDString {
    /*
     理论上某一时空下是唯一的;
     比如在当前这一秒,全世界产生的UUID都是不一样的;
     当然同一台设备产生的UUID也是不一样的!
     */
    //[[NSUUID UUID] UUIDString]
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    CFStringRef stringRef = CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);
    NSString *uuidString = (__bridge_transfer NSString *) stringRef;
    return uuidString;
}

#pragma mark - 语言本地化处理
- (NSString *)localizedString {
    return NSLocalizedString(self, @"_localized_");
}

+ (NSString *)localizedString:(NSString *)string {
    return NSLocalizedString(string, @"_localized_");
}

#pragma mark - 生成随机汉字
+ (NSString *)chineseWithLength:(NSUInteger)length {
    if (length <= 0) return @"";
    NSMutableString *result =@"".mutableCopy;
    for (int idx = 0; idx < length; idx++) {
        NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        NSInteger H = 0xA1 + arc4random()%(0xFE - 0xA1 + 1);
        NSInteger L = 0xB0 + arc4random()%(0xF7 - 0xB0 + 1);
        NSInteger count = (H << 8) + L;
        NSData *data = [NSData dataWithBytes:&count length:2];
        NSString *string = [[NSString alloc] initWithData:data encoding:encoding];
        [result appendString:string];
    }
    return result.copy;
}

#pragma mark - 分割字符串为字典
- (NSDictionary <NSString *, NSString *>*)componentsBySeparatedString:(NSString *)separated {
    return [self componentsBy:@"=" separated:separated];
}

- (NSDictionary *)componentsBy:(NSString *)byString separated:(NSString *)separated {
    if (byString.length <= 0 || separated.length <= 0) return nil;
    NSMutableDictionary <NSString *, NSString *>*dic = @{}.mutableCopy;
    [[self componentsSeparatedByString:separated] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSArray <NSString *>*kv = [obj componentsSeparatedByString:byString];
        if (kv.count == 1) {
            [dic setObject:@"" forKey:kv.firstObject];
        } else if (kv.count == 2) {
            [dic setObject:kv.lastObject forKey:kv.firstObject];
        } else if (kv.count > 2) {
            NSMutableArray <NSString *>*tempArray = kv.mutableCopy;
            [tempArray removeObjectAtIndex:0];
            [dic setObject:([tempArray componentsJoinedByString:byString] ? : @"") forKey:kv.firstObject];
        }
    }];
    return dic.count ? dic.copy : nil;
}

+ (BOOL)evaluateEmail:(NSString *)email {
    if (email.length <= 0) return NO;
    NSString *regex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    return [emailTest evaluateWithObject:email];
}

- (NSArray <NSString *>*)matchSubstringUseingExpressions:(NSArray <NSString *>*)expressions {
    if (self.length <= 0 || expressions.count <= 0) return nil;
    NSMutableArray <NSString *>*resultArray = @[].mutableCopy;
    [expressions enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSError *error;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:obj
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:&error];
        if (regex && !error) {
            NSArray <NSTextCheckingResult *>*allMatches = [regex matchesInString:self options:kNilOptions range:NSMakeRange(0, self.length)];
            if (allMatches.count > 0) {
                [allMatches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull r, NSUInteger i, BOOL * _Nonnull s) {
                    NSString *sub = [self substringWithRange:r.range];
                    if (![resultArray containsObject:sub]) [resultArray addObject:sub];
                }];
            }
        }
    }];
    return resultArray.count > 0 ? resultArray.copy : nil;
}

+ (NSArray <NSString *>*)matchString:(NSString *)string useingExpressions:(NSArray <NSString *>*)expressions {
    if ([self isEmptyString:string]) return nil;
    return [string matchSubstringUseingExpressions:expressions];
}

@end
