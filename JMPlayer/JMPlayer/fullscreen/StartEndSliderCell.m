//
//  StartEndSlider.m
//  JMPlayer
//
//  Created by Erich Pleny on 11/12/12.
//
//

#import "StartEndSliderCell.h"

@implementation StartEndSliderCell

-(void) setStartEndDelegate:(id<StartEndSliderProtocol>) del {
    delegate = del;
}

- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView*) view {
    if( [super startTrackingAt:startPoint inView:view] ) {
        [delegate onStartEndSliderStarted];
        return YES;
    }
    return NO;
}

- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag {
    [delegate onStartEndSliderEnded];
    [super stopTracking:lastPoint at:stopPoint inView:controlView mouseIsUp:flag];
}

@end
