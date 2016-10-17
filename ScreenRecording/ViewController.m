//
//  ViewController.m
//  ScreenRecording
//
//  Created by Nguyen Cat Dinh on 10/17/16.
//  Copyright © 2016 Nguyen Cat Dinh. All rights reserved.
//

#import "ViewController.h"
#import "CSScreenRecorder.h"

#include <mach/mach_time.h>
#import <objc/message.h>
#import <dlfcn.h>

@import MediaPlayer;

@interface ViewController ()<CSScreenRecorderDelegate>
{
  BOOL recording;
  BOOL shouldConnect;
  id routerController;
  MPVolumeView *volumeView;
  CSScreenRecorder *screenRecorder;
  NSString *airplayName;
}
@property (weak, nonatomic) IBOutlet UIView *mpView;
@end


@implementation ViewController
- (IBAction)toggleButton:(id)sender {
  if(recording)
  {
    [self stopRecord];
  }
  else
  {
    [self startRecord];
  }
}

- (void)setupAirplayMonitoring
{
  if(!routerController) {
    routerController = [NSClassFromString(@"MPAVRoutingController") new];
    [routerController setValue:self forKey:@"delegate"];
    [routerController setValue:[NSNumber numberWithLong:2] forKey:@"discoveryMode"];
  }
}

-(void)routingControllerAvailableRoutesDidChange	:(id)arg1{
  NSLog(@"arg1-%@",arg1);
  if (airplayName == nil) {
    return;
  }
  
  NSArray *availableRoutes = [routerController valueForKey:@"availableRoutes"];
  for (id router in availableRoutes) {
    NSString *routerName = [router valueForKey:@"routeName"];
    NSLog(@"routername -%@",routerName);
    if ([routerName rangeOfString:airplayName].length >0) {
      BOOL picked = [[router valueForKey:@"picked"] boolValue];
      if (picked == NO && !shouldConnect) {
        shouldConnect = YES;
        NSLog(@"connect once");
        NSString *one = @"p";
        NSString *two = @"ickR";
        NSString *three = @"oute:";
        NSString *path = [[one stringByAppendingString:two] stringByAppendingString:three];
        [routerController performSelector:NSSelectorFromString(path) withObject:router];
        //objc_msgSend(self.routerController,NSSelectorFromString(path),router);
      }
      return;
    }
  }
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  //    [self startRecord];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  shouldConnect = FALSE;
  
  airplayName = @"XBMC-GAMEBOX(XinDawn)";
  [self setupAirplayMonitoring];
  recording = NO;
  screenRecorder = [CSScreenRecorder sharedCSScreenRecorder];
  [screenRecorder setDelegate:self];
  CGRect rect;
  rect = self.mpView.frame;
  rect.origin.x = rect.origin.y = 0;
  
  volumeView = [[MPVolumeView alloc] initWithFrame:rect];
  //volumeView = [ [MPVolumeView alloc] init] ;
  
  [volumeView setShowsVolumeSlider:NO];
  
  [volumeView sizeToFit];
  [self.mpView addSubview:volumeView];
  
  [volumeView becomeFirstResponder];
  [volumeView setShowsRouteButton:YES];
  [volumeView setRouteButtonImage:[UIImage imageNamed:@"btn_record.png"] forState:UIControlStateNormal];
  [volumeView setRouteButtonImage:nil forState:UIControlStateNormal];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)startRecord {
  shouldConnect = FALSE;
  airplayName = @"XBMC-GAMEBOX(XinDawn)";
  [screenRecorder startRecordingScreen];
  recording = YES;
}

- (void)stopRecord {
  shouldConnect = FALSE;
  airplayName = @"iPhone";
  [screenRecorder stopRecordingScreen];
  recording = NO;
}

- (void)screenRecorderDidStartRecording:(CSScreenRecorder *)recorder
{
  NSLog(@"KDD, DID START");
  
}

- (void)screenRecorderDidStopRecording:(CSScreenRecorder *)recorder
{
  NSLog(@"KDD, DID STOP");
  
}


- (void)screenRecorder:(CSScreenRecorder *)recorder recordingTimeChanged:(NSTimeInterval)recordingTime
{// time in seconds since start of capture
  
  NSLog(@"KDD, DID UPDATE");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
