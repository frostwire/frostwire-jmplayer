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
#import "ScrubbingBar.h"
//#import "TimestampTextField.h"


// private method declarations
@interface FullscreenControls()

- (NSButton*)createButtonWithFrame:(NSRect) frame
                         Image:(NSImage*) image
                    AlternateImage:(NSImage*) alternateImage
                            Action:(SEL) action;
- (void)onPlayButtonPressed;
- (void)onFastForwardButtonPressed;
- (void)onRewindButtonPressed;

@end


@implementation FullscreenControls
@synthesize beingDragged, fcWindow;

-(id) initWithJMPlayer: (JMPlayer*) jmPlayer
      fullscreenWindow: (PlayerFullscreenWindow*) playerFSWindow {
	
    fcWindow = [playerFSWindow retain];
    jm_player = jmPlayer;
    
    if (! [self initResourceBundle]) {
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
        [self setAlphaValue:0.0];
        [self setOpaque:NO];
        
        // Enable shadow
        [self setHasShadow:YES];
        
        if ( ![self initUIControls] ) {
            NSLog(@"Failed to init UI controls");
            [self release];
            return nil;
        }
        
        isPlaying = NO;
        
    }
    
    return self;
}

- (BOOL)initResourceBundle
{
    NSString* developmentPath = [NSString stringWithFormat:@"%@../lib/osx/JMPlayer-Bundle/JMPlayer-Bundle.bundle", jm_player.appPath];
    NSString* path = [NSString stringWithFormat:@"%@JMPlayer-Bundle.bundle", jm_player.appPath];
    
    if ( (resourceBundle = [NSBundle bundleWithPath: path]) ) {
        return YES;
    } else if ( (resourceBundle = [NSBundle bundleWithPath: developmentPath])) {
        return YES;
    } else { // failed to find resource bundle
        return NO;
    }
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
    
    NSImage *fastforwardButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_fast_forward" ofType:@"png"]] autorelease];
    NSImage *fastforwardOnButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_fast_forward_on" ofType:@"png"]] autorelease];
    NSImage *rewindButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_fast_rewind" ofType:@"png"]] autorelease];
    NSImage *rewindOnButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_fast_rewind_on" ofType:@"png"]] autorelease];
    
    playButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_play" ofType:@"png"]] retain];
    playOnButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_play_on" ofType:@"png"]] retain];
    pauseButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_pause" ofType:@"png"]] retain];
    pauseOnButtonImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_pause_on" ofType:@"png"]] retain];

    
    
    // initialize sub-views/controls
    // -----------------------------
    
    // background image view
    NSRect bkgndFrame = NSMakeRect(0.0, 0.0, bkgndImage.size.width, bkgndImage.size.height);
    NSImageView * bkgndImageView = [[[NSImageView alloc] initWithFrame:bkgndFrame] autorelease];
    [bkgndImageView setImage:bkgndImage];
    
    
    // play / pause button
    NSRect playButtonFrame = NSMakeRect(204, 8, playButtonImage.size.width, playButtonImage.size.height);
    playButton = [self createButtonWithFrame:playButtonFrame
                                       Image:playButtonImage
                              AlternateImage:playOnButtonImage
                                      Action:@selector(onPlayButtonPressed)];
    
    // fast forward button
    NSRect fastforwardFrame = NSMakeRect(242, 10, fastforwardButtonImage.size.width, fastforwardButtonImage.size.height );
    NSButton *fastforwardButton = [self createButtonWithFrame:fastforwardFrame
                                                        Image:fastforwardButtonImage
                                               AlternateImage:fastforwardOnButtonImage
                                                       Action:@selector(onFastForwardButtonPressed)];

    // rewind button
    NSRect rewindFrame = NSMakeRect(163, 10, rewindButtonImage.size.width, rewindButtonImage.size.height );
    NSButton *rewindButton = [self createButtonWithFrame:rewindFrame
                                                   Image:rewindButtonImage
                                          AlternateImage:rewindOnButtonImage
                                                  Action:@selector(onRewindButtonPressed)];
    
    // progress bar
    // ...
    
    
    // add sub-views/controls to contentView
    // --------------------------------------
    [[self contentView] addSubview:bkgndImageView];
    [[self contentView] addSubview:playButton positioned:NSWindowAbove relativeTo:bkgndImageView];
    [[self contentView] addSubview:fastforwardButton positioned:NSWindowAbove relativeTo:bkgndImageView];
    [[self contentView] addSubview:rewindButton positioned:NSWindowAbove relativeTo:bkgndImageView];
    
    [playButton setNeedsDisplay:YES];
    [bkgndImageView setNeedsDisplay:YES];

    return YES;
}

- (NSButton*)createButtonWithFrame:(NSRect) frame
                             Image:(NSImage*) image
                    AlternateImage:(NSImage*) alternateImage
                            Action:(SEL) action
{
    NSButton* button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [button setTarget:self];
    [button setAction:action];
    [button setImage:image];
    [button setAlternateImage:alternateImage];
    [button.cell setBackgroundColor: [NSColor colorWithCalibratedWhite:0.0f alpha:0.0f]];
    [button setButtonType:NSMomentaryChangeButton];
    [button setBordered:NO];

    return button;
}


- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint currentDragPoint;
	NSPoint newOrigin;
	
    currentDragPoint = [self convertBaseToScreen:[self mouseLocationOutsideOfEventStream]];
    newOrigin.x = currentDragPoint.x - dragStartPoint.x;
    newOrigin.y = currentDragPoint.y - dragStartPoint.y;
    
    [self setFrameOrigin:newOrigin];
}

- (void)mouseDown:(NSEvent *)theEvent
{    
    NSRect windowFrame = [self frame];
	dragStartPoint = [self convertBaseToScreen:[theEvent locationInWindow]];
	dragStartPoint.x -= windowFrame.origin.x;
	dragStartPoint.y -= windowFrame.origin.y;
	beingDragged = YES;
}

- (void)mouseUp:(NSEvent *)theEvent
{
	beingDragged = NO;
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

/*
- (void) interface:(MPlayerInterface *)mi hasChangedStateTo:(NSNumber *)statenumber fromState:(NSNumber *)oldstatenumber
{	
	MIState state = [statenumber unsignedIntValue];
	unsigned int stateMask = (1<<state);
	MIState oldState = [oldstatenumber unsignedIntValue];
	unsigned int oldStateMask = (1<<oldState);
	
	// First play after startup
	if (state == MIStatePlaying && (oldStateMask & MIStateStartupMask)) {
		[fcAudioCycleButton setEnabled:([[playerController playingItem] audioStreamCount] > 1)];
		[fcSubtitleCycleButton setEnabled:([[playerController playingItem] subtitleCountForType:SubtitleTypeAll] > 0)];
	}
	
	// Change of Play/Pause state
	if (!!(stateMask & MIStatePPPlayingMask) != !!(oldStateMask & MIStatePPPlayingMask)) {
		// Playing
		if (stateMask & MIStatePPPlayingMask) {
			// Update interface
			[fcPlayButton setImage:fcPauseImageOff];
			[fcPlayButton setAlternateImage:fcPauseImageOn];
		// Pausing
		} else {
			// Update interface
			[fcPlayButton setImage:fcPlayImageOff];
			[fcPlayButton setAlternateImage:fcPlayImageOn];			
		}
	}
	
	// Change of Running/Stopped state
	if (!!(stateMask & MIStateStoppedMask) != !!(oldStateMask & MIStateStoppedMask)) {
		// Stopped
		if (stateMask & MIStateStoppedMask) {
			// Update interface
			[fcTimeTextField setTimestamptWithCurrentTime:0 andTotalTime:0];
			[fcFullscreenButton setEnabled:NO];
			// Disable stream buttons
			[fcAudioCycleButton setEnabled:NO];
			[fcSubtitleCycleButton setEnabled:NO];
		// Running
		} else {
			// Update interface
			[fcFullscreenButton setEnabled:YES];
		}
	}
	
	// Update progress bar
	if (stateMask & MIStateStoppedMask && !(oldStateMask & MIStateStoppedMask)) {
		// Reset progress bar
		[fcScrubbingBar setScrubStyle:MPEScrubbingBarEmptyStyle];
		[fcScrubbingBar setDoubleValue:0];
		[fcScrubbingBar setIndeterminate:NO];
	} else if (stateMask & MIStateIntermediateMask && !(oldStateMask & MIStateIntermediateMask)) {
		// Intermediate progress bar
		[fcScrubbingBar setScrubStyle:MPEScrubbingBarProgressStyle];
		[fcScrubbingBar setIndeterminate:YES];
	} else if (stateMask & MIStatePositionMask && !(oldStateMask & MIStatePositionMask)) {
		// Progress bar
		if ([[playerController playingItem] length] > 0) {
			[fcScrubbingBar setMaxValue: [[playerController playingItem] length]];
			[fcScrubbingBar setScrubStyle:MPEScrubbingBarPositionStyle];
		} else {
			[fcScrubbingBar setScrubStyle:MPEScrubbingBarProgressStyle];
			[fcScrubbingBar setMaxValue:100];
			[fcScrubbingBar setIndeterminate:NO];
		}
	}
}

- (void) interface:(MPlayerInterface *)mi volumeUpdate:(NSNumber *)volume isMuted:(NSNumber *)muted
{
	[fcVolumeSlider setFloatValue:[volume floatValue]];
}

- (void) interface:(MPlayerInterface *)mi timeUpdate:(NSNumber *)newTime
{
	float seconds = [newTime floatValue];
	
	if ([[playerController playingItem] length] > 0)
		[fcScrubbingBar setDoubleValue:seconds];
	else
		[fcScrubbingBar setDoubleValue:0];
	
	[fcTimeTextField setTimestamptWithCurrentTime:seconds andTotalTime:[[playerController movieInfo] length]];
}
*/

- (void) onPlayButtonPressed
{
    NSLog(@" play button pressed ");
    
    if ( isPlaying == YES ) {
        [playButton setImage: pauseButtonImage];
        [playButton setAlternateImage: pauseOnButtonImage];
    } else {
        [playButton setImage:playButtonImage];
        [playButton setAlternateImage:playOnButtonImage];
    }
    
    isPlaying = !isPlaying;
}

- (void) onFastForwardButtonPressed
{
    NSLog(@" fast forward button pressed ");
}

- (void) onRewindButtonPressed
{
    NSLog(@" rewind button pressed ");   
}

- (void) dealloc
{
    [pauseButtonImage release];
    [pauseOnButtonImage release];
	[playButtonImage release];
    [playOnButtonImage release];
	
    [animation release];
	[super dealloc];
    
}

@end
