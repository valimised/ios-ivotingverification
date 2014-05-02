//
//  VerificationResultCandidateCell.m
//  VVK
//
//  Created by Eigen Lenk on 2/12/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import "VerificationResultCandidateCell.h"

@implementation VerificationResultCandidateCell

@synthesize nameLabel;
@synthesize partyLabel;
@synthesize numberLabel;
@synthesize contentBackgroundView;

- (void)layoutSubviews;
{
    CGRect bounds = [self bounds];
    
    [super layoutSubviews];
    
    for (UIView *subview in [self subviews])
    {
        // Override the subview to make it fill the available width.
        CGRect frame = [subview frame];
        frame.origin.x = bounds.origin.x + 10;
        frame.size.width = bounds.size.width - 20;
        [subview setFrame:frame];
    }
}

@end
