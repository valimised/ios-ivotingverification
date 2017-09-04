//
//  VerificationResultCandidateCell.m
//  VVK

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
