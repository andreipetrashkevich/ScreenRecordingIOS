//
//  CSScreenRecorder.m
//  RecordMyScreen
//
//  Created by Aditya KD on 02/04/13.
//  Copyright (c) 2013 CoolStar Organization. All rights reserved.
//

#import "CSScreenRecorder.h"

#import <CoreVideo/CVPixelBuffer.h>
#import <QuartzCore/QuartzCore.h>

#include <sys/time.h>

#include "Utilities.h"
#include "mediaserver.h"
#include <pthread.h>

static AVAudioRecorder    *_audioRecorder=nil ;
@interface CSScreenRecorder ()
//{
//@private

//}


@end

@implementation CSScreenRecorder

static CSScreenRecorder * _sharedCSScreenRecorder;

+ (CSScreenRecorder *) sharedCSScreenRecorder
{
    
  if (_sharedCSScreenRecorder != nil) {
    return _sharedCSScreenRecorder;
  }
  _sharedCSScreenRecorder = [[CSScreenRecorder alloc] init];
  
  return _sharedCSScreenRecorder;
}

- (void)setDelegate:(id<CSScreenRecorderDelegate>)delegate{
    @synchronized(self)
    {
        _delegate = delegate;
    }
}


- (instancetype)init
{
    if ((self = [super init])) {
        
    }
    return self;
}


FILE  *m_handle = NULL;
void video_open(void *cls,int width,int height,const void *buffer, int buflen, int payloadtype, double timestamp)
{
  NSString *fileName264 = [Utilities documentsPath:[NSString stringWithFormat:@"XinDawnRec-%04d.264",rand()]];
  
  m_handle = fopen([fileName264 cStringUsingEncoding: NSUTF8StringEncoding], "wb");
  
  int spscnt;
  int spsnalsize;
  int ppscnt;
  int ppsnalsize;
        
  unsigned    char *head = (unsigned  char *)buffer;
  
  spscnt = head[5] & 0x1f;
  spsnalsize = ((uint32_t)head[6] << 8) | ((uint32_t)head[7]);
  ppscnt = head[8 + spsnalsize];
  ppsnalsize = ((uint32_t)head[9 + spsnalsize] << 8) | ((uint32_t)head[10 + spsnalsize]);
  
  unsigned char *data = (unsigned char *)malloc(4 + spsnalsize + 4 + ppsnalsize);
  
  data[0] = 0;
  data[1] = 0;
  data[2] = 0;
  data[3] = 1;
        
  memcpy(data + 4, head + 8, spsnalsize);
        
  data[4 + spsnalsize] = 0;
  data[5 + spsnalsize] = 0;
  data[6 + spsnalsize] = 0;
  data[7 + spsnalsize] = 1;
  
  memcpy(data + 8 + spsnalsize, head + 11 + spsnalsize, ppsnalsize);
        
  //Check: send data or send whole buffer to upper layer
  fwrite(data,1,4 + spsnalsize + 4 + ppsnalsize,m_handle);
        
  free(data);
  
    
//kdd
    [[CSScreenRecorder sharedCSScreenRecorder].delegate screenRecorderDidStartRecording:[CSScreenRecorder sharedCSScreenRecorder]];
  
}


void video_process(void *cls,const void *buffer, int buflen, int payloadtype, double timestamp)
{
  if (payloadtype == 0)
  {
    int		    rLen;
    unsigned    char *head;
    unsigned char *data = (unsigned char *)malloc(buflen);
    memcpy(data, buffer, buflen);
            
            
            // What are these code for???
        
            rLen = 0;
            head = (unsigned char *)data + rLen;
            while (rLen < buflen)
            {
                rLen += 4;
                rLen += (((uint32_t)head[0] << 24) | ((uint32_t)head[1] << 16) | ((uint32_t)head[2] << 8) | (uint32_t)head[3]);
                
                head[0] = 0;
                head[1] = 0;
                head[2] = 0;
                head[3] = 1;
                
                head = (unsigned char *)data + rLen;
            }
    
            
    //Send all data to upper layer currently we save H.264 to check first
    fwrite(data,1,buflen,m_handle);
            
    free(data);
      
  }
    // printf("=====video====%f====\n",timestamp);
    //kdd
    [[CSScreenRecorder sharedCSScreenRecorder].delegate screenRecorder:[CSScreenRecorder sharedCSScreenRecorder] recordingTimeChanged:timestamp];
  
}

void video_stop(void *cls)
{
    fclose(m_handle);
    printf("=====video_stop========\n");
    
    //kdd
    [[CSScreenRecorder sharedCSScreenRecorder].delegate screenRecorderDidStopRecording:[CSScreenRecorder sharedCSScreenRecorder]];
  
}

NSString* audioOutPath;
- (void)_setupAudio
{
  // Setup to be able to record global sounds (preexisting app sounds)
  
  NSError *sessionError = nil;
  
  
  [[AVAudioSession sharedInstance] setActive:YES error:&sessionError];
  
  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&sessionError];
  
  
  [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeDefault error:nil];
  
  
  [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
  
  
  self.audioSampleRate  = @44100;
  self.numberOfAudioChannels = @2;
  
  // Set the number of audio channels, using defaults if necessary.
  NSNumber *audioChannels = (self.numberOfAudioChannels ? self.numberOfAudioChannels : @2);
  NSNumber *sampleRate    = (self.audioSampleRate       ? self.audioSampleRate       : @44100.f);
  
  NSDictionary *audioSettings = @{
                                  AVNumberOfChannelsKey : (audioChannels ? audioChannels : @2),
                                  AVSampleRateKey       : (sampleRate    ? sampleRate    : @44100.0f)
                                  };
  
  
  // Initialize the audio recorder
  // Set output path of the audio file
  NSError *error = nil;
  
  audioOutPath = [NSString stringWithFormat:@"%@audio.caf",  NSTemporaryDirectory()];
  _audioRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:audioOutPath] settings:audioSettings error:&error];
  if (error && [self.delegate respondsToSelector:@selector(screenRecorder:audioRecorderSetupFailedWithError:)]) {
    // Let the delegate know that shit has happened.
    [self.delegate screenRecorder:self audioRecorderSetupFailedWithError:error];
    
    //kdd      [_audioRecorder release];
    _audioRecorder = nil;
    
    return;
  }
  
   [_audioRecorder setDelegate:self];
   [_audioRecorder prepareToRecord];
  
  // Start recording :P
    [_audioRecorder record];
}

void audio_open(void *cls, int bits, int channels, int samplerate, int isaudio)
{
  printf("=====audio========\n");
  
}


void audio_setvolume(void *cls,int volume)
{
  printf("=====audio====%d====\n",volume);
}


void audio_process(void *cls,const void *buffer, int buflen, double timestamp, uint32_t seqnum)
{
  printf("=====audio========\n");
}


void audio_stop(void *cls)
{
  
  printf("=====audio_stop========\n");
}

- (void)startRecordingScreen
{
  [self _setupAudio];
  airplay_callbacks_t ao;
  memset(&ao,0,sizeof(airplay_callbacks_t));
  ao.cls                          = (__bridge void *)self;
    
  ao.AirPlayMirroring_Play     = video_open;
  ao.AirPlayMirroring_Process  = video_process;
  ao.AirPlayMirroring_Stop     = video_stop;
  
  ao.AirPlayAudio_Init         = audio_open;
  ao.AirPlayAudio_SetVolume    = audio_setvolume;
  ao.AirPlayAudio_Process      = audio_process;
  ao.AirPlayAudio_destroy      = audio_stop;
  
  int ret = XinDawn_StartMediaServer("XBMC-GAMEBOX(XinDawn)",1920, 1080, 60, 47000,7100,"000000000", &ao);
  
  NSLog(@"Start Media Server with return %d\n",ret);
}

- (void)_finishEncoding
{
  
  // Stop the audio recording
  [_audioRecorder stop];
  _audioRecorder = nil;
  
  //[self addAudioTrackToRecording];
  
  //NSError *sessionError = nil;
  //[[AVAudioSession sharedInstance] setActive:NO error:&sessionError];
  
  
  
}

- (void)stopRecordingScreen
{
  [self _finishEncoding];
  XinDawn_StopMediaServer();
  NSLog(@"Stop Media Server \n");
}
@end
