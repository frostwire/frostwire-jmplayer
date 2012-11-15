/*  
 *  FullscreenControls.m
 *  MPlayerOSX Extended
 *  
 *  Created on 03.11.2008
 *  
 *  Description:
 *	Window used for the fullscreen controls.
 *  
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#import "FullscreenControls.h"
#import <AppKit/AppKit.h>
#import "Debug.h"
#import "JMPlayer.h"
#import "ProgressSlider.h"
#import "VolumeSlider.h"

// private method declarations
@interface FullscreenControls()

- (NSButton*)createButtonWithFrame:(NSRect) frame Image:(NSImage*) image Action:(SEL) action;
- (void)onPlayButtonPressed;
- (void)onFastForwardButtonPressed;
- (void)onRewindButtonPressed;
- (void)onFullScreenButtonPressed;

- (void)onProgressSliderValueChanged:(float) seconds;
- (void)onProgressSliderStarted;
- (void)onProgressSliderEnded;
- (void)onVolumeSliderVolumeChange:(CGFloat) volume;

@end


@implementation FullscreenControls

@synthesize beingDragged, fcWindow, delegate;

-(id) initWithJMPlayer: (JMPlayer*) jmPlayer
      fullscreenWindow: (PlayerFullscreenWindow*) playerFSWindow {
	
    fcWindow = [playerFSWindow retain];
    jm_player = jmPlayer;
    
    // wire up for callbacks
    delegate = (id<MusicPlayerClientProtocol>)jmPlayer;
    jmPlayer.player = self;
    
    if (! (resourceBundle = [FullscreenControls findResourceBundleWithAppPath:jm_player.appPath]) ) {
        NSLog(@"Error");
        [self release];
        return nil;
    }
        
    NSRect frame;
    frame.origin.x = 0;
    frame.origin.y = 0;
    frame.size = [self determineWindowSize];
    
    if ( frame.size.width == 0.0 || frame.size.height == 0.0 ) {
        NSLog(@"ERROR: failed to determine window size in initWithJMPlayer");
        [self release];
        return nil;
    }
    
    if ( (self = [super initWithContentRect:frame
                                  styleMask:NSBorderlessWindowMask
                                    backing:NSBackingStoreBuffered
                                      defer:NO]) ) {
        // Prepare window transparency
        [self setBackgroundColor: [NSColor clearColor]];
        [self setOpaque:NO];
        [self setIgnoresMouseEvents:FALSE];
        
        // Enable shadow
        [self setHasShadow:YES];
        
        if ( ![self initUIControls] ) {
            NSLog(@"Failed to init UI controls");
            [self release];
            return nil;
        }
        
    }
    
    return self;
}

+ (NSBundle*)findResourceBundleWithAppPath:(NSString*) appPath
{
    NSString *developmentPath = [NSString stringWithFormat:@"%@../lib/osx/JMPlayer-Bundle/JMPlayer-Bundle.bundle", appPath];
    NSString *path = [NSString stringWithFormat:@"%@JMPlayer-Bundle.bundle", appPath];
    NSBundle *bundle = nil;
    
    if ( !(bundle = [NSBundle bundleWithPath: path]) ) {
        bundle = [NSBundle bundleWithPath: developmentPath];
    }
    
    return bundle;
}

- (NSSize)determineWindowSize
{
    NSString* imagePath = [resourceBundle pathForResource:@"fc_background" ofType:@"png"];
    
    if (nil == imagePath) {
        NSLog(@"ERROR: could not file file path for fc_background");
        return NSMakeSize(0.0, 0.0);
    }
    
    NSImage *bkgnd = [[NSImage alloc] initByReferencingFile:imagePath];
    NSSize size;
    
    size.height = bkgnd.size.height;
    size.width = bkgnd.size.width;
    
    [bkgnd release];
    
    return size;
}

- (BOOL)initUIControls
{
    
    // initialize images
    // -----------------
    NSImage *bkgndImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_background" ofType:@"png"]] autorelease];
    
    NSImage *fastforwardButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_next" ofType:@"png"]] autorelease];
    NSImage *rewindButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_previous" ofType:@"png"]] autorelease];
    NSImage *fullscreenButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_fullscreen_exit" ofType:@"png"]] autorelease];
    playButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_play" ofType:@"png"]] retain];
    pauseButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_pause" ofType:@"png"]] retain];
    
    // initialize sub-views/controls
    // -----------------------------
    
    // background image view
    NSRect bkgndFrame = NSMakeRect(0.0, 0.0, bkgndImage.size.width, bkgndImage.size.height);
    NSImageView * bkgndImageView = [[[NSImageView alloc] initWithFrame:bkgndFrame] autorelease];
    [bkgndImageView setImage:bkgndImage];
    [[self contentView] addSubview:bkgndImageView];
    
    // play button
    //NSRect playButtonFrame = NSMakeRect(243, 35, playButtonImage.size.width, playButtonImage.size.height);
    NSRect playButtonFrame = NSMakeRect(216, 35, playButtonImage.size.width, playButtonImage.size.height);
    playButton = [self createButtonWithFrame:playButtonFrame Image:playButtonImage Action:@selector(onPlayButtonPressed)];
    [[self contentView] addSubview:playButton positioned:NSWindowAbove relativeTo:bkgndImageView];
    
    // pause button
    //NSRect pauseButtonFrame = NSMakeRect(243, 35, pauseButtonImage.size.width, pauseButtonImage.size.height);
    NSRect pauseButtonFrame = NSMakeRect(216, 35, pauseButtonImage.size.width, pauseButtonImage.size.height);
    pauseButton = [self createButtonWithFrame:pauseButtonFrame Image:pauseButtonImage Action:@selector(onPauseButtonPressed)];
    
    // fast forward button
    //NSRect fastforwardFrame = NSMakeRect(318, 40, fastforwardButtonImage.size.width, fastforwardButtonImage.size.height );
    NSRect fastforwardFrame = NSMakeRect(286, 40, fastforwardButtonImage.size.width, fastforwardButtonImage.size.height );
    fastforwardButton = [self createButtonWithFrame:fastforwardFrame Image:fastforwardButtonImage Action:@selector(onFastForwardButtonPressed)];
    [[self contentView] addSubview:fastforwardButton positioned:NSWindowAbove relativeTo:bkgndImageView];
    
    // rewind button
    //NSRect rewindFrame = NSMakeRect(181, 40, rewindButtonImage.size.width, rewindButtonImage.size.height );
    NSRect rewindFrame = NSMakeRect(162, 40, rewindButtonImage.size.width, rewindButtonImage.size.height );
    rewindButton = [self createButtonWithFrame:rewindFrame Image:rewindButtonImage Action:@selector(onRewindButtonPressed)];
    [[self contentView] addSubview:rewindButton positioned:NSWindowAbove relativeTo:bkgndImageView];
    
    // exit fullscreen button
    //NSRect fullscreenFrame = NSMakeRect(447, 53, fullscreenButtonImage.size.width, fullscreenButtonImage.size.height);
    NSRect fullscreenFrame = NSMakeRect(402, 53, fullscreenButtonImage.size.width, fullscreenButtonImage.size.height);
    fullscreenButton = [self createButtonWithFrame:fullscreenFrame Image:fullscreenButtonImage Action:@selector(onFullScreenButtonPressed)];
    [[self contentView] addSubview:fullscreenButton positioned:NSWindowAbove relativeTo:bkgndImageView];
    
    // progress slider
    CGPoint center = NSMakePoint([self frame].size.width * 0.5, [self frame].size.height * 0.2);
    progressSlider = [[ProgressSlider alloc] initWithCenter:center viewWidth: [self frame].size.width];
    [progressSlider setDelegate:self];
    [[self contentView] addSubview:progressSlider positioned:NSWindowAbove relativeTo:bkgndImageView];
    
    // volume slider
    NSRect vsFrame = NSMakeRect(16, 60, 0.25 * self.frame.size.width, 25);
    volumeSlider = [[VolumeSlider alloc] initWithFrame: vsFrame ApplicationPath:jm_player.appPath];
    [volumeSlider setDelegate:self];
    [[self contentView] addSubview:volumeSlider positioned:NSWindowAbove relativeTo:bkgndImageView];
    
    return YES;
}

- (NSButton*)createButtonWithFrame:(NSRect) frame
                             Image:(NSImage*) image
                            Action:(SEL) action
{
    NSButton* button = [[NSButton alloc] initWithFrame:frame];
    [button setTarget:self];
    [button setAction:action];
    [button setImage:image];
    [button setButtonType:NSMomentaryChangeButton];
    [button setBordered:NO];

    return button;
}

- (void)show
{
	[fcWindow addChildWindow:self ordered:NSWindowAbove];
	[self fadeWith:NSViewAnimationFadeInEffect];
}

- (void)hide
{
	[fcWindow removeChildWindow:self];
	[self fadeWith:NSViewAnimationFadeOutEffect];
	[self performSelector:@selector(endHide) withObject:nil afterDelay:0.5];
}

- (void)endHide
{
	[self orderOut:self];
}

- (void)fadeWith:(NSString*)effect
{
	NSMutableDictionary *adesc;
	
	// Setup animation
	adesc = [NSMutableDictionary dictionaryWithCapacity:3];
	[adesc setObject:self forKey:NSViewAnimationTargetKey];
	
	[adesc setObject:effect forKey:NSViewAnimationEffectKey];
	
	// Create animation object if needed
	if (animation == nil) {
		animation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects: adesc, nil]];
	} else {
		[animation setViewAnimations:[NSArray arrayWithObjects: adesc, nil]];
	}
	
	[animation setAnimationBlockingMode:NSAnimationNonblockingThreaded];
	[animation setDuration:0.5];
	[animation setAnimationCurve:NSAnimationEaseIn];
	
	[animation startAnimation];
	
}

- (void) cycleTimeDisplayMode:(id)sender
{
	if (![self isVisible])
		[fcWindow showOSD];
	else {
		//[fcTimeTextField cycleDisplayMode:self];
		[fcWindow refreshOSDTimer];
	}
}

- (void) dealloc
{
    [pauseButtonImage release];
	[playButtonImage release];
    
    [playButton release];
    [fastforwardButton release];
    [rewindButton release];
    [fullscreenButton release];
    [volumeSlider release];
    [progressSlider release];
    
    [animation release];
	[super dealloc];
    
}


/*
 * UI Control handlers - these all go straight to the JMPlayer, 
 *   then to Java - only when Java notifies us back do we update the UI.
 */
-(void)onVolumeSliderVolumeChange:(CGFloat) volume {
    [delegate onVolumeChanged:volume];
}

- (void)onProgressSliderValueChanged:(float) seconds {
    [delegate onSeekToTime:seconds];
}

- (void)onProgressSliderStarted {
    [delegate onProgressSliderStarted];
}

- (void)onProgressSliderEnded {
    [delegate onProgressSliderEnded];
}

- (void) onPlayButtonPressed
{
    [delegate onPlayPressed];
}

- (void) onPauseButtonPressed
{
    [delegate onPausePressed];
}

- (void) onFastForwardButtonPressed
{
    [delegate onFastForwardPressed];
}

- (void) onRewindButtonPressed
{
    [delegate onRewindPressed];
}

- (void)onFullScreenButtonPressed
{
    [delegate onToggleFullscreenPressed];
}


/*
 * Java callback handlers
 */

-(void) setVolume:(CGFloat)volume {
    if (volume != [volumeSlider getVolume]) {
        [volumeSlider setVolume:volume];
    }
}

-(void) setState:(int)state {
    switch (state) {
        case JMPlayer_statePlaying:
            [playButton removeFromSuperview];
            [[self contentView] addSubview:pauseButton];
            break;
        case JMPlayer_statePaused:
            [pauseButton removeFromSuperview];
            [[self contentView] addSubview:playButton];
            break;
        case JMPlayer_stateClosed:
            [pauseButton removeFromSuperview];
            [[self contentView] addSubview:playButton];
            break;
        default:
            break;
    }
}

-(void) setMaxTime:(CGFloat)seconds {
    [progressSlider setMaxTime:seconds];
}

-(void) setCurrentTime:(CGFloat)seconds {
    [progressSlider setCurrentTime:seconds];
}


@end
