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

#import "RunsNetSpeedMeasurer.h"

NSString * const RunsNetworkMaxDownloadSpeedAttributeName       = @"RunsNetworkMaxDownloadSpeedAttributeName";
NSString * const RunsNetworkAverageDownloadSpeedAttributeName   = @"RunsNetworkAverageDownloadSpeedAttributeName";
NSString * const RunsNetworkCurrentDownloadSpeedAttributeName   = @"RunsNetworkCurrentDownloadSpeedAttributeName";
NSString * const RunsNetworkMaxUploadSpeedAttributeName         = @"RunsNetworkMaxUploadSpeedAttributeName";
NSString * const RunsNetworkAverageUploadSpeedAttributeName     = @"RunsNetworkAverageUploadSpeedAttributeName";
NSString * const RunsNetworkCurrentUploadSpeedAttributeName     = @"RunsNetworkCurrentUploadSpeedAttributeName";
NSString * const RunsNetworkConnectionTypeAttributeName  = @"RunsNetworkConnectionTypeAttributeName";


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

#pragma mark -- Public Method

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

@end

@interface RunsNetSubSpeedMeasurer()
@property (nonatomic, assign) NSTimeInterval measurerInterval;
@property (nonatomic, assign) RunsNetMeasurerCapability measurerCapability;
@property (nonatomic, strong) RunsNetworkSpeedAttributeCallback measurerBlock;
@end

@implementation RunsNetSubSpeedMeasurer

@synthesize accuracyLevel;
@synthesize delegate;

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"RunsNetSubSpeedMeasurer Release");
#endif
}

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



@end

