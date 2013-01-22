/*  
 *  PlayerFullscreenWindow.h
 *  MPlayerOSX Extended
 *  
 *  Created on 20.10.2008
 *  
 *  Description:
 *	Borderless window used to go into and display video in fullscreen.
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

#import <Cocoa/Cocoa.h>
#import "Protocols.h"

@class FullscreenControls;
@class JMPlayer;

@interface PlayerFullscreenWindow : NSWindow <MusicPlayerProtocol> {

	FullscreenControls *fullscreenControls;
	JMPlayer *player;
    
	BOOL isFullscreen;
	BOOL mouseInWindow;
	BOOL mouseOverControls;
	
	NSTrackingRectTag fsTrackTag, fcTrackTag;
	NSTimer *osdTimer;
	NSPoint lastMousePosition;
    
    int playerState;
}

-(id) initWithContentRect: (NSRect) contentRect 
				styleMask: (unsigned int) styleMask 
				  backing: (NSBackingStoreType) backingType
                 jmPlayer: (JMPlayer*) jmPlayer
					defer: (BOOL) flag;

- (void) hideOSD;
- (void) showOSD;
- (void) setFullscreen: (bool)aBool;
- (void) startMouseTracking;
- (void) stopMouseTracking;
- (void) refreshOSDTimer;

- (void) mouseEnteredFSWindow;
- (void) mouseExitedFSWindow;
- (void) mouseEnteredFCWindow;
- (void) mouseExitedFCWindow;

// MusicPlayerProtocol
-(void) setVolume:(CGFloat)volume;
-(void) setState:(int)state;
-(void) setMaxTime:(CGFloat)seconds;
-(void) setCurrentTime:(CGFloat)seconds;

@end
