//
//  StartEndSlider.h
//  JMPlayer
//
//  Created by Erich Pleny on 11/12/12.
//
//

#import <Cocoa/Cocoa.h>

@protocol StartEndSliderProtocol <NSObject>

- (void) onStartEndSliderStarted;
- (void) onStartEndSliderEnded;

@end

@interface StartEndSliderCell : NSSliderCell {

    id <StartEndSliderProtocol> delegate;
    
}

-(void) setStartEndDelegate:(id<StartEndSliderProtocol>) del;

@end
