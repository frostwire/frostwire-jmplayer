//
//  ProgressSlider.m
//  JMPlayer
//
//  Created by Erich Pleny on 10/10/12.
//
//

#import "ProgressSlider.h"

@interface ProgressSlider()

- (void)updateUI;
- (NSTextField*) createTimeTextFieldWithSize:(NSSize)size AlignLeft:(BOOL)alignLeft;
- (NSString*) timeStringForSeconds:(int)rawSeconds PrependNegative:(BOOL)prependNegative;
- (void) onSliderValueChange;

@end

@implementation ProgressSlider

- (id)initWithCenter:(CGPoint)center viewWidth:(CGFloat)viewWidth
{
    int sliderHeight = 20;
    NSSize timeFieldSize = NSMakeSize(viewWidth * 0.15, sliderHeight);
    NSRect frame = NSMakeRect(center.x - viewWidth / 2.0, center.y-sliderHeight / 2.0, viewWidth, sliderHeight);
    
    if ((self = [super initWithFrame:frame])) {
        
        delegate = nil;
        
        // create time elapsed text fields
        timeElapsedTextField = [self createTimeTextFieldWithSize:timeFieldSize AlignLeft:FALSE];
        [self addSubview:timeElapsedTextField];
        timeRemainingTextField = [self createTimeTextFieldWithSize:timeFieldSize AlignLeft:TRUE];
        [self addSubview:timeRemainingTextField];
        
        CGFloat sliderWidth = viewWidth - [timeElapsedTextField frame].size.width - [timeRemainingTextField frame].size.width;
        CGFloat xPos = 0.0;
        
        // position time elapsed text
        frame = [timeElapsedTextField frame];
        frame.origin.y = (sliderHeight - frame.size.height) / 2.0;
        frame.origin.x = xPos;
        [timeElapsedTextField setFrame:frame];
        xPos += frame.size.width;
        
        // create / position slider
        NSRect sliderFrame = NSMakeRect(xPos, 0.0, sliderWidth, sliderHeight);
        slider = [[NSSlider alloc] initWithFrame:sliderFrame];
        [slider setContinuous:TRUE];
        [slider setTarget:self];
        [slider setAction:@selector(onSliderValueChange)];
        [self addSubview:slider];
        xPos += sliderWidth;
        
        // position time remaining text
        frame = [timeRemainingTextField frame];
        frame.origin.y = (sliderHeight - frame.size.height) / 2.0;
        frame.origin.x = xPos;
        [timeRemainingTextField setFrame:frame];
        
        // set default time
        [self setMaxTime:250];
        [self setCurrentTime:17];
    }
    
    return self;
}

- (void)setDelegate:(id<ProgressSliderProtocol>)del {
    delegate = del;
}

- (void) setMaxTime:(CGFloat)seconds {
    maxTime = seconds;
    [self setCurrentTime:0];
}

- (void) setCurrentTime:(CGFloat)seconds {
    if ( currentTime != seconds ) {
        currentTime = seconds;
        [self updateUI];
    }
}


- (void) updateUI {
    int remainingTime = maxTime - currentTime;
    [slider setDoubleValue: currentTime / maxTime];
    [timeElapsedTextField setStringValue: [self timeStringForSeconds:currentTime PrependNegative:FALSE]];
    [timeRemainingTextField setStringValue: [self timeStringForSeconds:remainingTime PrependNegative:TRUE]];
}

- (void) onSliderValueChange {

    int seconds = [slider floatValue] * maxTime;
    
    [self setCurrentTime: seconds];

    if (delegate) {
        [delegate onProgressSliderValueChanged:seconds];
    }
    
}


- (NSTextField*) createTimeTextFieldWithSize: (NSSize) size AlignLeft:(BOOL) alignLeft {
    
    NSRect frame = NSMakeRect(0.0, 0.0, size.width, size.height);
    
    NSTextField* textField = [[[NSTextField alloc]initWithFrame:frame] autorelease];
    
    if ( textField ) {
        
        [textField setEditable:FALSE];
        [textField setSelectable:FALSE];
        [textField setBordered:FALSE];
        [textField setDrawsBackground:FALSE];
        [textField setAlignment: alignLeft ? NSLeftTextAlignment : NSRightTextAlignment];
        [textField setTextColor: [NSColor whiteColor]];
        [textField setStringValue: [self timeStringForSeconds:7245 PrependNegative:TRUE]];
    }
    
    return textField;
}

- (NSString*) timeStringForSeconds:(int) rawSeconds PrependNegative:(BOOL) prependNegative {
    
    int hours = rawSeconds / 3600;
    int minutes = (rawSeconds - (hours * 3600)) / 60;
    int seconds = rawSeconds - (hours * 3600) - (minutes * 60);
    
    NSString * fmtString = nil;
    
    if ( hours > 0 ) {
        fmtString = [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
    } else {
        fmtString = [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
    }
    
    if ( prependNegative ) {
        fmtString = [NSString stringWithFormat:@"-%@", fmtString];
    }
    
    return fmtString;
}



- (void)dealloc {
    
    [timeElapsedTextField release];
    [timeRemainingTextField release];
    [slider release];
    
    [super dealloc];
}

@end
