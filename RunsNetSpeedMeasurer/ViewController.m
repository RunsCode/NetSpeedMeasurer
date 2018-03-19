//
//  ViewController.m
//  RunsNetworkSpeedMeasurer
//
//  Created by runs on 2018/3/16.
//  Copyright © 2018年 Olacio. All rights reserved.
//

#import "ViewController.h"
#import "RunsNetSpeedMeasurer.h"

@interface ViewController ()<NSURLSessionDownloadDelegate,RunsNetSpeedMeasurerDelegate>
@property (strong, nonatomic) IBOutlet UILabel *uploadMaxSpeedLabel;
@property (strong, nonatomic) IBOutlet UILabel *uploadAvgSpeedLabel;
@property (strong, nonatomic) IBOutlet UILabel *uploadMinSpeedLabel;
@property (strong, nonatomic) IBOutlet UILabel *uploadCurSpeedLabel;
@property (strong, nonatomic) IBOutlet UILabel *downloadMaxSpeedLabel;
@property (strong, nonatomic) IBOutlet UILabel *downloadAvgSpeedLabel;
@property (strong, nonatomic) IBOutlet UILabel *downloadCurSpeedLabel;
@property (strong, nonatomic) IBOutlet UILabel *downloadMinSpeedLabel;
@property (nonatomic, strong) id<ISpeedMeasurerProtocol> measurer;
@property (strong, nonatomic) IBOutlet UILabel *netTypeLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _measurer = [[RunsNetSpeedMeasurer alloc] initWithAccuracyLevel:5];
    [_measurer enableCapability:RunsNetMeasurer_Default];
    _measurer.delegate = self;
    _measurer.measurerInterval = 0.5f;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onUoloadTest:(id)sender {
    
}

- (IBAction)onDowmloadTest:(id)sender {
    [_measurer execute];
    NSLog(@"onDowmloadTest");
    //
    NSURL* url = [NSURL URLWithString:@"http://record.olacio.com/record/data/media/2-28155/merge-audio_20180314122538352.m4a"];
    if (!url)  return;
    
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
    [[session downloadTaskWithURL:url] resume];
}


#pragma mark -- NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession*)session downloadTask:(NSURLSessionDownloadTask*)downloadTask didFinishDownloadingToURL:(NSURL*)location {
    NSLog(@"下载完成");
    [_measurer shutdown];
}

- (void)URLSession:(NSURLSession*)session downloadTask:(NSURLSessionDownloadTask*)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    float progress = (float)totalBytesWritten / totalBytesExpectedToWrite;
        NSLog(@"下载进度 ：%f", progress);
}

#pragma mark -- RunsNetSpeedMeasurerDelegate

- (void)measurer:(nonnull id<ISpeedMeasurerProtocol>)measurer didCompletedByInterval:(nonnull NSDictionary<NSString *,id> *)attributes {
    [self displayNetAttributes:attributes];
}

- (void)displayNetAttributes:(NSDictionary *)attributes {
    RunsNetConnectionType netType = [attributes[RunsNetworkConnectionTypeAttributeName] integerValue];
    _netTypeLabel.text = netType == RunsNetConnectionType_WiFi ?  @"WWAN-移动数据网络" :  @"WiFi-无线网络";
    CGFloat uploadMaxSpeed = [attributes[RunsNetworkMaxUploadSpeedAttributeName] doubleValue];
    _uploadMaxSpeedLabel.text = [NSString stringWithFormat:@"Max : %.2f MB/s",uploadMaxSpeed];
    CGFloat uploadMinSpeed = [attributes[RunsNetworkMinUploadSpeedAttributeName] doubleValue];
    _uploadMinSpeedLabel.text = [NSString stringWithFormat:@"Min : %.2f MB/s",uploadMinSpeed];
    CGFloat uploadAvgSpeed = [attributes[RunsNetworkAverageUploadSpeedAttributeName] doubleValue];
    _uploadAvgSpeedLabel.text = [NSString stringWithFormat:@"Avg : %.2f MB/s",uploadAvgSpeed];
    CGFloat uploadCurSpeed = [attributes[RunsNetworkCurrentUploadSpeedAttributeName] doubleValue];
    _uploadCurSpeedLabel.text = [NSString stringWithFormat:@"Cur : %.2f MB/s",uploadCurSpeed];
    //
    CGFloat downMaxSpeed = [attributes[RunsNetworkMaxDownloadSpeedAttributeName] doubleValue];
    NSLog(@"downMaxSpeed = %.2f", downMaxSpeed);
    if (downMaxSpeed > 0)
        _downloadMaxSpeedLabel.text = [NSString stringWithFormat:@"Max : %.2f MB/s",downMaxSpeed];
    CGFloat downloadMinSpeed = [attributes[RunsNetworkMinDownloadSpeedAttributeName] doubleValue];
    NSLog(@"downloadMinSpeed = %.2f", downloadMinSpeed);
    if (downloadMinSpeed > 0)
        _downloadMinSpeedLabel.text = [NSString stringWithFormat:@"Min : %.2f MB/s",downloadMinSpeed];
    CGFloat downloadAvgSpeed = [attributes[RunsNetworkAverageDownloadSpeedAttributeName] doubleValue];
    NSLog(@"downloadAvgSpeed = %.2f", downloadAvgSpeed);
    if (downloadAvgSpeed > 0)
        _downloadAvgSpeedLabel.text = [NSString stringWithFormat:@"Avg : %.2f MB/s",downloadAvgSpeed];
    CGFloat downloadCurSpeed = [attributes[RunsNetworkCurrentDownloadSpeedAttributeName] doubleValue];
    NSLog(@"downloadCurSpeed = %.2f", downloadCurSpeed);
    if (downloadCurSpeed > 0)
        _downloadCurSpeedLabel.text = [NSString stringWithFormat:@"Cur : %.2f MB/s",downloadCurSpeed];
}


@end
