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


@implementation RunsNetFragmentation
@end


@interface RunsNetSpeedMeasurer()
@property (nonatomic, assign) NSTimeInterval measurerInterval;

//@property (nonatomic, readonly) double maxDownloadSpeed;
//@property (nonatomic, readonly) double averageDownloadSpeed;
//@property (nonatomic, readonly) double currentDownloadSpeed;


@property (nonatomic, strong) RunsNetworkSpeedAttributeCallback measurerBlock;

@end


@implementation RunsNetSpeedMeasurer
@synthesize accuracyLevel;
@synthesize delegate;

- (void)dealloc {
    
}

- (instancetype)init {
    self = [super init];
    if (self) {
        //
    }
    return self;
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





