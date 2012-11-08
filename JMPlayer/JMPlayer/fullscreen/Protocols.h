//
//  Protocols.h
//  JMPlayer
//
//  Created by Erich Pleny on 11/7/12.
//
//

@protocol MusicPlayerClientProtocol <NSObject>

-(void)onVolumeChanged:(CGFloat)volume;
-(void)onSeekToTime:(CGFloat)seconds;
-(void)onPlayPressed;
-(void)onPausePressed;
-(void)onFastForwardPressed;
-(void)onRewindPressed;
-(void)onToggleFullscreenPressed;

@end

@protocol MusicPlayerProtocol <NSObject>

-(void)setVolume:(CGFloat)volume;
-(void)setState:(int)state;
-(void)setMaxTime:(CGFloat)seconds;
-(void)setCurrentTime:(CGFloat)seconds;

@end
