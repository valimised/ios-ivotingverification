//
//  VoteVerificationViewController.h
//  VVK

#import <UIKit/UIKit.h>

@interface VoteVerificationResultsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
{
    IBOutlet UITableView * contentTableView;
    IBOutlet UITableViewCell * timerCell;
    
    IBOutlet UIView * timerCellBackgroundView;
    IBOutlet UILabel * timerCellLabel;
    
    BOOL presentedModally;

    @private
    __strong NSDictionary * groups;
    __strong NSTimer * closeTickTimer;
    NSTimeInterval timerLaunchTimestamp;
}

@property (nonatomic, readonly) BOOL presentedModally;

- (void)handleResults:(in NSDictionary *)results;

@end
