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
+ (NSString *)maxValueInputKeyPath { return @"@max.inputBytesCount";}
+ (NSString *)minValueInputKeyPath { return @"@min.inputBytesCount";}
+ (NSString *)avgValueInputKeyPath { return @"@avg.inputBytesCount";}
+ (NSString *)maxValueOutputKeyPath { return @"@max.outputBytesCount";}
+ (NSString *)minValueOutputKeyPath { return @"@min.outputBytesCount";}
+ (NSString *)avgValueOutputKeyPath { return @"@avg.outputBytesCount";}
+ (NSString *)realTimeInputKeyPath {return  @"real.time.input";}
+ (NSString *)realTimeOutputKeyPath {return  @"real.time.output";}
@end

@interface RunsNetSpeedMeasurer()
@property (nonatomic, assign) RunsNetMeasurerCapability measurerCapability;
@property (nonatomic, strong) id<ISpeedMeasurerProtocol> uplinkSpeedMeasurer;
@property (nonatomic, strong) id<ISpeedMeasurerProtocol> downlinkSpeedMeasurer;
@end

@implementation RunsNetSpeedMeasurer
@synthesize measurerBlock;
@synthesize measurerInterval;
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

- (void)setMeasurerInterval:(NSTimeInterval)measurerInterval_ {
    measurerInterval = measurerInterval_ <= 0.f ? 1.f : measurerInterval_;
    _downlinkSpeedMeasurer.measurerInterval = measurerInterval;
    _uplinkSpeedMeasurer.measurerInterval = measurerInterval;
}

- (void)setMeasurerBlock:(RunsNetworkSpeedAttributeCallback)measurerBlock_ {
    measurerBlock = measurerBlock_;
    [self subcribe];
}

- (void)setDelegate:(id<RunsNetSpeedMeasurerDelegate>)delegate_ {
    delegate = delegate_;
    [self subcribe];
}

- (void)mesaurerByInterval:(NSTimeInterval)interval attributesDelegate:(id<RunsNetSpeedMeasurerDelegate>)delegate {
    self.measurerInterval = interval <= 0.f ? 1.f : interval;
    self.delegate = delegate;
    [self subcribe];
}

- (void)subcribe {
    __weak typeof(self) weak_self = self;
    [_downlinkSpeedMeasurer setMeasurerBlock:^(NSDictionary<NSString *,NSNumber *> * _Nonnull attributes) {
        if (attributes.count <= 0) return ;
        if (weak_self.measurerBlock) {
            weak_self.measurerBlock(attributes);
            return;
        }
        if (weak_self.delegate && [weak_self.delegate respondsToSelector:@selector(measurer:didCompletedByInterval:)]) {
            [weak_self.delegate measurer:weak_self didCompletedByInterval:attributes];
        }
    }];
    [_uplinkSpeedMeasurer setMeasurerBlock:^(NSDictionary<NSString *,NSNumber *> * _Nonnull attributes) {
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

- (void)setAccuracyLevel:(NSUInteger)accuracyLevel_ {
    NSUInteger max = MEASURER_ACCURACY_LEVEL_MAX;
    NSUInteger min = MEASURER_ACCURACY_LEVEL_MIN;
    accuracyLevel = accuracyLevel_ >= min ? accuracyLevel_ <= max ?: max : min;
    _downlinkSpeedMeasurer.accuracyLevel = self.accuracyLevel;
    _uplinkSpeedMeasurer.accuracyLevel = self.accuracyLevel;
}

- (void)execute {
    [_downlinkSpeedMeasurer execute];
    [_uplinkSpeedMeasurer execute];
}

- (void)shutdown {
    [_downlinkSpeedMeasurer shutdown];
    [_uplinkSpeedMeasurer shutdown];
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
@end


@interface RunsNetSubSpeedMeasurer()
@property (nonatomic, strong) NSTimer *dispatchTimer;
@property (nonatomic, assign) RunsNetMeasurerCapability measurerCapability;
@property (nonatomic, strong) NSMutableArray<RunsNetFragmentation *> *fragmentArray;
@property (nonatomic) u_int32_t previousInputBytesCount;
@property (nonatomic) u_int32_t previousOutputBytesCount;
@end

@implementation RunsNetSubSpeedMeasurer
@synthesize measurerBlock;
@synthesize measurerInterval;
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
    RunsNetFragmentation *fragment = [[RunsNetFragmentation alloc] init];
    fragment.endTimestamp = [[NSDate date] timeIntervalSince1970];
    fragment.beginTimestamp = fragment.endTimestamp - self.measurerInterval;
    fragment.inputBytesCount = ibytes - _previousInputBytesCount;
    fragment.outputBytesCount = obytes - _previousOutputBytesCount;
    fragment.connectionType = type;
    //
    _previousOutputBytesCount = ibytes;
    _previousOutputBytesCount = obytes;
    //
    return fragment;
}

- (void)dispatch {
    RunsNetFragmentation *fragment = [self currentNetCardTrafficData];
    if(!fragment) return;
    if (_fragmentArray.count >= self.maxFramentArrayCapacity) {
        [_fragmentArray removeObjectAtIndex:0];
    }
    [self.fragmentArray addObject:fragment];
    //sub class will override
}

- (double)calculateSpeedWithKeyPath:(NSString *)keyPath {
    double bytesInMegabyte = 1024 * 1024 * 1000;
    double maxPerMeasureInterval = [[self.fragmentArray valueForKeyPath:keyPath] doubleValue] / bytesInMegabyte;
    return maxPerMeasureInterval / self.measurerInterval;
}

- (double)calculateRealTimeSpeedWithKeyPath:(NSString *)keyPath {
    if ([[NSDate date] timeIntervalSinceNow] - _fragmentArray.lastObject.endTimestamp > self.measurerInterval) {
        return 0;
    }
    uint32_t bytesCount = _fragmentArray.lastObject.inputBytesCount;
    if ([keyPath isEqualToString:RunsNetFragmentation.realTimeOutputKeyPath]) {
        bytesCount = _fragmentArray.lastObject.outputBytesCount;
    }
    double bytesPerSecondInBytes = bytesCount / self.measurerInterval;
    double bytesInMegabyte = 1024 * 1024 * 1000;
    return bytesPerSecondInBytes / bytesInMegabyte;
}

- (NSMutableArray<RunsNetFragmentation *> *)fragmentArray {
    if (_fragmentArray) return _fragmentArray;
    int capacity = [self maxFramentArrayCapacity];
    _fragmentArray = [[NSMutableArray alloc] initWithCapacity:capacity];
    return _fragmentArray;
}

- (int)maxFramentArrayCapacity {
    return (1 / self.measurerInterval) * accuracyLevel * 600;
}


@end

@implementation RunsNetUplinkSpeedMeasurer
- (void)dealloc {
#ifdef DEBUG
    NSLog(@"RunsNetUplinkSpeedMeasurer Release");
#endif
}

- (void)dispatch {
    [super dispatch];
    if (self.fragmentArray.count <= 0)  return;

    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithCapacity:5];
    [attributes setObject:@(self.fragmentArray.lastObject.connectionType) forKey:RunsNetworkConnectionTypeAttributeName];
    if ([self hasCapability:RunsNetMeasurer_MaxUploadSpeed]) {
        double max = [self calculateSpeedWithKeyPath:RunsNetFragmentation.maxValueOutputKeyPath];
        [attributes setObject:@(max) forKey:RunsNetworkMaxUploadSpeedAttributeName];
    }
    if ([self hasCapability:RunsNetMeasurer_MinUploadSpeed]) {
        double min = [self calculateSpeedWithKeyPath:RunsNetFragmentation.minValueOutputKeyPath];
        [attributes setObject:@(min) forKey:RunsNetworkMinUploadSpeedAttributeName];
    }
    if ([self hasCapability:RunsNetMeasurer_AverageUploadSpeed]) {
        double avg = [self calculateSpeedWithKeyPath:RunsNetFragmentation.avgValueOutputKeyPath];
        [attributes setObject:@(avg) forKey:RunsNetworkAverageUploadSpeedAttributeName];
    }
    if ([self hasCapability:RunsNetMeasurer_RealTimeUploadSpeed]) {
        double cur = [self calculateRealTimeSpeedWithKeyPath:RunsNetFragmentation.realTimeOutputKeyPath];
        [attributes setObject:@(cur) forKey:RunsNetworkCurrentUploadSpeedAttributeName];
    }
    if (self.measurerBlock) {
        self.measurerBlock(attributes);
    }
}

@end

@implementation RunsNetDownlinkSpeedMeasurer

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"RunsNetDownlinkSpeedMeasurer Release");
#endif
}

- (void)dispatch {
    [super dispatch];
    if (self.fragmentArray.count <= 0)  return;
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithCapacity:5];
    [attributes setObject:@(self.fragmentArray.lastObject.connectionType) forKey:RunsNetworkConnectionTypeAttributeName];
    if ([self hasCapability:RunsNetMeasurer_MaxDownloadSpeed])  {
        double max = [self calculateSpeedWithKeyPath:RunsNetFragmentation.maxValueInputKeyPath];
        [attributes setObject:@(max) forKey:RunsNetworkMaxDownloadSpeedAttributeName];
    }
    if ([self hasCapability:RunsNetMeasurer_MinDownloadSpeed]) {
        double min = [self calculateSpeedWithKeyPath:RunsNetFragmentation.minValueInputKeyPath];
        [attributes setObject:@(min) forKey:RunsNetworkMinDownloadSpeedAttributeName];
    }
    if ([self hasCapability:RunsNetMeasurer_AverageDownloadSpeed]) {
        double avg = [self calculateSpeedWithKeyPath:RunsNetFragmentation.avgValueInputKeyPath];
        [attributes setObject:@(avg) forKey:RunsNetworkAverageDownloadSpeedAttributeName];
    }
    if ([self hasCapability:RunsNetMeasurer_RealTimeDownloadSpeed]) {
        double cur = [self calculateRealTimeSpeedWithKeyPath:RunsNetFragmentation.realTimeInputKeyPath];
        [attributes setObject:@(cur) forKey:RunsNetworkCurrentDownloadSpeedAttributeName];
    }
    if (self.measurerBlock) {
        self.measurerBlock(attributes);
    }
}


@end

