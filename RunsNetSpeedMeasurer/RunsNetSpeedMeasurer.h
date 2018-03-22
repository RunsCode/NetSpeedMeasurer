//
//  RunsNetSpeedMeasurer.h
//  RunsNetSpeedMeasurer
//
//  Created by runs on 2018/3/16.
//  Learning from Vladislav Dugnist
//  Copyright © 2018年 Olacio. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __LP64__ || (TARGET_OS_EMBEDDED && !TARGET_OS_IPHONE) || TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
typedef long RLong;
typedef unsigned long RULong;
#else
typedef long long RLong;
typedef unsigned long long RULong;
#endif

typedef NS_ENUM(NSUInteger, RunsNetConnectionType) {
    RunsNetConnectionType_WiFi = 0,
    RunsNetConnectionType_WWAN = 1,
};

NS_ASSUME_NONNULL_BEGIN
@class RunsNetMeasurerResult;
typedef void(^RunsNetworkSpeedAttributeCallback)(RunsNetMeasurerResult *result);

@protocol ISpeedMeasurerProtocol;
@protocol RunsNetSpeedMeasurerDelegate <NSObject>
- (void)measurer:(id<ISpeedMeasurerProtocol>)measurer didCompletedByInterval:(RunsNetMeasurerResult *)result;
@end

@protocol ISpeedMeasurerProtocol <NSObject>
@property (nonatomic, assign) NSUInteger accuracyLevel;//精度等级 1~5
@property (nonatomic, assign) NSTimeInterval measurerInterval;
@property (nonatomic, weak) id<RunsNetSpeedMeasurerDelegate> delegate;//Block和Delegate 二选一, Block优先级更高.
@property (nonatomic, strong) RunsNetworkSpeedAttributeCallback measurerBlock;//Block和Delegate 二选一, Block优先级更高.
- (instancetype)initWithAccuracyLevel:(NSUInteger)accuracyLevel interval:(NSTimeInterval)interval;
- (void)execute;
- (void)shutdown;
@end

@interface RunsNetFragmentation : NSObject
@property (nonatomic, assign) RunsNetConnectionType connectionType;
@property (nonatomic, assign) u_int32_t inputBytesCount;
@property (nonatomic, assign) u_int32_t outputBytesCount;
@property (nonatomic) NSTimeInterval beginTimestamp;
@property (nonatomic) NSTimeInterval endTimestamp;
+ (NSString *)maxValueInputKeyPath;
+ (NSString *)minValueInputKeyPath;
+ (NSString *)avgValueInputKeyPath;
+ (NSString *)maxValueOutputKeyPath;
+ (NSString *)minValueOutputKeyPath;
+ (NSString *)avgValueOutputKeyPath;
+ (NSString *)realTimeInputKeyPath;
+ (NSString *)realTimeOutputKeyPath;
@end

@interface RunsNetMeasurerResult : NSObject
@property (nonatomic, assign) RunsNetConnectionType connectionType;
@property (nonatomic, assign) double uplinkMaxSpeed;
@property (nonatomic, assign) double uplinkMinSpeed;
@property (nonatomic, assign) double uplinkAvgSpeed;
@property (nonatomic, assign) double uplinkCurSpeed;
@property (nonatomic, assign) double downlinkMaxSpeed;
@property (nonatomic, assign) double downlinkMinSpeed;
@property (nonatomic, assign) double downlinkAvgSpeed;
@property (nonatomic, assign) double downlinkCurSpeed;
@end

@interface RunsNetSpeedMeasurer : NSObject <ISpeedMeasurerProtocol>

@end



NS_ASSUME_NONNULL_END
