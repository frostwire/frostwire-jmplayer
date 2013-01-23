//
//  OwnerWrapper.h
//  JMPlayer
//
//  Created by Alden Torres on 1/23/13.
//
//

#import <Foundation/Foundation.h>

#include "jni.h"

@interface OwnerWrapper : NSObject
{
    jobject owner;
    jclass  cls;
    jmethodID changeVolumeID;
    jmethodID volumeIncrementID;
    jmethodID volumeDecrementID;
    jmethodID seekToTimeID;
    jmethodID playPressedID;
    jmethodID pausePressedID;
    jmethodID fastForwardPressedID;
    jmethodID rewindPressedID;
    jmethodID toggleFullscreenPressedID;
    jmethodID progressSliderStartedID;
    jmethodID progressSliderEndedID;
}

-(id) initWithOwner:(jobject) theOwner;
-(void) OnVolumeChanged:(float) volume;
-(void) OnIncrementVolumePressed;
-(void) OnDecrementVolumePressed;
-(void) OnSeekToTime:(float) seconds;
-(void) OnPlayPressed;
-(void) OnPausePressed;
-(void) OnFastForwardPressed;
-(void) OnRewindPressed;
-(void) OnToggleFullscreenPressed;
-(void) OnProgressSliderStarted;
-(void) OnProgressSliderEnded;

@end
