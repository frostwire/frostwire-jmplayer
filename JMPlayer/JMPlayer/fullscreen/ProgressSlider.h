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

#import <Cocoa/Cocoa.h>
#import "StartEndSliderCell.h"

@protocol ProgressSliderProtocol <NSObject>

- (void) onProgressSliderValueChanged:(float) seconds;
- (void) onProgressSliderStarted;
- (void) onProgressSliderEnded;

@end

@interface ProgressSlider : NSView <StartEndSliderProtocol>
{
    CGFloat maxTime;
    CGFloat currentTime;
    
    NSTextField *timeElapsedTextField;
    NSTextField *timeRemainingTextField;
    NSSlider *slider;
    
    id<ProgressSliderProtocol> delegate;
}

- (id)initWithCenter:(CGPoint)center viewWidth:(CGFloat)viewWidth;
- (CGFloat)getMaxTime;
- (void)setMaxTime:(CGFloat)seconds;
- (CGFloat)getCurrentTime;
- (void)setCurrentTime:(CGFloat)seconds;
- (void)setDelegate:(id<ProgressSliderProtocol>)del;
- (void)dealloc;

- (void) onStartEndSliderStarted;
- (void) onStartEndSliderEnded;

@end
