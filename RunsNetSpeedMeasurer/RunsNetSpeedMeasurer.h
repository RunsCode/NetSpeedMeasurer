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
    RunsNetConnectionType_WiFi,
    RunsNetConnectionType_WWAN,
};


NS_ASSUME_NONNULL_BEGIN

extern NSString * const RunsNetworkMaxSpeedAttributeName;
extern NSString * const RunsNetworkAverageSpeedAttributeName;
extern NSString * const RunsNetworkCurrentSpeedAttributeName;
extern NSString * const RunsNetworkConnectionTypeAttributeName;

typedef void(^RunsNetworkSpeedAttributeCallback)(NSDictionary<NSString *, id> *attributes);

@protocol ISpeedMeasurerProtocol;
@protocol RunsNetSpeedMeasurerDelegate <NSObject>
- (NSTimeInterval)intervalForMeasurer:(id<ISpeedMeasurerProtocol>)measurer;
- (void)measurer:(id<ISpeedMeasurerProtocol>)measurer didCompletedByInterval:(NSDictionary<NSString *, id>*)attributes;
@end

@protocol ISpeedMeasurerProtocol <NSObject>
@property (nonatomic, assign) NSUInteger accuracyLevel;//精度等级 1~5
@property (nonatomic, weak) id<RunsNetSpeedMeasurerDelegate> delegate;
- (void)mesaurerByInterval:(NSTimeInterval)interval attributesBlock:(RunsNetworkSpeedAttributeCallback)block;
@end

@interface RunsNetFragmentation : NSObject
@property (nonatomic, assign) RunsNetConnectionType connectionType;
@property (nonatomic, assign) RULong beginTimestamp;
@property (nonatomic, assign) RULong endTimestamp;
@property (nonatomic, assign) RULong bytesCount;
@property (nonatomic, assign) RULong packetsCount;

@end

@interface RunsNetSpeedMeasurer : NSObject <ISpeedMeasurerProtocol>

@end

NS_ASSUME_NONNULL_END
