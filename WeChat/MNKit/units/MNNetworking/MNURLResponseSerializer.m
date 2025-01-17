//
//  MNURLResponseSerializer.m
//  MNKit
//
//  Created by Vincent on 2018/11/7.
//  Copyright © 2018年 小斯. All rights reserved.
//

#import "MNURLResponseSerializer.h"

NSString * const MNURLResponseSerializationErrorDomain = @"com.mn.response.serialization.error.domain";
NSString * const MNURLResponseFailingErrorKey = @"com.mn.response.failing.error.key";
NSString * const MNURLResponseSerializationErrorKey = @"com.mn.response.serialization.error.key";

/**可接受的响应码*/
NSIndexSet *_Nonnull MNURLResponseAcceptableStatus (void) {
    static NSIndexSet *acceptable_status_set;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        acceptable_status_set = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    });
    return acceptable_status_set;
}

/**错误的合并,填充*/
static NSError * MNErrorWithUnderlyingError(NSError *error, NSError *underlyingError) {
    if (!error) {
        return underlyingError;
    }
    if (!underlyingError || error.userInfo[NSUnderlyingErrorKey]) {
        return error;
    }
    NSMutableDictionary *mutableUserInfo = [error.userInfo mutableCopy];
    mutableUserInfo[NSUnderlyingErrorKey] = underlyingError;
    return [[NSError alloc] initWithDomain:error.domain code:error.code userInfo:mutableUserInfo];
}

/**判断错误是否是指定的错误类型*/
static BOOL MNErrorOrUnderlyingErrorHasCodeInDomain(NSError *error, NSInteger code, NSString *domain) {
    //判断错误域名和传过来的域名是否一致，错误code是否一致
    if ([error.domain isEqualToString:domain] && error.code == code) {
        return YES;
    } else if (error.userInfo[NSUnderlyingErrorKey]) {
        //如果userInfo的NSUnderlyingErrorKey有值, 则再判断一次。
        return MNErrorOrUnderlyingErrorHasCodeInDomain(error.userInfo[NSUnderlyingErrorKey], code, domain);
    }
    return NO;
}

@implementation MNURLResponseSerializer

+ (instancetype)serializer {
    return [[MNURLResponseSerializer alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    self.JSONOptions = kNilOptions;
    self.stringEncoding = NSUTF8StringEncoding;
    self.serializationType = MNURLSerializationTypeJSON;
    self.acceptableStatus = MNURLResponseAcceptableStatus();
    return self;
}

#pragma mark - 数据解析
- (id)objectWithResponse:(NSURLResponse *)response
                    data:(NSData *)data
                   error:(NSError *__autoreleasing *)error
{
    //先判断是不是可接受类型和可接受code
    if (![self validateResponse:(NSHTTPURLResponse *)response data:data error:error]) {
        //error为空, 或者错误为指定类型
        //验证出错的情况下error为空说明数据为nil 或 [response MIMEType] 为nil
        //MNURLResponseSerializationErrorDomain 说明响应码或数据类型不被接受
        if (!error || MNErrorOrUnderlyingErrorHasCodeInDomain(*error, NSURLErrorCannotDecodeContentData, MNURLResponseSerializationErrorDomain)) {
            return nil;
        }
    }
    if (self.serializationType == MNURLSerializationTypeJSON) {
        return [self JSONObjectWithData:data error:error];
    } else if (self.serializationType == MNURLSerializationTypeString) {
        return [self StringObjectWithData:data error:error];
    } else if (self.serializationType == MNURLSerializationTypePlist) {
        return [self PropertyListObjectWithData:data error:error];
    }  else if (self.serializationType == MNURLSerializationTypeXML) {
        return [self XMLObjectWithData:data];
    }
    return nil;
}

#pragma mark JSON解析
- (id)JSONObjectWithData:(NSData *)data error:(NSError *__autoreleasing *)error
{
    id responseObject = nil;
    NSError *serializationError = nil;
    //如果数据为空
    BOOL isEmpty = [data isEqualToData:[NSData dataWithBytes:" " length:1]];
    //不空则去json解析
    if (data.length > 0 && !isEmpty) {
        responseObject = [NSJSONSerialization JSONObjectWithData:data
                                                         options:self.JSONOptions
                                                           error:&serializationError];
    } else {
        serializationError = [NSError errorWithDomain:MNURLResponseSerializationErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"data is empty"}];
    }
    if (!responseObject || serializationError) {
        //拿着json解析的error去填充错误信息
        if (error) {
            *error = MNErrorWithUnderlyingError(serializationError, *error);
        }
        return nil;
    }
    return responseObject;
}

#pragma mark String解析
- (id)StringObjectWithData:(NSData *)data error:(NSError *__autoreleasing *)error
{
    NSString *responseObject = nil;
    NSError *serializationError = nil;
    BOOL isEmpty = [data isEqualToData:[NSData dataWithBytes:" " length:1]];
    if (data.length > 0 && !isEmpty) {
        responseObject = [[NSString alloc] initWithData:data encoding:self.stringEncoding];
        if (responseObject.length <= 0) {
            responseObject = nil;
            serializationError = [NSError errorWithDomain:MNURLResponseSerializationErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:@{NSLocalizedDescriptionKey:@"serialization data error"}];
        }
    } else {
        serializationError = [NSError errorWithDomain:MNURLResponseSerializationErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:@{NSLocalizedDescriptionKey:@"data is empty"}];
    }
    if (serializationError && error) {
        *error = MNErrorWithUnderlyingError(serializationError, *error);
    }
    return responseObject;
}

#pragma mark XML解析
- (id)XMLObjectWithData:(NSData *)data
{
    if (!data) return nil;
    //返回解析器, 数据根据具体要求自行解析
    return [[NSXMLParser alloc] initWithData:data];
}

#pragma mark PropertyList解析
- (id)PropertyListObjectWithData:(NSData *)data error:(NSError *__autoreleasing *)error
{
    id responseObject = nil;
    NSError *serializationError = nil;
    BOOL isEmpty = [data isEqualToData:[NSData dataWithBytes:" " length:1]];
    if (data.length > 0 && !isEmpty) {
        responseObject = [NSPropertyListSerialization propertyListWithData:data
                                                                   options:kNilOptions
                                                                    format:NULL
                                                                     error:&serializationError];
    } else {
        serializationError = [NSError errorWithDomain:MNURLResponseSerializationErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"data is empty"}];
    }
    if (!responseObject || serializationError) {
        if (error) {
            *error = MNErrorWithUnderlyingError(serializationError, *error);
        }
        return nil;
    }
    return responseObject;
}

#pragma mark - 验证数据是否匹配
- (BOOL)validateResponse:(NSHTTPURLResponse *)response
                    data:(NSData *)data
                   error:(NSError * __autoreleasing *)error
{
    //response是否合法标识
    BOOL responseIsValid = YES;
    //验证的error
    NSError *validationError = nil;
    //如果存在且是NSHTTPURLResponse
    if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSSet <NSString *>*acceptableContentTypes = [self acceptableContentTypes];
        //判断自己能接受的数据类型和response的数据类型是否匹配，
        //如果不匹配数据类型，如果不匹配response，而且响应类型不为空或者数据长度不为0
        if (acceptableContentTypes && ![acceptableContentTypes containsObject:[response MIMEType]] &&
            !([response MIMEType] == nil && [data length] <= 0)) {
            //说明解析数据肯定是失败的, 这时候要把解析错误信息放到error里。
            //如果数据长度大于0，而且有响应url
            if ([data length] > 0 && [response URL]) {
                NSMutableDictionary *mutableUserInfo = [@{
                                                          NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"request failed: unacceptable content-type: %@", @"MNNetworking", nil), [response MIMEType]],
                                                          NSURLErrorFailingURLErrorKey:[response URL],
                                                          MNURLResponseFailingErrorKey: response,
                                                          } mutableCopy];
                if (data) {
                    mutableUserInfo[MNURLResponseSerializationErrorKey] = data;
                }
                
                validationError = MNErrorWithUnderlyingError([NSError errorWithDomain:MNURLResponseSerializationErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:mutableUserInfo], validationError);
            }
            
            responseIsValid = NO;
        }
        //判断自己可接受的状态码
        //如果和response的状态码不匹配，则进入if块
        if (self.acceptableStatus && ![self.acceptableStatus containsIndex:(NSUInteger)response.statusCode] && [response URL]) {
            NSMutableDictionary *mutableUserInfo = [@{
                                                      NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"request failed: %@ (%ld)", @"MNNetworking", nil), [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], (long)response.statusCode],
                                                      NSURLErrorFailingURLErrorKey:[response URL],
                                                      MNURLResponseFailingErrorKey: response,
                                                      } mutableCopy];
            
            if (data) {
                mutableUserInfo[MNURLResponseSerializationErrorKey] = data;
            }
            
            validationError = MNErrorWithUnderlyingError([NSError errorWithDomain:MNURLResponseSerializationErrorDomain code:NSURLErrorBadServerResponse userInfo:mutableUserInfo], validationError);
            
            responseIsValid = NO;
        }
    }
    
    /**错误指针存在, 且验证数据错误, 为指针赋值*/
    if (error && !responseIsValid) {
        *error = validationError;
    }
    
    return responseIsValid;
}

#pragma mark - 可接受数据类型
- (NSSet <NSString *>*)acceptableContentTypes {
    if (!_acceptableContentTypes || _acceptableContentTypes.count <= 0) {
        switch (self.serializationType) {
            case MNURLSerializationTypeJSON:
            {
                _acceptableContentTypes = [NSSet setWithObjects:@"text/html", @"application/json", @"text/json", @"text/javascript", nil];
            } break;
            case MNURLSerializationTypeString:
            {
                _acceptableContentTypes = [NSSet setWithObjects:@"text/html", @"application/xml", @"text/plain", nil];
            } break;
            case MNURLSerializationTypeXML:
            {
                _acceptableContentTypes = [NSSet setWithObjects:@"application/xml", @"text/xml", nil];
            } break;
            case MNURLSerializationTypePlist:
            {
                _acceptableContentTypes = [NSSet setWithObjects:@"application/x-plist", nil];
            } break;
            default:
                break;
        }
    }
    return _acceptableContentTypes;
}

#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone {
    MNURLResponseSerializer *serializer = [[self.class allocWithZone:zone] init];
    serializer.stringEncoding = self.stringEncoding;
    serializer.serializationType = self.serializationType;
    serializer.JSONOptions = self.JSONOptions;
    serializer.acceptableStatus = self.acceptableStatus;
    serializer.acceptableContentTypes = self.acceptableContentTypes;
    return serializer;
}

@end
