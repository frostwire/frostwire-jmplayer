//
//  ProgressSlider.m
//  JMPlayer
//
//  Created by Erich Pleny on 10/10/12.
//
//

#import "ProgressSlider.h"
#import "ProgressSliderCell.h"

@implementation ProgressSlider

- (id)initWithCenter:(CGPoint)center viewWidth:(CGFloat)viewWidth
{
    int sliderWidth = viewWidth * 0.6;
    int sliderHeight = 25;
    int progressHeight = 5;
    
    NSRect frame = NSMakeRect(center.x - sliderWidth / 2.0, center.y-sliderHeight / 2.0, sliderWidth, sliderHeight);
    
    if ((self = [super initWithFrame:frame])) {
        
        // create progress bar
        NSRect progressFrame = NSMakeRect(0.0,
                                          (frame.size.height - progressHeight) / 2.0,
                                          sliderWidth,
                                          progressHeight);
        NSProgressIndicator * progressIndicator = [[NSProgressIndicator alloc] initWithFrame:progressFrame];
        [progressIndicator setIndeterminate:FALSE];
        [progressIndicator setDoubleValue:27.5];
        [self addSubview:progressIndicator];
        
        
        // create slider overlay
        NSRect sliderFrame = NSMakeRect(0.0, 0.0, sliderWidth,sliderHeight);
        
        [NSSlider setCellClass:[ProgressSliderCell class]];
        NSSlider *progressSlider = [[NSSlider alloc] initWithFrame:sliderFrame];
        [NSSlider setCellClass:[NSSliderCell class]];
        
        [progressSlider setDoubleValue:0.275];
        [self addSubview:progressSlider positioned:NSWindowAbove relativeTo:progressIndicator ];
    }
    
    return self;
}

@end
