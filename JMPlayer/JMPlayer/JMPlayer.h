/*
 * Created by Alden Torres (aldenml)
 * Copyright (c) 2012, FrostWire(R). All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <Foundation/Foundation.h>

#import <JavaVM/jni.h>
#import <JavaVM/AWTCocoaComponent.h>
#import <AppKit/AppKit.h>

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <QuartzCore/QuartzCore.h>

//include for shared memory
#include <sys/mman.h>

#import "MPlayerVideoRenderer.h"
#import "PlayerFullscreenWindow.h"
#import "ProgressSlider.h"

#import "Debug.h"

#ifdef __cplusplus
extern "C" {
#endif
    
    JNIEXPORT jlong JNICALL Java_com_frostwire_gui_mplayer_MPlayerComponent_createNSView1(JNIEnv *, jobject);
    
#ifdef __cplusplus
}
#endif

#define		WSM_SCALE		1
#define		WSM_FIT_SCREEN	2
#define		WSM_FIT_WIDTH	3

enum {
	MPEScaleModeZoomToFit,
	MPEScaleModeZoomToFill,
	MPEScaleModeStretchToFill
};
typedef NSUInteger MPEVideoScaleMode;

enum {
    JMPlayer_addNotify       = 1,
    JMPlayer_dispose         = 2,
    JMPlayer_volumeChanged   = 3,
    JMPlayer_timeInitialized = 4,
    JMPlayer_progressChanged = 5,
    JMPlayer_stateChanged    = 6,
    JMPlayer_toggleFS        = 7
};

enum {
    JMPlayer_statePlaying = 1,
    JMPlayer_statePaused = 2,
    JMPlayer_stateClosed = 3
};

@interface JMPlayer : NSOpenGLView <MPlayerVideoRenderereDelegateProtocol, AWTCocoaComponent, MusicPlayerClientProtocol>
{
    jobject jowner;
    
    MPlayerVideoRenderer *renderer;
    
    BOOL isFullscreen;
	BOOL switchingToFullscreen;
	BOOL switchingInProgress;
    BOOL isOntop;
    
    NSString *buffer_name;
    
	CGLContextObj ctx;
    
    // window dragging
	NSPoint dragStartPoint;
    
    // fullscreen switching
    NSRect old_win_frame;
	NSSize old_win_size;
	NSRect old_view_frame;
    
    // screen blacking
	NSMutableArray *blackingWindows;
    
    //video texture
	NSSize video_size;
	float video_aspect;
	float org_video_aspect;
    
    // zoom factor
	float zoomFactor;
	// fit width
	int fitWidth;
    
    int windowSizeMode;
    MPEVideoScaleMode videoScaleMode;
    
    // animations
	unsigned int runningAnimations;
    
    IBOutlet PlayerFullscreenWindow* fullscreenWindow;
   	NSWindow* playerWindow;
    NSView* playerSuperView;
}

@property (nonatomic, retain) id<MusicPlayerProtocol> player;
@property (nonatomic, retain) ProgressSlider* progressSlider;
@property (nonatomic, retain) NSString* appPath;


- (id) initWithFrame: (jobject) owner frame:(NSRect) frame applicationPath:(NSString*) applicationPath;

// Render Thread methods
- (void) toggleFullscreen;
- (void) finishToggleFullscreen;

- (void) setFrame:(NSRect)frame onWindow:(NSWindow *)window;
- (NSString *)bufferName;
- (BOOL) isFullscreen;

- (NSRect) videoFrame;
- (void) reshape;
- (void) close;
- (void) finishClosing;
- (void) updateOntop;
- (void) startRenderingWithSize:(NSValue *)sizeValue;
- (void) fullscreenWindowMoved:(NSNotification *)notification;

// --- MusicPlayerClientProtocol ---
-(void)onVolumeChanged:(CGFloat)volume;
-(void)onSeekToTime:(float)seconds;
-(void)onPlayPressed;
-(void)onPausePressed;
-(void)onFastForwardPressed;
-(void)onRewindPressed;
-(void)onToggleFullscreenPressed;
-(void)onProgressSliderStarted;
-(void)onProgressSliderEnded;
@end
