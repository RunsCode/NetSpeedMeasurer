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

@implementation RunsNetFragmentation
+ (NSString *)maxValueInputKeyPath { return @"@max.inputBytesCount"; }
+ (NSString *)minValueInputKeyPath { return @"@min.inputBytesCount"; }
+ (NSString *)avgValueInputKeyPath { return @"@avg.inputBytesCount"; }
+ (NSString *)maxValueOutputKeyPath { return @"@max.outputBytesCount"; }
+ (NSString *)minValueOutputKeyPath { return @"@min.outputBytesCount"; }
+ (NSString *)avgValueOutputKeyPath { return @"@avg.outputBytesCount"; }
+ (NSString *)realTimeInputKeyPath { return  @"real.time.input"; }
+ (NSString *)realTimeOutputKeyPath { return  @"real.time.output"; }
@end

@implementation RunsNetMeasurerResult
- (NSString *)description {
    return [NSString stringWithFormat:@"\nUplink: \n{\n   max : %.2f MB/s, min : %.2f MB/s, avg : %.2f MB/s, cur : %.2f MB/s \n}, \nDownlink: \n{\n   max : %.2f MB/s, min : %.2f MB/s, avg : %.2f MB/s, cur : %.2f MB/s \n}",
            _uplinkMaxSpeed, _uplinkMinSpeed, _uplinkAvgSpeed, _uplinkCurSpeed, _downlinkMaxSpeed, _downlinkMinSpeed, _downlinkAvgSpeed, _downlinkCurSpeed];
}
@end

@interface RunsNetSpeedMeasurer()
@property (nonatomic, strong) NSTimer *dispatchTimer;
@property (nonatomic, strong) NSMutableArray<RunsNetFragmentation *> *fragmentArray;
@property (nonatomic) u_int32_t previousInputBytesCount;
@property (nonatomic) u_int32_t previousOutputBytesCount;
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

#pragma mark -- Public Method ISpeedMeasurerProtocol

- (instancetype)initWithAccuracyLevel:(NSUInteger)accuracyLevel {
    self = [super init];
    if (self) {
        self.accuracyLevel = accuracyLevel;
    }
    return self;
}

- (void)setMeasurerInterval:(NSTimeInterval)measurerInterval_ {
    measurerInterval = measurerInterval_ <= 0.f ? 1.f : measurerInterval_;
}

- (void)setMeasurerBlock:(RunsNetworkSpeedAttributeCallback)measurerBlock_ {
    measurerBlock = measurerBlock_;
}

- (void)setDelegate:(id<RunsNetSpeedMeasurerDelegate>)delegate_ {
    delegate = delegate_;
 }

- (void)setAccuracyLevel:(NSUInteger)accuracyLevel_ {
    NSUInteger max = MEASURER_ACCURACY_LEVEL_MAX;
    NSUInteger min = MEASURER_ACCURACY_LEVEL_MIN;
    accuracyLevel = accuracyLevel_ >= min ? accuracyLevel_ <= max ?: max : min;
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
    [self calculateSpeed];
}

- (void)calculateSpeed {
    RunsNetMeasurerResult *result = [[RunsNetMeasurerResult alloc] init];
    result.connectionType = self.fragmentArray.lastObject.connectionType;
    {//上行
        result.uplinkMaxSpeed = [self calculateSpeedWithKeyPath:RunsNetFragmentation.maxValueOutputKeyPath];
        result.uplinkMinSpeed = [self calculateSpeedWithKeyPath:RunsNetFragmentation.minValueOutputKeyPath];
        result.uplinkAvgSpeed = [self calculateSpeedWithKeyPath:RunsNetFragmentation.avgValueOutputKeyPath];
        result.uplinkCurSpeed = [self calculateRealTimeSpeedWithKeyPath:RunsNetFragmentation.realTimeOutputKeyPath];
    }
    {//下行
        result.downlinkMaxSpeed = [self calculateSpeedWithKeyPath:RunsNetFragmentation.maxValueInputKeyPath];
        result.downlinkMinSpeed = [self calculateSpeedWithKeyPath:RunsNetFragmentation.minValueInputKeyPath];
        result.downlinkAvgSpeed = [self calculateSpeedWithKeyPath:RunsNetFragmentation.avgValueInputKeyPath];
        result.downlinkCurSpeed = [self calculateRealTimeSpeedWithKeyPath:RunsNetFragmentation.realTimeInputKeyPath];
    }
    
    if (measurerBlock) {
        measurerBlock(result);
        return;
    }
    
    if (delegate && [delegate respondsToSelector:@selector(measurer:didCompletedByInterval:)]) {
        [delegate measurer:self didCompletedByInterval:result];
    }
}

- (double)calculateSpeedWithKeyPath:(NSString *)keyPath {
    double bytesInMegabyte = 1024 * 1024 * 1000;
    double maxPerMeasureInterval = [[self.fragmentArray valueForKeyPath:keyPath] doubleValue] / bytesInMegabyte;
    return maxPerMeasureInterval / self.measurerInterval;
}

- (double)calculateRealTimeSpeedWithKeyPath:(NSString *)keyPath {
    if (NSDate.date.timeIntervalSinceNow - _fragmentArray.lastObject.endTimestamp > self.measurerInterval) {
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
