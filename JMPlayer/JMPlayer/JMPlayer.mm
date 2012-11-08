//
//  JMPlayer.m
//  JMPlayer
//
//  Created by Alden Torres on 8/18/12.
//
//

#import "JMPlayer.h"
#import "JNIInterface.h"

#import <Carbon/Carbon.h>
#import <Foundation/NSByteOrder.h>

#import "FullscreenControls.h"

#import "CocoaAdditions.h"

#define JRISigArray(T)		"[" T
#define JRISigByte			"B"
#define JRISigChar			"C"
#define JRISigClass(name)	"L" name ";"
#define JRISigFloat			"F"
#define JRISigDouble		"D"
#define JRISigMethod(args)	"(" args ")"
#define JRISigNoArgs		""
#define JRISigInt			"I"
#define JRISigLong			"J"
#define JRISigShort			"S"
#define JRISigVoid			"V"
#define JRISigBoolean		"Z"

JavaVM* jvm = NULL;

jint GetJNIEnv(JNIEnv **env, bool *mustDetach);

static NSString *VVAnimationsDidEnd = @"VVAnimationsDidEnd";

@implementation JMPlayer

@synthesize appPath, progressSlider;

- (id) initWithFrame: (jobject) owner frame:(NSRect) frame applicationPath:(NSString*) applicationPath
{
	self = [super initWithFrame:frame];
    jowner = owner;
    
    //jniInterface = JNIInterface::GetInstance();
    
    appPath = applicationPath;
    
	buffer_name = [@"fwmplayer" retain];
    
    // initialize self
    [self awakeFromNib];

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
            [fullscreenWindow setState:(int)JNIInterface::GetInstance().getJNIIntValue(message)];
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

- (void) awakeFromNib
{
	renderer = [[MPlayerVideoRenderer alloc] initWithContext:[self openGLContext] andConnectionName:buffer_name];
	[renderer setDelegate:self];
    
    ctx = (CGLContextObj)[[self openGLContext] CGLContextObj];
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
 Resize OpenGL view to fit movie
 */
- (void) resizeView
{
	
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
 Set video scale mode
 */
- (void) setVideoScaleMode:(MPEVideoScaleMode)scaleMode
{
	videoScaleMode = scaleMode;
	
	[self reshape];
}

/*
 Set aspect ratio
 */
- (void)setAspectRatio:(float)aspect
{
	if (aspect > 0)
		video_aspect = aspect;
	else
		video_aspect = org_video_aspect;
	
	[self reshapeAndResize];
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
		
		[self syncWindows:YES];
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
        //[fullscreenWindow orderFront:NSApp];
		//[self drawRect:[self convertRectToBacking: [self frame]]];
        [playerSuperView setNeedsDisplay:NO];
        [self display];
        
        [self setFrame:screen_frame onWindow:fullscreenWindow blocking:NO];
		
        /*
		NSRect frame = [playerWindow frame];
		frame.size = [playerWindow contentMinSize];
		frame = [playerWindow frameRectForContentRect:frame];
		*/
		
        //[self setFrame:frame onWindow:playerWindow blocking:NO];
		
        //[self blackScreensExcept:0];
        
		// wait for animation to finish
		//if ([self animateInterface]) {
		//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishToggleFullscreen)
		//												 name:VVAnimationsDidEnd object:self];
		//} else
        [self finishToggleFullscreen];
        
	} else {
		
		// unhide player window
		/*
		NSRect win_frame = [playerWindow frame];
		win_frame.size = old_win_size;
		*/
        
		//[self setFrame:win_frame onWindow:playerWindow blocking:NO];
		
		// move player window below fullscreen window
		//[self syncWindows:NO];
		[playerWindow orderWindow:NSWindowBelow relativeTo:[fullscreenWindow windowNumber]];
		[playerWindow makeKeyWindow];
		
		[fullscreenWindow setFullscreen:NO];
		[fullscreenWindow stopMouseTracking];
		
		// resize fullscreen window back onto video view
		//NSRect rect = [playerWindow convertRectToScreen:old_win_frame];
		
		[self setFrame:old_win_frame onWindow:fullscreenWindow blocking:NO];
		
		//[self unblackScreens];
		
		// wait for animation to finish
		//if ([self animateInterface]) {
		//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishToggleFullscreen)
		//												 name:VVAnimationsDidEnd object:self];
		//} else
        [self finishToggleFullscreen];
	}
}

- (void) finishToggleFullscreen
{
	
    NSUInteger fullscreenId = [[NSScreen screens] indexOfObject:[playerWindow screen]];
    
	if (switchingToFullscreen) {
		
		// hide player window
		//if ([playerWindow screen] == [fullscreenWindow screen])
		//[playerWindow orderOut:self];
		
		[fullscreenWindow startMouseTracking];
		
	} else {
		
        //NSView* tmp = [self retain];
        
        [self removeFromSuperview];
		[playerSuperView addSubview:self];
        
        //[tmp release];
        
        [fullscreenWindow orderOut:nil];
		
		// move view back, place and redraw
		//[self setFrame:old_view_frame];
		//[self drawRect:old_view_frame];
		
		//exit kiosk mode
        if ( fullscreenId == 0)
            SetSystemUIMode( kUIModeNormal, 0);
		
		// reset drag point
		//dragStartPoint = NSZeroPoint;
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

- (void)syncWindows: (BOOL)toFullscreen
{
	// Make sure the player and fullscreen windows are on the same space
	NSInteger playerLevel = [playerWindow level];
	//NSInteger fullsceenLevel = [fullScreenControls level];
	
	if (toFullscreen) {
		//[playerWindow addChildWindow:[fullScreenControls window] ordered:NSWindowAbove];
		//[playerWindow removeChildWindow:[fullScreenControls window]];
	} else {
		//[[fullScreenControls window] addChildWindow:playerWindow ordered:NSWindowBelow];
		//[[fullScreenControls window] removeChildWindow:playerWindow];
	}
	
	[playerWindow setLevel:playerLevel];
	//[fullScreenControls setLevel:fullsceenLevel];
}

/*
 Reshape and then resize View
 */
- (void) reshapeAndResize
{
	[self reshape];
	[self resizeView];
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
	[[self window] setFrame:frame display:YES animate:[self animateInterface]];
	
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

/*
 Resize Window with given options
 */
- (void) setWindowSizeMode:(int)mode withValue:(float)val
{
	windowSizeMode = mode;
	
	if (windowSizeMode == WSM_SCALE)
		zoomFactor = val;
	else if (windowSizeMode == WSM_FIT_WIDTH)
		fitWidth = val;
	
	// do not apply if not playing
	if (video_size.width == 0)
		return;
	
	// exit fullscreen first and finish with callback
	if (isFullscreen) {
		
		[[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(resizeView)
                                                     name: @"MIFullscreenSwitchDone"
                                                   object: self];
		
	} else
		// not in fullscreen: resize now
		[self resizeView];
}

/*
 Set Ontop (sent by PlayerController)
 */
- (void) setOntop:(BOOL)ontop
{
	isOntop = ontop;
	[self updateOntop];
}

- (void) updateOntop
{
	//if ([fullscreenWindow isVisible] && (isOntop || [PREFS boolForKey:MPEFullscreenBlockOthers])) {
    if ( [fullscreenWindow isVisible] ) {
		NSInteger level = NSModalPanelWindowLevel;
		//if ([PREFS boolForKey:MPEFullscreenBlockOthers]) // assume YES
		level = NSScreenSaverWindowLevel;
		
		[fullscreenWindow setLevel:level];
		//[fcControlWindow  setLevel:level];
		
		//[fullscreenWindow orderWindow:NSWindowBelow relativeTo:[fcControlWindow windowNumber]];
		[playerWindow orderWindow:NSWindowBelow relativeTo:[fullscreenWindow windowNumber]];
	} else {
		[fullscreenWindow setLevel:NSNormalWindowLevel];
		//[fcControlWindow  setLevel:NSNormalWindowLevel];
	}
}


- (void) setFrame:(NSRect)frame onWindow:(NSWindow *)window blocking:(BOOL)blocking
{
	// apply directly if animations are disabled
	[window setFrame:frame display:YES animate:[self animateInterface]];
    return;
    
    /*
	NSViewAnimation *anim;
	NSMutableDictionary *animInfo;
	
	animInfo = [NSMutableDictionary dictionaryWithCapacity:3];
	[animInfo setObject:window forKey:NSViewAnimationTargetKey];
	[animInfo setObject:[NSValue valueWithRect:[window frame]] forKey:NSViewAnimationStartFrameKey];
	[animInfo setObject:[NSValue valueWithRect:frame] forKey:NSViewAnimationEndFrameKey];
	
	anim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:animInfo]];
	[anim setDelegate:self];
	
	[anim setDuration:[window animationResizeTime:frame]];
	if (!blocking)
		[anim setAnimationBlockingMode:NSAnimationNonblocking];
	else
		[anim setAnimationBlockingMode:NSAnimationBlocking];
	
	[anim startAnimation];
	[anim release];
	
	runningAnimations++;
    */
}

- (void) fullscreenWindowMoved:(NSNotification *)notification
{
	// triggered when fullscreen window changes spaces
	NSRect screen_frame = [[[NSScreen screens] objectAtIndex:0] frame];
	[fullscreenWindow setFrame:screen_frame display:YES animate:NO];
}
/*
- (void) blackScreensExcept:(int)fullscreenId
{
	[blackingWindows release];
	blackingWindows = [[NSMutableArray alloc] initWithCapacity:[[NSScreen screens] count]];
	
	unsigned int i;
	NSWindow *win;
	NSRect fs_rect;
	for (i = 0; i < [[NSScreen screens] count]; i++) {
		// don't black fullscreen screen
		if (i == fullscreenId)
			continue;
		// when blacking the main screen, hide the menu bar and dock
		if (i == 0)
			SetSystemUIMode( kUIModeAllSuppressed, 0);
		
		fs_rect = [[[NSScreen screens] objectAtIndex:i] frame];
		fs_rect.origin = NSZeroPoint;
		win = [[NSWindow alloc] initWithContentRect:fs_rect styleMask:NSBorderlessWindowMask
											backing:NSBackingStoreBuffered defer:NO screen:[[NSScreen screens] objectAtIndex:i]];
		[win setBackgroundColor:[NSColor blackColor]];
		//if ([PREFS boolForKey:MPEFullscreenBlockOthers]) // assume YES
			[win setLevel:NSScreenSaverWindowLevel];
		//else
		//	[win setLevel:NSModalPanelWindowLevel];
		
        [win orderFront:nil];
		
		if ([self animateInterface])
			[self fadeWindow:win withEffect:NSViewAnimationFadeInEffect];
		
		[blackingWindows addObject:win];
		[win release];
	}
	
}
*/
 
/*
 Remove black out windows
 */
/*
 - (void) unblackScreens
{
	if (!blackingWindows)
		return;
	
	unsigned int i;
	for (i = 0; i < [blackingWindows count]; i++) {
		if (![self animateInterface])
			[[blackingWindows objectAtIndex:i] close];
		else
			[self fadeWindow:[blackingWindows objectAtIndex:i] withEffect:NSViewAnimationFadeOutEffect];
	}
	
	[blackingWindows release];
	blackingWindows = nil;
}
*/

// animate interface transitions
- (BOOL) animateInterface
{
    /*
	if ([[self preferences] objectForKey:MPEAnimateInterfaceTransitions])
		return [[self preferences] boolForKey:MPEAnimateInterfaceTransitions];
	else
     */
	return YES;
}

/*
 Animate window fading in/out
 */
/*
- (void) fadeWindow:(NSWindow *)window withEffect:(NSString *)effect
{
	
	NSViewAnimation *anim;
	NSMutableDictionary *animInfo;
	
	animInfo = [NSMutableDictionary dictionaryWithCapacity:2];
	[animInfo setObject:window forKey:NSViewAnimationTargetKey];
	[animInfo setObject:effect forKey:NSViewAnimationEffectKey];
	
	anim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:animInfo]];
	[anim setAnimationBlockingMode:NSAnimationNonblockingThreaded];
	[anim setAnimationCurve:NSAnimationEaseIn];
	[anim setDuration:0.3];
	
	[anim startAnimation];
	[anim release];
}
*/
/*
 Handle animations ending `
 */
/*
- (void)animationDidEnd:(NSAnimation *)animation {
	
	runningAnimations--;
	
	if (runningAnimations == 0)
		[[NSNotificationCenter defaultCenter] postNotificationName:VVAnimationsDidEnd object:self];
}
*/



/*
 * Music Player client notifications.
 */

-(void)onVolumeChanged:(CGFloat)volume {
    JNIInterface::GetInstance().OnVolumeChanged(volume);
}

-(void)onSeekToTime:(CGFloat)seconds {
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

