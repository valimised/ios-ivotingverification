//
//  VerificationResultCandidateCell.h
//  VVK
//
//  Created by Eigen Lenk on 2/12/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

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
