//
//  JMPlayer.h
//  JMPlayer
//
//  Created by Alden Torres on 8/18/12.
//
//

#import <Foundation/Foundation.h>

#import <JavaVM/jni.h>
#import <JavaVM/AWTCocoaComponent.h>
#import <AppKit/AppKit.h>

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <QuartzCore/QuartzCore.h>

//include for shared memory
#include <sys/mman.h>

//#include "JNIInterface.h"

#import "MPlayerVideoRenderer.h"
#import "PlayerFullscreenWindow.h"
#import "ProgressSlider.h"
#import "FullscreenControls.h"

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


@class FullscreenControls;

enum {
    JMPlayer_addNotify       = 1,
    JMPlayer_dispose         = 2,
    JMPlayer_toggleFS        = 3
};

@interface JMPlayer : NSOpenGLView <MPlayerVideoRenderereDelegateProtocol, AWTCocoaComponent, MusicPlayerClientProtocol>
{
    jobject jowner;
    //JNIInterface* jniInterface;
    
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
   	//IBOutlet NSWindow *fcControlWindow;
    NSWindow* playerWindow;
    NSView* playerSuperView;
    
    // === PlayerController ===
    // Fullscreen controls
	IBOutlet FullscreenControls *fullScreenControls;
}

@property (nonatomic, retain) id<MusicPlayerProtocol> player;
@property (nonatomic, retain) ProgressSlider* progressSlider;
@property (nonatomic, retain) NSString* appPath;


- (id) initWithFrame: (jobject) owner frame:(NSRect) frame applicationPath:(NSString*) applicationPath;

// Render Thread methods
- (void) toggleFullscreen;
- (void) finishToggleFullscreen;

// Helper methods
- (void) setFrame:(NSRect)frame onWindow:(NSWindow *)window blocking:(BOOL)blocking;

// Main Thread methods
- (NSString *)bufferName;

- (BOOL) isFullscreen;
//- (void) blackScreensExcept:(int)fullscreenId;
//- (void) unblackScreens;

// new:
- (NSRect) videoFrame;
- (void) reshape;
- (void) resizeView;
- (void) reshapeAndResize;
- (void) close;
- (void) finishClosing;
- (void) setWindowSizeMode:(int)mode withValue:(float)val;
- (void) setOntop:(BOOL)ontop;

- (void) updateOntop;

// new:
- (void) setAspectRatio:(float)aspect;
//- (void) setAspectRatioFromPreferences;
- (void) setVideoScaleMode:(MPEVideoScaleMode)scaleMode;

- (void) fullscreenWindowMoved:(NSNotification *)notification;

// --- MusicPlayerClientProtocol ---
-(void)onVolumeChanged:(CGFloat)volume;
-(void)onSeekToTime:(CGFloat)seconds;
-(void)onPlayPressed;
-(void)onPausePressed;
-(void)onFastForwardPressed;
-(void)onRewindPressed;

// === from AppController ===
- (BOOL) animateInterface;

// === from PlayerController ===
- (void) syncWindows:(BOOL)switchingToFullscreen;

@end
