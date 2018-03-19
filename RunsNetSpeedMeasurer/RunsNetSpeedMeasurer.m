//
//  RunsNetSpeedMeasurer.m
//  RunsNetSpeedMeasurer
//
//  Created by runs on 2018/3/16.
//  Learning from Vladislav Dugnist
//  Copyright © 2018年 Olacio. All rights reserved.
//

#define MEASURER_ACCURACY_LEVEL_MIN (1)
#define MEASURER_ACCURACY_LEVEL_MAX (5)

#define WIFI_PREFIX  @"en"
#define WWAN_PREFIX  @"pdp_ip"


#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>

#import "RunsNetSpeedMeasurer.h"

NSString * const RunsNetworkMaxDownloadSpeedAttributeName       = @"RunsNetworkMaxDownloadSpeedAttributeName";
NSString * const RunsNetworkMinDownloadSpeedAttributeName       = @"RunsNetworkMinDownloadSpeedAttributeName";
NSString * const RunsNetworkAverageDownloadSpeedAttributeName   = @"RunsNetworkAverageDownloadSpeedAttributeName";
NSString * const RunsNetworkCurrentDownloadSpeedAttributeName   = @"RunsNetworkCurrentDownloadSpeedAttributeName";
NSString * const RunsNetworkMaxUploadSpeedAttributeName         = @"RunsNetworkMaxUploadSpeedAttributeName";
NSString * const RunsNetworkMinUploadSpeedAttributeName         = @"RunsNetworkMinUploadSpeedAttributeName";
NSString * const RunsNetworkAverageUploadSpeedAttributeName     = @"RunsNetworkAverageUploadSpeedAttributeName";
NSString * const RunsNetworkCurrentUploadSpeedAttributeName     = @"RunsNetworkCurrentUploadSpeedAttributeName";
NSString * const RunsNetworkConnectionTypeAttributeName         = @"RunsNetworkConnectionTypeAttributeName";


@implementation RunsNetFragmentation

@end

@interface RunsNetSpeedMeasurer()
@property (nonatomic, assign) NSTimeInterval measurerInterval;
@property (nonatomic, assign) RunsNetMeasurerCapability measurerCapability;
@property (nonatomic, strong) RunsNetworkSpeedAttributeCallback measurerBlock;
@property (nonatomic, strong) id<ISpeedMeasurerProtocol> uplinkSpeedMeasurer;
@property (nonatomic, strong) id<ISpeedMeasurerProtocol> downlinkSpeedMeasurer;
@end

@implementation RunsNetSpeedMeasurer
@synthesize accuracyLevel;
@synthesize delegate;

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"RunsNetSpeedMeasurer Release");
#endif
}

- (instancetype)init {
    self = [super init];
    if (self) {
        //
    }
    return self;
}

#pragma mark -- Public Method ISpeedMeasurerProtocol

- (instancetype)initWithAccuracyLevel:(NSUInteger)accuracyLevel {
    self = [super init];
    if (self) {
        self.accuracyLevel = accuracyLevel;
    }
    return self;
}

- (void)enableCapability:(RunsNetMeasurerCapability)capability {
    //通过能力区分避免意外初始化不必要的能力对象
    if (RunsNetMeasurer_AllCapability == capability) {
        [self.downlinkSpeedMeasurer enableCapability:RunsNetMeasurer_AllDownloadSpeed];
        [self.uplinkSpeedMeasurer enableCapability:RunsNetMeasurer_AllUploadSpeed];
        return;
    }
    
    if (RunsNetMeasurer_AllDownloadSpeed & capability) {
        [self.downlinkSpeedMeasurer enableCapability:capability];
        return;
    }
    if (RunsNetMeasurer_AllUploadSpeed & capability) {
        [self.uplinkSpeedMeasurer enableCapability:capability];
    }
}

- (void)disableCapability:(RunsNetMeasurerCapability)capability {
    
    if (RunsNetMeasurer_AllCapability == capability) {
        _downlinkSpeedMeasurer = nil;
        _uplinkSpeedMeasurer = nil;
        return;
    }
    [_downlinkSpeedMeasurer disableCapability:capability];
    [_uplinkSpeedMeasurer disableCapability:capability];
}

- (BOOL)hasCapability:(RunsNetMeasurerCapability)capability {
    return [_downlinkSpeedMeasurer hasCapability:capability] || [_uplinkSpeedMeasurer hasCapability:capability];
}

- (void)mesaurerByInterval:(NSTimeInterval)interval attributesBlock:(RunsNetworkSpeedAttributeCallback)block {
    _measurerInterval = interval <= 0.f ? 1.f : interval;
    _measurerBlock = block;
    __weak typeof(self) weak_self = self;
    [_downlinkSpeedMeasurer mesaurerByInterval:_measurerInterval attributesBlock:^(NSDictionary<NSString *,id> * _Nonnull attributes) {
        if (attributes.count <= 0) return ;
        if (weak_self.measurerBlock) {
            weak_self.measurerBlock(attributes);
            return;
        }
        if (weak_self.delegate && [weak_self.delegate respondsToSelector:@selector(measurer:didCompletedByInterval:)]) {
            [weak_self.delegate measurer:weak_self didCompletedByInterval:attributes];
        }
    }];
    [_uplinkSpeedMeasurer mesaurerByInterval:_measurerInterval attributesBlock:^(NSDictionary<NSString *,id> * _Nonnull attributes) {
        if (attributes.count <= 0) return ;
        if (weak_self.measurerBlock) {
            weak_self.measurerBlock(attributes);
            return;
        }
        if (weak_self.delegate && [weak_self.delegate respondsToSelector:@selector(measurer:didCompletedByInterval:)]) {
            [weak_self.delegate measurer:weak_self didCompletedByInterval:attributes];
        }
    }];
}

- (void)setAccuracyLevel:(NSUInteger)accuracyLevel {
    NSUInteger max = MEASURER_ACCURACY_LEVEL_MAX;
    NSUInteger min = MEASURER_ACCURACY_LEVEL_MIN;
    self.accuracyLevel = accuracyLevel >= min ? accuracyLevel <= max ?: max : min;
    _downlinkSpeedMeasurer.accuracyLevel = self.accuracyLevel;
    _uplinkSpeedMeasurer.accuracyLevel = self.accuracyLevel;
}

- (id<ISpeedMeasurerProtocol>)uplinkSpeedMeasurer {
    if (_uplinkSpeedMeasurer) return _uplinkSpeedMeasurer;
    _uplinkSpeedMeasurer = [[RunsNetUplinkSpeedMeasurer alloc] initWithAccuracyLevel:self.accuracyLevel];;
    return _uplinkSpeedMeasurer;
}

- (id<ISpeedMeasurerProtocol>)downlinkSpeedMeasurer {
    if (_downlinkSpeedMeasurer) return _downlinkSpeedMeasurer;
    _downlinkSpeedMeasurer = [[RunsNetDownlinkSpeedMeasurer alloc] initWithAccuracyLevel:self.accuracyLevel];;
    return _downlinkSpeedMeasurer;
}

- (void)execute {
    [_downlinkSpeedMeasurer execute];
    [_uplinkSpeedMeasurer execute];
}

- (void)shutdown {
    [_downlinkSpeedMeasurer shutdown];
    [_uplinkSpeedMeasurer shutdown];
}

@end


@interface RunsNetSubSpeedMeasurer()
@property (nonatomic, strong) NSTimer *dispatchTimer;
@property (nonatomic, assign) NSTimeInterval measurerInterval;
@property (nonatomic, assign) RunsNetMeasurerCapability measurerCapability;
@property (nonatomic, strong) RunsNetworkSpeedAttributeCallback measurerBlock;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *attributes;
@property (nonatomic, strong) NSMutableArray<RunsNetFragmentation *> *fragmentArray;
@end

@implementation RunsNetSubSpeedMeasurer

@synthesize accuracyLevel;
@synthesize delegate;

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"RunsNetSubSpeedMeasurer Release");
#endif
}

#pragma mark -- Public Method ISpeedMeasurerProtocol

- (instancetype)initWithAccuracyLevel:(NSUInteger)accuracyLevel {
    self = [super init];
    if (self) {
        self.accuracyLevel = accuracyLevel;
    }
    return self;
}

- (void)enableCapability:(RunsNetMeasurerCapability)capability {
    _measurerCapability |= capability;
}

- (void)disableCapability:(RunsNetMeasurerCapability)capability {
    if (_measurerCapability & capability) {
        capability &= ~capability;
    }
}

- (BOOL)hasCapability:(RunsNetMeasurerCapability)capability {
    return _measurerCapability & capability;
}

- (void)mesaurerByInterval:(NSTimeInterval)interval attributesBlock:(RunsNetworkSpeedAttributeCallback)block {
    _measurerInterval = interval <= 0.f ? 1.f : interval;
    _measurerBlock = block;
}

- (void)setAccuracyLevel:(NSUInteger)accuracyLevel {
    NSUInteger max = MEASURER_ACCURACY_LEVEL_MAX;
    NSUInteger min = MEASURER_ACCURACY_LEVEL_MIN;
    self.accuracyLevel = accuracyLevel >= min ? accuracyLevel <= max ?: max : min;
}

- (void)execute {
    if (_dispatchTimer) return;
    _dispatchTimer = [NSTimer scheduledTimerWithTimeInterval:self.measurerInterval target:self selector:@selector(dispatch) userInfo:nil repeats:YES];
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addTimer:_dispatchTimer forMode:NSRunLoopCommonModes];
}

- (void)shutdown {
    if (!_dispatchTimer) return;
    [_dispatchTimer invalidate];
    _dispatchTimer = nil;
}

- (RunsNetFragmentation * _Nullable )currentNetCardTrafficData {
    struct ifaddrs *ifa_list = 0, *ifa;
    if (getifaddrs(&ifa_list) == -1) {
        return nil;
    }

    u_int32_t ibytes = 0;
    u_int32_t obytes = 0;
    //统计显卡上下行流量
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        if (AF_LINK != ifa->ifa_addr->sa_family) continue;
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING))  continue;
        if (ifa->ifa_data == 0) continue;
        
        /* Not a loopback device. */
        if (strncmp(ifa->ifa_name, "lo", 2)) {
            struct if_data *if_data = (struct if_data *)ifa->ifa_data;
            ibytes += if_data->ifi_ibytes;
            obytes += if_data->ifi_obytes;
        }
    }
    //
    NSString* ifa_name = [NSString stringWithCString:ifa_list->ifa_name encoding:NSUTF8StringEncoding];
    RunsNetConnectionType type = RunsNetConnectionType_WWAN;
    if ([ifa_name hasPrefix:WIFI_PREFIX]) {
        type = RunsNetConnectionType_WiFi;
    }
    RunsNetFragmentation *fragment = [self wrapFragmentWithConntype:type inputBytes:ibytes outputBytes:obytes];
    //
    freeifaddrs(ifa_list);
    return fragment;
}

- (RunsNetFragmentation *)wrapFragmentWithConntype:(RunsNetConnectionType)type inputBytes:(u_int32_t)ibytes outputBytes:(u_int32_t)obytes {
    RunsNetFragmentation *fragment = [RunsNetFragmentation new];
    fragment.inputBytesCount = ibytes;
    fragment.outputBytesCount = obytes;
    fragment.connectionType = type;
    return fragment;

}

- (void)dispatch {
    RunsNetFragmentation *fragment = [self currentNetCardTrafficData];
    if(!fragment) return;
    [self.fragmentArray addObject:fragment];
    //sub class will override
}

- (double)calculateAverageSpeed {
    //sub class will override
    return 0.0;
}

- (double)calculateMaxSpeed {
    //sub class will override
    return 0.0;
}

- (double)calculateMinSpeed {
    //sub class will override
    return 0.0;
}

- (double)calculateRealTimeSpeed {
    //sub class will override
    return 0.0;
}

- (NSMutableDictionary<NSString *,NSNumber *> *)attributes {
    if (_attributes) return _attributes;
    _attributes = [[NSMutableDictionary alloc] initWithCapacity:5];
    return _attributes;
}

- (NSMutableArray<RunsNetFragmentation *> *)fragmentArray {
    if (_fragmentArray) return _fragmentArray;
    int capacity = [self maxFramentArrayCapacity];
    _fragmentArray = [[NSMutableArray alloc] initWithCapacity:capacity];
    return _fragmentArray;
}

- (int)maxFramentArrayCapacity {
    return (1 / _measurerInterval) * accuracyLevel * 600;
}

- (void)addAttributesWithObject:(NSNumber *)number forKey:(NSString *)key {
    if (!number || !key || key.length <=0 ) {
        return;
    }
    [self.attributes setObject:number forKey:key];
}

@end



@implementation RunsNetUplinkSpeedMeasurer
- (void)dealloc {
#ifdef DEBUG
    NSLog(@"RunsNetUplinkSpeedMeasurer Release");
#endif
}

- (instancetype)initWithAccuracyLevel:(NSUInteger)accuracyLevel {
    self = [super initWithAccuracyLevel:accuracyLevel];
    if (self) {
        
    }
    return self;
}

- (void)dispatch {
    [super dispatch];
    if (self.fragmentArray.count <= 0)  return;
    [self.attributes setObject:@(self.fragmentArray.lastObject.connectionType) forKey:RunsNetworkConnectionTypeAttributeName];
    __weak typeof(self) weak_self = self;
    dispatch_queue_t queue = dispatch_queue_create("com.runs.upload_speed", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    if ([self hasCapability:RunsNetMeasurer_MaxUploadSpeed]) {
        dispatch_group_async(group, queue, ^{
            double max = [weak_self calculateMaxSpeed];
            [weak_self addAttributesWithObject:@(max) forKey:RunsNetworkMaxUploadSpeedAttributeName];
        });
    }
    if ([self hasCapability:RunsNetMeasurer_MinUploadSpeed]) {
        dispatch_group_async(group, queue, ^{
            double min = [weak_self calculateMinSpeed];
            [weak_self addAttributesWithObject:@(min) forKey:RunsNetworkMinUploadSpeedAttributeName];
        });
    }
    if ([self hasCapability:RunsNetMeasurer_AverageUploadSpeed]) {
        dispatch_group_async(group, queue, ^{
            double average = [weak_self calculateAverageSpeed];
            [weak_self addAttributesWithObject:@(average) forKey:RunsNetworkAverageUploadSpeedAttributeName];
        });
    }
    if ([self hasCapability:RunsNetMeasurer_RealTimeUploadSpeed]) {
        dispatch_group_async(group, queue, ^{
            double realTime = [weak_self calculateRealTimeSpeed];
            [weak_self addAttributesWithObject:@(realTime) forKey:RunsNetworkAverageUploadSpeedAttributeName];
        });
    }
    dispatch_group_notify(group, queue, ^{
        if (weak_self.measurerBlock) {
            weak_self.measurerBlock(weak_self.attributes);
        }
    });
}

- (double)calculateMaxSpeed {
    return 0.0;
}

- (double)calculateMinSpeed {
    return 0.0;
}

- (double)calculateAverageSpeed {
    return 0.0;
}

- (double)calculateRealTimeSpeed {
    return 0.0;
}

@end

@implementation RunsNetDownlinkSpeedMeasurer

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"RunsNetDownlinkSpeedMeasurer Release");
#endif
}

- (instancetype)initWithAccuracyLevel:(NSUInteger)accuracyLevel {
    self = [super initWithAccuracyLevel:accuracyLevel];
    if (self) {
        
    }
    return self;
}

- (void)dispatch {
    [super dispatch];
    if (self.fragmentArray.count <= 0)  return;
    [self.attributes setObject:@(self.fragmentArray.lastObject.connectionType) forKey:RunsNetworkConnectionTypeAttributeName];
    __weak typeof(self) weak_self = self;
    dispatch_queue_t queue = dispatch_queue_create("com.runs.download_speed", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    if ([self hasCapability:RunsNetMeasurer_MaxDownloadSpeed]) {
        dispatch_group_async(group, queue, ^{
            double max = [self calculateMaxSpeed];
            [weak_self addAttributesWithObject:@(max) forKey:RunsNetworkMaxDownloadSpeedAttributeName];
        });
    }
    if ([self hasCapability:RunsNetMeasurer_MinDownloadSpeed]) {
        dispatch_group_async(group, queue, ^{
            double min = [self calculateMinSpeed];
            [weak_self addAttributesWithObject:@(min) forKey:RunsNetworkMinDownloadSpeedAttributeName];
        });
    }
    if ([self hasCapability:RunsNetMeasurer_AverageDownloadSpeed]) {
        dispatch_group_async(group, queue, ^{
            double average = [self calculateAverageSpeed];
            [weak_self addAttributesWithObject:@(average) forKey:RunsNetworkAverageDownloadSpeedAttributeName];
        });
    }
    if ([self hasCapability:RunsNetMeasurer_RealTimeDownloadSpeed]) {
        dispatch_group_async(group, queue, ^{
            double realTime = [self calculateRealTimeSpeed];
            [weak_self addAttributesWithObject:@(realTime) forKey:RunsNetworkCurrentDownloadSpeedAttributeName];
        });
    }
    dispatch_group_notify(group, queue, ^{
        if (weak_self.measurerBlock) {
            weak_self.measurerBlock(weak_self.attributes);
        }
    });
}

- (double)calculateMaxSpeed {
    return 0.0;
}

- (double)calculateMinSpeed {
    return 0.0;
}

- (double)calculateAverageSpeed {
    return 0.0;
}

- (double)calculateRealTimeSpeed {
    return 0.0;
}


@end

