//
//  OwnerWrapper.m
//  JMPlayer
//
//  Created by Alden Torres on 1/23/13.
//
//

#import "OwnerWrapper.h"

@implementation OwnerWrapper

-(id) initWithOwner:(jobject) theOwner
{
    if (self = [super init])
    {
        owner = theOwner;
    }
    
    return self;
}
@end
