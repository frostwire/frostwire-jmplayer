/*
 * Created by Erich Pleny (erichpleny)
 * Copyright (c) 2012, FrostWire(R). All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "VolumeSlider.h"
#import "FullscreenControls.h"

@implementation VolumeSlider

- (id)initWithFrame:(NSRect)frame imagesPath : (NSString*) imagesPath
{
    if (self = [super initWithFrame:frame]) {
        
        // create 3 controls: volume off, slider, volume on
        // centered vertically and stretching to fit entire width of frame.
        
        NSImage *volumeOffImage = [[[NSImage alloc] initByReferencingFile:[imagesPath stringByAppendingString:@"fc_volume_off.png"]] autorelease];
        NSImage *volumeOnImage = [[[NSImage alloc] initByReferencingFile:[imagesPath stringByAppendingString:@"fc_volume_on.png"]] autorelease];
        
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

-(CGFloat)getVolume {
    return slider.floatValue;
}

- (void)onSliderValueChange {
    if ( self.delegate ) {
        [ self.delegate onVolumeSliderVolumeChange:[slider floatValue]];
    }
}
@end
