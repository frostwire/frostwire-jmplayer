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

#import "JMPlayer.h"
#import "JNIInterface.h"

#import <Carbon/Carbon.h>
#import <Foundation/NSByteOrder.h>

#import "CocoaAdditions.h"

JavaVM* jvm = NULL;

jint GetJNIEnv(JNIEnv **env, bool *mustDetach);

static NSString *VVAnimationsDidEnd = @"VVAnimationsDidEnd";

@implementation JMPlayer

@synthesize appPath, progressSlider, playerState;

- (id) initWithFrame: (jobject) owner frame:(NSRect) frame applicationPath:(NSString*) applicationPath
{
	self = [super initWithFrame:frame];
    jowner = owner;
    
    appPath = applicationPath;
    
	buffer_name = [@"fwmplayer" retain];
    
    // initialize renderer
    renderer = [[MPlayerVideoRenderer alloc] initWithContext:[self openGLContext] andConnectionName:buffer_name];
	[renderer setDelegate:self];
    ctx = (CGLContextObj)[[self openGLContext] CGLContextObj];

    fullscreenWindow = [[PlayerFullscreenWindow alloc] initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered  jmPlayer:self defer:NO ];

    return self;
}

-(void)awtMessage:(jint)messageID message:(jobject)message env:(JNIEnv*)env
{
    switch (messageID) {
        case JMPlayer_volumeChanged:
            [fullscreenWindow setVolume:(float)JNIInterface::GetInstance().getJNIFloatValue(message)];
            break;
        case JMPlayer_progressChanged:
            [fullscreenWindow setCurrentTime:(float)JNIInterface::GetInstance().getJNIFloatValue(message)];
            break;
        case JMPlayer_stateChanged:
            [self setPlayerState:JNIInterface::GetInstance().getJNIIntValue(message)];
            [fullscreenWindow setState:[self playerState]];
            break;
        case JMPlayer_timeInitialized:
            [fullscreenWindow setMaxTime:(float)JNIInterface::GetInstance().getJNIFloatValue(message)];
            break;
        case JMPlayer_toggleFS:
            [self toggleFullscreen];
            break;
        case JMPlayer_addNotify:
            break;
        case JMPlayer_dispose:
            if(jowner != NULL){
                env->DeleteGlobalRef(jowner);
                jowner = NULL;
            }
            break;
        default:
            fprintf(stderr, "JMPlayer Error : Unknown message received (%d)\n", (int) messageID);
            break;
    }
}

- (void) dealloc
{
	[buffer_name release];
	[renderer release];
    
	[super dealloc];
}

/*
 Return if currently in fullscreen
 */
- (BOOL) isFullscreen
{
	return isFullscreen;
}

- (NSString *)bufferName
{
	return [[buffer_name retain] autorelease];
}

- (void)startRenderingWithSize:(NSValue *)sizeValue {
    
	video_size = [sizeValue sizeValue];
	video_aspect = org_video_aspect = video_size.width / video_size.height;
    
	[self reshape];
}

/*
 Calculate bounds for video
 */
- (NSRect) videoFrame
{
	NSRect displayFrame = [self bounds];
	NSRect videoFrame = displayFrame;
    
	// Display frame is video frame for stretch to fill
	if (videoScaleMode == MPEScaleModeStretchToFill)
		return videoFrame;
    
	// Video is taller than display frame if aspect is smaller -> Fit height
	BOOL fitHeight = (video_aspect < (displayFrame.size.width / displayFrame.size.height));
    
	// Reverse for zoom to fill
	if (videoScaleMode == MPEScaleModeZoomToFill)
		fitHeight = !fitHeight;
    
	if (fitHeight)
		videoFrame.size.width = videoFrame.size.height * video_aspect;
	else
		videoFrame.size.height = videoFrame.size.width * (1 / video_aspect);
    
	// Center video
	videoFrame.origin.x = (displayFrame.size.width - videoFrame.size.width) / 2;
	videoFrame.origin.y = (displayFrame.size.height - videoFrame.size.height) / 2;
    
	return videoFrame;
}

/*
 View changed: synchronized call to the renderer
 */
- (void) reshape
{
	[renderer boundsDidChangeTo:[self bounds] withVideoFrame:[self videoFrame]];
}

- (void) update
{
	CGLLockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
	[[self openGLContext] update];
	CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
}

- (void) drawRect: (NSRect) bounds
{
	[renderer redraw];
}

/*
 Toggle fullscreen on the gui side
 */
- (void) toggleFullscreen
{
	// wait until finished before switching again
	if (switchingInProgress)
		return;
	switchingInProgress = YES;
	
    if(!isFullscreen) {
		switchingToFullscreen = YES;
	} else {
		switchingToFullscreen = NO;
		isFullscreen = NO;
	}
	
    
    if (playerWindow == nil) {
        playerWindow = [self window];
    }
    
    if (playerSuperView == nil) {
        playerSuperView = [self superview];
    }
    
    
    NSUInteger fullscreenId = [[NSScreen screens] indexOfObject:[playerWindow screen]];
    NSRect screen_frame = [[[NSScreen screens] objectAtIndex:fullscreenId] frame];
	
	if (switchingToFullscreen) {
		
		// hide menu and dock if on same screen
		if (fullscreenId == 0)
            SetSystemUIMode( kUIModeAllSuppressed, 0);
		
		// place fswin above video in player window
        NSRect rect = [self convertRect:[self frame] toView:nil];
		rect = [playerWindow convertRectToScreen: rect];
		[fullscreenWindow setFrame:rect display:NO animate:NO];
		
		[fullscreenWindow makeKeyAndOrderFront:nil];
		[self updateOntop];
		
		[fullscreenWindow setFullscreen:YES];
		
		// Save current frame for back transition
		old_win_frame = fullscreenWindow.frame;
		// save window size for back transition
		old_win_size = fullscreenWindow.frame.size;
		// save current view for back transition
        
		// move view to fswin and redraw to avoid flicker
		[self removeFromSuperview];
        [fullscreenWindow setContentView:self];
        [playerSuperView setNeedsDisplay:NO];
        [self display];
        
        [self setFrame:screen_frame onWindow:fullscreenWindow];
		
        [self finishToggleFullscreen];
        
	} else {
		
		[playerWindow orderWindow:NSWindowBelow relativeTo:[fullscreenWindow windowNumber]];
		[playerWindow makeKeyWindow];
		
		[fullscreenWindow setFullscreen:NO];
		[fullscreenWindow stopMouseTracking];
		
		[self setFrame:old_win_frame onWindow:fullscreenWindow];
		
		[self finishToggleFullscreen];
	}
}

- (void) finishToggleFullscreen
{
	
    NSUInteger fullscreenId = [[NSScreen screens] indexOfObject:[playerWindow screen]];
    
	if (switchingToFullscreen) {
		
        [fullscreenWindow startMouseTracking];
		
	} else {
		
        [self removeFromSuperview];
		[playerSuperView addSubview:self];
        
        [fullscreenWindow orderOut:nil];
		
		//exit kiosk mode
        if ( fullscreenId == 0)
            SetSystemUIMode( kUIModeNormal, 0);
    }
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:VVAnimationsDidEnd object:nil];
	
	if (switchingToFullscreen)
		isFullscreen = YES;
	
	[self reshape];
	switchingInProgress = NO;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MIFullscreenSwitchDone"
														object:self
													  userInfo:nil];
}

/*
 Close OpenGL view
 */
- (void) close
{
	// exit fullscreen and close with callback
	if (isFullscreen) {
		
		[self toggleFullscreen];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(finishClosing)
                                                     name: @"MIFullscreenSwitchDone"
                                                   object: self];
		
		return;
	}
	
	// not fullscreen: close immediately
	[self finishClosing];
}

- (void) finishClosing
{
	video_size = NSZeroSize;
	video_aspect = org_video_aspect = 0;
	
	// close video view
	NSRect frame = [[self window] frame];
	frame.size = [playerWindow contentMinSize];
	frame = [playerWindow frameRectForContentRect:frame];
	[[self window] setFrame:frame display:YES animate:YES];
	
	// remove fullscreen callback
	[[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name: @"MIFullscreenSwitchDone"
                                                  object: self];
	
	// post view closed notification
	[[NSNotificationCenter defaultCenter]
     postNotificationName:@"MIVideoViewClosed"
     object:self
     userInfo:nil];
}

- (void) updateOntop
{
	if ( [fullscreenWindow isVisible] ) {
		NSInteger level = NSModalPanelWindowLevel;
		level = NSScreenSaverWindowLevel;
		
		[fullscreenWindow setLevel:level];
		[playerWindow orderWindow:NSWindowBelow relativeTo:[fullscreenWindow windowNumber]];
	} else {
		[fullscreenWindow setLevel:NSNormalWindowLevel];
    }
}

- (void) setFrame:(NSRect)frame onWindow:(NSWindow *)window
{
	// apply directly if animations are disabled
	[window setFrame:frame display:YES animate:YES];
    return;
    
}

- (void) fullscreenWindowMoved:(NSNotification *)notification
{
	// triggered when fullscreen window changes spaces
	NSRect screen_frame = [[[NSScreen screens] objectAtIndex:0] frame];
	[fullscreenWindow setFrame:screen_frame display:YES animate:NO];
}


/*
 * Music Player client notifications.
 */

-(void)onVolumeChanged:(CGFloat)volume {
    JNIInterface::GetInstance().OnVolumeChanged(volume);
}

-(void)onSeekToTime:(float)seconds {
    JNIInterface::GetInstance().OnSeekToTime(seconds);
}

-(void)onPlayPressed {
    JNIInterface::GetInstance().OnPlayPressed();
}

-(void)onPausePressed {
    JNIInterface::GetInstance().OnPausePressed();
}

-(void)onFastForwardPressed {
    JNIInterface::GetInstance().OnFastForwardPressed();
}

-(void)onRewindPressed {
    JNIInterface::GetInstance().OnRewindPressed();
}

-(void)onToggleFullscreenPressed {
    JNIInterface::GetInstance().OnToggleFullscreenPressed();
}

-(void)onProgressSliderStarted {
    JNIInterface::GetInstance().OnProgressSliderStarted();
}

-(void)onProgressSliderEnded {
    JNIInterface::GetInstance().OnProgressSliderEnded();
}

-(void)onIncrementVolumePressed {
    JNIInterface::GetInstance().OnIncrementVolumePressed();
}

-(void)onDecrementVolumePressed {
    JNIInterface::GetInstance().OnDecrementVolumePressed();
}

@end

#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    jvm = vm;
    return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL JNI_OnUnload(JavaVM *vm, void *reserved) {
}

JNIEXPORT jlong JNICALL Java_com_frostwire_gui_mplayer_MPlayerComponentOSX_createNSView1
(JNIEnv *env, jobject obj, jstring appPath) {
    JMPlayer* view = nil;
    NS_DURING;
    int width = 200;
    int height = 200;
    
    jobject jowner = (env)->NewGlobalRef(obj);
    
    JNIInterface::GetInstance().Initialize(env, jowner);
    
    // prepare application Path
    const char *charPath = env->GetStringUTFChars(appPath, NULL);//Java String to C Style string
    NSString *pathNSString = [[[NSString alloc] initWithUTF8String:charPath] autorelease];
    
    view = [[JMPlayer alloc] initWithFrame : jowner frame:NSMakeRect(0, 0, width, height) applicationPath: pathNSString];
    
    env->ReleaseStringUTFChars(appPath, charPath);
    
    NS_HANDLER;
    fprintf(stderr, "ERROR : Failed to create JMPlayer view\n");
    NS_VALUERETURN(0, jlong);
    NS_ENDHANDLER;
    
    return (jlong) view;
}

jint GetJNIEnv(JNIEnv **env, bool *mustDetach) {
	jint getEnvErr = JNI_OK;
	*mustDetach = false;
	if (jvm) {
		getEnvErr = jvm->GetEnv((void **)env, JNI_VERSION_1_4);
		if (getEnvErr == JNI_EDETACHED) {
			getEnvErr = jvm->AttachCurrentThread((void **)env, NULL);
			if (getEnvErr == JNI_OK) {
				*mustDetach = true;
			}
		}
	}
	return getEnvErr;
}
    
#ifdef __cplusplus
}
#endif

