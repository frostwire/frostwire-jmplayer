//
//  VolumeSlider.m
//  JMPlayer
//
//  Created by Erich Pleny on 10/11/12.
//
//

#import "VolumeSlider.h"
#import "FullscreenControls.h"

@implementation VolumeSlider

- (id)initWithFrame:(NSRect)frame ApplicationPath:(NSString*) appPath {
    
    if (self = [super initWithFrame:frame]) {
        
        // create 3 controls: volume off, slider, volume on
        // centered vertically and stretching to fit entire width of frame.
        
        NSBundle *resourceBundle = [FullscreenControls findResourceBundleWithAppPath:appPath];
        
        NSImage *volumeOffImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_volume_off" ofType:@"png"]] autorelease];
        NSImage *volumeOnImage = [[[NSImage alloc] initByReferencingFile:[resourceBundle pathForResource:@"fc_volume_on" ofType:@"png"]] autorelease];
        
        int spacer = 5;
        int xPos = spacer;
        int volumeOffYPos = (frame.size.height - volumeOffImage.size.height) / 2;
        int volumeOnYPos = (frame.size.height - volumeOnImage.size.height) / 2;
        int sliderWidth = frame.size.width - volumeOffImage.size.width - volumeOnImage.size.width - 4*spacer;
        
        // create volume off image
        NSRect volumeOffFrame = NSMakeRect(xPos, volumeOffYPos, volumeOffImage.size.width, volumeOffImage.size.height);
        NSImageView *volumeOffView = [[NSImageView alloc] initWithFrame:volumeOffFrame];
        [volumeOffView setImage:volumeOffImage];
        [self addSubview:volumeOffView];
        xPos += volumeOffImage.size.width + spacer;
        
        // create slider
        NSRect sliderFrame = NSMakeRect(xPos, 0, sliderWidth, frame.size.height);
        slider = [[NSSlider alloc] initWithFrame:sliderFrame];
        [slider setContinuous:TRUE];
        [slider setTarget:self];
        [slider setAction:@selector(onSliderValueChange)];
        [self addSubview:slider];
        xPos += slider.frame.size.width;

        // create volume on image
        NSRect volumeOnFrame = NSMakeRect(xPos, volumeOnYPos, volumeOnImage.size.width, volumeOnImage.size.height);
        NSImageView *volumeOnView = [[NSImageView alloc] initWithFrame:volumeOnFrame];
        [volumeOnView setImage:volumeOnImage];
        [self addSubview:volumeOnView];
        
        [self setVolume:0.5];
    }
    
    return self;
}

/*
 * setVolume - volume between 0.0 and 1.0.
 */
- (void)setVolume:(CGFloat)volume {
    [slider setFloatValue:volume];
}

- (void)onSliderValueChange {
    if ( self.delegate ) {
        [ self.delegate onVolumeSliderVolumeChange:[slider floatValue]];
    }
}
@end
