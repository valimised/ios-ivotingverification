//
//  VerificationResultCandidateCell.h
//  VVK

#import <UIKit/UIKit.h>

@interface VerificationResultCandidateCell : UITableViewCell
{
    IBOutlet UILabel * nameLabel;
    IBOutlet UILabel * partyLabel;
    IBOutlet UILabel * numberLabel;
    IBOutlet UIView * contentBackgroundView;
}

@property (nonatomic, readonly) UILabel * nameLabel;
@property (nonatomic, readonly) UILabel * partyLabel;
@property (nonatomic, readonly) UILabel * numberLabel;
@property (nonatomic, readonly) UIView * contentBackgroundView;

@end
