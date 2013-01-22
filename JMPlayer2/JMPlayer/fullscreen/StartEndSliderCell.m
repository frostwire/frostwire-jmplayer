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
