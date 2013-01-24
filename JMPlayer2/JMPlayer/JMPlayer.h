//
//  JMPlayer.h
//  JMPlayer
//
//  Created by Alden Torres on 1/21/13.
//
//

#import <Foundation/Foundation.h>

#import "jni.h"

#import <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <QuartzCore/QuartzCore.h>

#include <sys/mman.h>

#import "MPlayerVideoRenderer.h"
#import "PlayerFullscreenWindow.h"
#import "ProgressSlider.h"
#import "Debug.h"
#import "OwnerWrapper.h"

#ifdef __cplusplus
extern "C" {
#endif
    
    JNIEXPORT jlong JNICALL Java_com_frostwire_gui_mplayer_MPlayerComponentOSX2_createNSView(JNIEnv *, jobject);
    JNIEXPORT void JNICALL Java_com_frostwire_gui_mplayer_MPlayerComponentOSX2_awtMessage(JNIEnv *, jobject, jlong view, jint messageID, jobject message);
    
#ifdef __cplusplus
}
#endif

#define		WSM_SCALE		1
#define		WSM_FIT_SCREEN	2
#define		WSM_FIT_WIDTH	3

enum
{
	MPEScaleModeZoomToFit,
	MPEScaleModeZoomToFill,
	MPEScaleModeStretchToFill
};

typedef NSUInteger MPEVideoScaleMode;

enum
{
    JMPlayer_addNotify       = 1,
    JMPlayer_dispose         = 2,
    JMPlayer_volumeChanged   = 3,
    JMPlayer_timeInitialized = 4,
    JMPlayer_progressChanged = 5,
    JMPlayer_stateChanged    = 6,
    JMPlayer_toggleFS        = 7
};

enum
{
    JMPlayer_statePlaying = 1,
    JMPlayer_statePaused = 2,
    JMPlayer_stateClosed = 3
};

@interface JMPlayer : NSOpenGLView <MPlayerVideoRenderereDelegateProtocol, MusicPlayerClientProtocol>
{
    jobject jowner;
    OwnerWrapper* owner;
    
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
    
    BOOL mouseIsOver;
}

@property (nonatomic)           int playerState;
@property (nonatomic, retain)   id<MusicPlayerProtocol> player;
@property (nonatomic, retain)   ProgressSlider* progressSlider;
@property (nonatomic) BOOL mouseIsOver;

- (id) initWithFrame: (JNIEnv*) env theOwner: (jobject) theOwner frame:(NSRect) frame;

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
-(void)onIncrementVolumePressed;
-(void)onDecrementVolumePressed;
-(void)onSeekToTime:(float)seconds;
-(void)onPlayPressed;
-(void)onPausePressed;
-(void)onFastForwardPressed;
-(void)onRewindPressed;
-(void)onToggleFullscreenPressed;
-(void)onProgressSliderStarted;
-(void)onProgressSliderEnded;

@end
