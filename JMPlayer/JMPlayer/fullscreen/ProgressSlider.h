//
//  ProgressSlider.h
//  JMPlayer
//
//  Created by Erich Pleny on 10/10/12.
//
//

#import <Cocoa/Cocoa.h>

@protocol ProgressSliderProtocol <NSObject>

- (void) onProgressSliderValueChanged:(int) seconds;

@end

@interface ProgressSlider : NSView
{
    CGFloat maxTime;
    CGFloat currentTime;
    
    NSTextField *timeElapsedTextField;
    NSTextField *timeRemainingTextField;
    NSSlider *slider;
    
    id<ProgressSliderProtocol> delegate;
}

- (id)initWithCenter:(CGPoint)center viewWidth:(CGFloat)viewWidth;
- (void)setMaxTime:(CGFloat)seconds;
- (void)setCurrentTime:(CGFloat)seconds;
- (void)setDelegate:(id<ProgressSliderProtocol>)del;
- (void)dealloc;

@end
