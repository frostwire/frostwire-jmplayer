//
//  VolumeSlider.h
//  JMPlayer
//
//  Created by Erich Pleny on 10/11/12.
//
//

#import <Cocoa/Cocoa.h>

@protocol VolumeSliderProtocol <NSObject>

-(void)onVolumeSliderVolumeChange:(CGFloat) volume;

@end

@interface VolumeSlider : NSView
{
    NSSlider* slider;
}

@property (nonatomic, retain) id<VolumeSliderProtocol> delegate;

- (id)initWithFrame:(NSRect)frameRect ApplicationPath:(NSString*) appPath;
- (void)setVolume:(CGFloat)volume;

@end
