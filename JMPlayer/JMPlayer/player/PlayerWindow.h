/* PlayerWindow */

#import <Cocoa/Cocoa.h>

//@class PlayerController;
@class JMPlayer;

@interface PlayerWindow : NSWindow
{
	//IBOutlet PlayerController *playerController;
	
    JMPlayer *player;
    
	float scrollXAcc;
}
//@property (readonly) PlayerController *playerController;

- (void) setJMPlayer:(JMPlayer*) jmPlayer;
- (void) keyDown:(NSEvent *)theEvent;

@end
