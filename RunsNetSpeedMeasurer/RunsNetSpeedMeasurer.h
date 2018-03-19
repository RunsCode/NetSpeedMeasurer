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

typedef NS_ENUM(NSUInteger, RunsNetMeasurerCapability) {
    RunsNetMeasurer_MaxDownloadSpeed        = 1 << 0,
    RunsNetMeasurer_MinDownloadSpeed        = 1 << 1,
    RunsNetMeasurer_AverageDownloadSpeed    = 1 << 2,
    RunsNetMeasurer_RealTimeDownloadSpeed   = 1 << 3,
    RunsNetMeasurer_AllDownloadSpeed        = RunsNetMeasurer_MaxDownloadSpeed
                                            | RunsNetMeasurer_MinDownloadSpeed
                                            | RunsNetMeasurer_AverageDownloadSpeed
                                            | RunsNetMeasurer_RealTimeDownloadSpeed,
    //
    RunsNetMeasurer_MaxUploadSpeed          = 1 << 4,
    RunsNetMeasurer_MinUploadSpeed          = 1 << 5,
    RunsNetMeasurer_AverageUploadSpeed      = 1 << 6,
    RunsNetMeasurer_RealTimeUploadSpeed     = 1 << 7,
    RunsNetMeasurer_AllUploadSpeed          = RunsNetMeasurer_MaxUploadSpeed
                                            | RunsNetMeasurer_MinUploadSpeed
                                            | RunsNetMeasurer_AverageUploadSpeed
                                            | RunsNetMeasurer_RealTimeUploadSpeed,
    //
    RunsNetMeasurer_AllCapability           = RunsNetMeasurer_AllDownloadSpeed | RunsNetMeasurer_AllUploadSpeed,
    RunsNetMeasurer_Default                 = RunsNetMeasurer_AllCapability
};

NS_ASSUME_NONNULL_BEGIN

extern NSString * const RunsNetworkMaxDownloadSpeedAttributeName;
extern NSString * const RunsNetworkMinDownloadSpeedAttributeName;
extern NSString * const RunsNetworkAverageDownloadSpeedAttributeName;
extern NSString * const RunsNetworkCurrentDownloadSpeedAttributeName;
extern NSString * const RunsNetworkMaxUploadSpeedAttributeName;
extern NSString * const RunsNetworkMinUploadSpeedAttributeName;
extern NSString * const RunsNetworkAverageUploadSpeedAttributeName;
extern NSString * const RunsNetworkCurrentUploadSpeedAttributeName;
extern NSString * const RunsNetworkConnectionTypeAttributeName;

typedef void(^RunsNetworkSpeedAttributeCallback)(NSDictionary<NSString *, NSNumber *> *attributes);

@protocol ISpeedMeasurerProtocol;
@protocol RunsNetSpeedMeasurerDelegate <NSObject>
- (void)measurer:(id<ISpeedMeasurerProtocol>)measurer didCompletedByInterval:(NSDictionary<NSString *, id>*)attributes;
@end

@protocol ISubSpeedMeasurerProtocol <NSObject>
- (double)calculateMaxSpeed;
- (double)calculateMinSpeed;
- (double)calculateAverageSpeed;
- (double)calculateRealTimeSpeed;
@end

@protocol ISpeedMeasurerProtocol <NSObject>
@property (nonatomic, assign) NSUInteger accuracyLevel;//精度等级 1~5
@property (nonatomic, weak) id<RunsNetSpeedMeasurerDelegate> delegate;//Block和Delegate 二选一, Block优先级更高.
- (instancetype)initWithAccuracyLevel:(NSUInteger)accuracyLevel;
- (void)mesaurerByInterval:(NSTimeInterval)interval attributesBlock:(RunsNetworkSpeedAttributeCallback)block;
- (void)enableCapability:(RunsNetMeasurerCapability)capability;
- (void)disableCapability:(RunsNetMeasurerCapability)capability;
- (BOOL)hasCapability:(RunsNetMeasurerCapability)capability;
- (void)execute;
- (void)shutdown;
@end

@interface RunsNetFragmentation : NSObject
@property (nonatomic, assign) RunsNetConnectionType connectionType;
@property (nonatomic, assign) u_int32_t inputBytesCount;
@property (nonatomic, assign) u_int32_t outputBytesCount;
@end

@interface RunsNetSpeedMeasurer : NSObject <ISpeedMeasurerProtocol>

@end

@interface RunsNetSubSpeedMeasurer : NSObject <ISpeedMeasurerProtocol, ISubSpeedMeasurerProtocol>
@property (nonatomic) u_int32_t previousWifiInputBytesCount;
@property (nonatomic) u_int32_t previousWwanInputBytesCount;
@property (nonatomic) u_int32_t previousWifiOutputBytesCount;
@property (nonatomic) u_int32_t previousWwanOutputBytesCount;
- (void)dispatch;
@end

@interface RunsNetUplinkSpeedMeasurer : RunsNetSubSpeedMeasurer

@end

@interface RunsNetDownlinkSpeedMeasurer : RunsNetSubSpeedMeasurer

@end



NS_ASSUME_NONNULL_END
