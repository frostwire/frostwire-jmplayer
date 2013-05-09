//
//  JMPlayer.m
//  JMPlayer
//
//  Created by Alden Torres on 1/21/13.
//
//

#import "JMPlayer.h"

#import <Cocoa/Cocoa.h>

#import <Carbon/Carbon.h>
#import <Foundation/NSByteOrder.h>

#import "CocoaAdditions.h"

static NSString *VVAnimationsDidEnd = @"VVAnimationsDidEnd";

@implementation JMPlayer

@synthesize progressSlider;
@synthesize playerState;
@synthesize mouseIsOver;

- (id) initWithFrame: (JNIEnv*) env theOwner: (jobject) theOwner frame:(NSRect) frame imagesPath : (NSString*) imagesPath
{
	self = [super initWithFrame:frame];
    jowner = theOwner;
    owner = [[OwnerWrapper alloc] initWithOwner:env theOwner:theOwner];
    
	buffer_name = [@"fwmplayer" retain];
    
    // initialize renderer
    renderer = [[MPlayerVideoRenderer alloc] initWithContext:[self openGLContext] andConnectionName:buffer_name];
	[renderer setDelegate:self];
    ctx = (CGLContextObj)[[self openGLContext] CGLContextObj];
    
    fullscreenWindow = [[PlayerFullscreenWindow alloc] initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered  jmPlayer:self defer:NO imagesPath:imagesPath];
    
    mouseIsOver = NO;
    
    int opts = (NSTrackingActiveAlways | NSTrackingInVisibleRect |  NSTrackingMouseMoved);
    area = [[NSTrackingArea alloc] initWithRect:[self bounds]
                                                        options:opts
                                                          owner:self
                                                       userInfo:nil];
    [self addTrackingArea:area];
    
    return self;
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
    {
		return videoFrame;
    }
    
	// Video is taller than display frame if aspect is smaller -> Fit height
	BOOL fitHeight = (video_aspect < (displayFrame.size.width / displayFrame.size.height));
    
	// Reverse for zoom to fill
	if (videoScaleMode == MPEScaleModeZoomToFill)
    {
		fitHeight = !fitHeight;
    }
    
	if (fitHeight)
    {
		videoFrame.size.width = videoFrame.size.height * video_aspect;
    }
	else
    {
		videoFrame.size.height = videoFrame.size.width * (1 / video_aspect);
    }
    
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
    {
		return;
    }
    
	switchingInProgress = YES;
	
    if(!isFullscreen)
    {
		switchingToFullscreen = YES;
	}
    else
    {
		switchingToFullscreen = NO;
		isFullscreen = NO;
	}
	
    if (playerWindow == nil)
    {
        playerWindow = [self window];
    }
    
    if (playerSuperView == nil)
    {
        playerSuperView = [self superview];
    }
    
    
    NSUInteger fullscreenId = [[NSScreen screens] indexOfObject:[playerWindow screen]];
    NSRect screen_frame = [[[NSScreen screens] objectAtIndex:fullscreenId] frame];
	
	if (switchingToFullscreen)
    {
		// hide menu and dock if on same screen
        if (fullscreenId == 0)
        {
            SetSystemUIMode(kUIModeAllSuppressed, 0);
        }
		
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
    
	if (switchingToFullscreen)
    {
        [fullscreenWindow startMouseTracking];
	}
    else
    {
        [self removeFromSuperview];
		[playerSuperView addSubview:self];
        
        [fullscreenWindow orderOut:nil];
		
		//exit kiosk mode
        if (fullscreenId == 0)
        {
            SetSystemUIMode(kUIModeNormal, 0);
        }
    }
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:VVAnimationsDidEnd object:nil];
	
	if (switchingToFullscreen)
    {
		isFullscreen = YES;
    }
	
	[self reshape];
	switchingInProgress = NO;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MIFullscreenSwitchDone" object:self userInfo:nil];
}

/*
 Close OpenGL view
 */
- (void) close
{
	if (isFullscreen) // exit fullscreen and close with callback
    {
		[self toggleFullscreen];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(finishClosing) name: @"MIFullscreenSwitchDone" object: self];
	}
    else // not fullscreen: close immediately
    {
        [self finishClosing];
    }
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
	[[NSNotificationCenter defaultCenter] removeObserver:self name: @"MIFullscreenSwitchDone" object: self];
	
	// post view closed notification
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MIVideoViewClosed" object:self userInfo:nil];
}

- (void) updateOntop
{
	if ([fullscreenWindow isVisible])
    {
		NSInteger level = NSModalPanelWindowLevel;
		level = NSScreenSaverWindowLevel;
		
		[fullscreenWindow setLevel:level];
		[playerWindow orderWindow:NSWindowBelow relativeTo:[fullscreenWindow windowNumber]];
	}
    else
    {
		[fullscreenWindow setLevel:NSNormalWindowLevel];
    }
}

- (void) setFrame:(NSRect)frame onWindow:(NSWindow *)window
{
	// apply directly if animations are disabled
	[window setFrame:frame display:YES animate:YES];
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
    [owner OnVolumeChanged:volume];
}

-(void)onSeekToTime:(float)seconds {
    [owner OnSeekToTime:seconds];
}

-(void)onPlayPressed {
    [owner OnPlayPressed];
}

-(void)onPausePressed
{
    [owner OnPausePressed];
}

-(void)onFastForwardPressed
{
    [owner OnFastForwardPressed];
}

-(void)onRewindPressed
{
    [owner OnRewindPressed];
}

-(void)onToggleFullscreenPressed
{
    [owner OnToggleFullscreenPressed];
}

-(void)onProgressSliderStarted
{
    [owner OnProgressSliderStarted];
}

-(void)onProgressSliderEnded
{
    [owner OnProgressSliderEnded];
}

-(void)onIncrementVolumePressed
{
    [owner OnIncrementVolumePressed];
}

-(void)onDecrementVolumePressed
{
    [owner OnDecrementVolumePressed];
}

-(void)awtMessage:(jint)messageID message:(jobject)message env:(JNIEnv*)env
{
    switch (messageID) {
        case JMPlayer_volumeChanged:
            [fullscreenWindow setVolume:FloatValue(env, message)];
            break;
        case JMPlayer_progressChanged:
            [fullscreenWindow setCurrentTime:FloatValue(env, message)];
            break;
        case JMPlayer_stateChanged:
            [self setPlayerState:IntegerValue(env, message)];
            [fullscreenWindow setState:[self playerState]];
            break;
        case JMPlayer_timeInitialized:
            [fullscreenWindow setMaxTime:FloatValue(env, message)];
            break;
        case JMPlayer_toggleFS:
            [self toggleFullscreen];
            break;
        case JMPlayer_addNotify:
            break;
        case JMPlayer_dispose:
            if(jowner != NULL)
            {
                (*env)->DeleteGlobalRef(env, jowner);
                jowner = NULL;
            }
            break;
        default:
            fprintf(stderr, "JMPlayer Error : Unknown message received (%d)\n", (int) messageID);
            break;
    }
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    [super mouseMoved:theEvent];
    NSPoint mousePosition = [NSEvent mouseLocation];
	float delta = pow(lastMousePosition.x - mousePosition.x, 2) + pow(lastMousePosition.y - mousePosition.y, 2);
	lastMousePosition = mousePosition;
	
    // check if amount of mouse movement is >= 5 pixels (sqrt(35)
    //  - but ignoring sqrt calc for perf reasons
    // note this is pixels moved in one update from the OS, not
    // in one user's swipe.
	if(delta > 25.0f )
	{
		[owner OnMouseMoved];
	}
}

- (void)mouseUp:(NSEvent*)event {
    [super mouseUp:event];
    if (event.clickCount > 1) {
        [owner OnMouseDoubleClick];
    }
}

-(void) deliverJavaMouseEvent: (NSEvent *) event {
//    BOOL isEnabled = YES;
//    NSWindow* window = [self window];
//    if ([window isKindOfClass: [AWTWindow_Panel class]] || [window isKindOfClass: [AWTWindow_Normal class]]) {
//        isEnabled = [(AWTWindow*)[window delegate] isEnabled];
//    }
//    
//    if (!isEnabled) {
//        return;
//    }
    
    NSEventType type = [event type];
    
    if ((type == NSMouseEntered && mouseIsOver) || (type == NSMouseExited && !mouseIsOver)) {
        return;
    }else if ((type == NSMouseEntered && !mouseIsOver) || (type == NSMouseExited && mouseIsOver)) {
        mouseIsOver = !mouseIsOver;
    }
    
    /*
    [AWTToolkit eventCountPlusPlus];
    
    JNIEnv *env = [ThreadUtilities getJNIEnv];
    
    NSPoint eventLocation = [event locationInWindow];
    NSPoint localPoint = [self convertPoint: eventLocation fromView: nil];
    NSPoint absP = [NSEvent mouseLocation];
    
    // Convert global numbers between Cocoa's coordinate system and Java.
    // TODO: need consitent way for doing that both with global as well as with local coordinates.
    // The reason to do it here is one more native method for getting screen dimension otherwise.
    
    NSRect screenRect = [[NSScreen mainScreen] frame];
    absP.y = screenRect.size.height - absP.y;
    jint clickCount;
    
    if (type == NSMouseEntered ||
        type == NSMouseExited ||
        type == NSScrollWheel ||
        type == NSMouseMoved) {
        clickCount = 0;
    } else {
        clickCount = [event clickCount];
    }
    
    static JNF_CLASS_CACHE(jc_NSEvent, "sun/lwawt/macosx/event/NSEvent");
    static JNF_CTOR_CACHE(jctor_NSEvent, jc_NSEvent, "(IIIIIIIIDD)V");
    jobject jEvent = JNFNewObject(env, jctor_NSEvent,
                                  [event type],
                                  [event modifierFlags],
                                  clickCount,
                                  [event buttonNumber],
                                  (jint)localPoint.x, (jint)localPoint.y,
                                  (jint)absP.x, (jint)absP.y,
                                  [event deltaY],
                                  [event deltaX]);
    if (jEvent == nil) {
        // Unable to create event by some reason.
        return;
    }
    
    static JNF_CLASS_CACHE(jc_PlatformView, "sun/lwawt/macosx/CPlatformView");
    static JNF_MEMBER_CACHE(jm_deliverMouseEvent, jc_PlatformView, "deliverMouseEvent", "(Lsun/lwawt/macosx/event/NSEvent;)V");
    JNFCallVoidMethod(env, m_cPlatformView, jm_deliverMouseEvent, jEvent);
     */
}

@end

NSString *JavaStringToNSString(JNIEnv *env, jstring aString)
{
    if(aString == NULL)
        return nil;
    
    const jchar *chars = (*env)->GetStringChars(env, aString, NULL);
    NSString *resultString = [NSString stringWithCharacters:(UniChar *)chars length:(*env)->GetStringLength(env, aString)];
    (*env)->ReleaseStringChars(env, aString, chars);
    return resultString;
}

JNIEXPORT jlong JNICALL Java_com_frostwire_gui_mplayer_MPlayerComponentOSX2_createNSView(JNIEnv *env, jobject obj, jstring imagesPath)
{
    @try
    {
        NSArray* windows = [[NSApplication sharedApplication] windows];
        
        NSWindow* playerWindow = NULL;
        
        for (NSWindow* window in windows)
        {
            // temporary hack
            if ([[window title] hasPrefix:@"FrostWire Media Player"])
            {
                playerWindow = window;
            }
        }
        
        JMPlayer* view = nil;
        
        int width = 800;
        int height = 600;
        
        NSString* theImagesPath = JavaStringToNSString(env, imagesPath);
        view = [[JMPlayer alloc] initWithFrame : env theOwner:obj frame:NSMakeRect(0, 0, width, height) imagesPath:theImagesPath];
        
        // add JMPlayer view as a content view
        [playerWindow setContentView:view];
        /*{
            NSWindow* window = playerWindow;
            NSRect window_frame = [window frame];
            NSView* v = view;
            NSView* cv = [playerWindow contentView];
            [cv setAutoresizesSubviews:YES];
            
            //NSRect vframe = [v frame];
            [v setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            
            //NSView* tmp_superview = [[[NSView alloc] initWithFrame:vframe] autorelease];
            //[tmp_superview addSubview:v];
            //[tmp_superview setAutoresizesSubviews:YES];
            //[tmp_superview setFrame:window_frame];
            
            //[v removeFromSuperview];
            [cv addSubview:v];
        }*/
        
        return (jlong)view;
    }
    @catch (NSException *e)
    {
        fprintf(stderr, "ERROR : Failed to create JMPlayer view\n");
        return 0;
    }
}

JNIEXPORT void JNICALL Java_com_frostwire_gui_mplayer_MPlayerComponentOSX2_awtMessage(JNIEnv* env, jobject obj, jlong view, jint messageID, jobject message)
{
    JMPlayer* player = (JMPlayer*)view;
    
    [player awtMessage:messageID message:message env:env];
}
