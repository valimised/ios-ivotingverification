//
//  VoteVerificationViewController.m
//  VVK

#import "VoteVerificationResultsViewController.h"
#import "Candidate.h"
#import "AppDelegate.h"
#import "UIColor+Hex.h"
#import "VerificationResultCandidateCell.h"
#import "C.h"
#import "AccessibilityUtil.h"
#import "ScaledFonts.h"

@interface VoteVerificationResultsViewController ()

- (void) setupCloseTimer;
- (void) updateTimerLabel;

@end

@implementation VoteVerificationResultsViewController

@synthesize presentedModally;


- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return (UIInterfaceOrientationMaskPortrait |
            UIInterfaceOrientationMaskLandscapeLeft |
            UIInterfaceOrientationMaskLandscapeRight);
}


- (id) initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if (self) {
    }

    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    [self setupNavigationBar];
    contentTableView.backgroundColor = [UIColor whiteColor];
    contentTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    timerCellBackgroundView.backgroundColor = [[C sharedInstance] lblCloseTimeoutBackgroundCenter];
    timerCellLabel.textColor = [[C sharedInstance] lblCloseTimeoutForeground];
    [[ScaledFonts sharedInstance] applyScaledFontToUILabel:timerCellLabel];
    timerCellBackgroundView.layer.cornerRadius = 5.0f;
    [self setTimerCellHeight];
    [contentTableView setEstimatedRowHeight:78];
    return;
}

- (void) setupNavigationBar
{
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = [[Config sharedInstance] textForKey:@"lbl_choice"];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.navigationItem.titleView = titleLabel;
  
    UIImage *image = [UIImage imageNamed:@"btn_close.png"];
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithImage:image
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(dismiss:)];
    leftButton.accessibilityLabel = [[Config sharedInstance] textForKey:@"btn_close"];
    leftButton.accessibilityTraits = UIAccessibilityTraitButton;
    self.navigationItem.leftBarButtonItem = leftButton;
    
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [UIColor systemCyanColor]; // navigation bar + status bar color
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    self.navigationController.navigationBar.compactAppearance = appearance;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    presentedModally = YES;
    [contentTableView reloadData];
    [self setupCloseTimer];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self setAccessibleElementsHidden:true];
    int timeLimit = ([[[Config sharedInstance] getParameter:@"close_timeout"] intValue] / 1000);
    [[AccessibilityUtil sharedInstance] informAboutTimeLimit:[NSString stringWithFormat:@"%d", timeLimit]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setAccessibleElementsHidden:false];
        [[AccessibilityUtil sharedInstance] setDefaultAccesibilityFocusOnView:(UILabel *)self.navigationItem.titleView];
    });
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    groups = nil;
    presentedModally = NO;
}

- (void)appDidBecomeActive {
    [self setTimerCellHeight];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark - Table view delegate

- (NSInteger) numberOfSectionsInTableView:(UITableView*)tableView
{
    return 1 + [groups count];
}

- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    }
    else {
        NSString* key = [groups allKeys][section - 1];
        NSArray* candidates = groups[key];
        return [candidates count];
    }
}

- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    if (indexPath.section == 0) {
        return timerCell;
    }

    VerificationResultCandidateCell* cell = [tableView dequeueReusableCellWithIdentifier:
                                             @"VerificationResultCandidateCell"];

    if (cell == nil) {
        NSArray* topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"VerificationResultCandidateCell"
                                                                 owner:self options:nil];
        cell = [topLevelObjects objectAtIndex:0];
        [cell setBackgroundView:nil];
        [cell setBackgroundColor:[UIColor clearColor]];
        [cell.contentBackgroundView.layer setMasksToBounds:YES];
        [cell layoutSubviews];
    }

    NSString* key = [groups allKeys][indexPath.section - 1];
    NSArray* candidates = groups[key];
    Candidate* candidate = candidates[indexPath.row];
    cell.nameLabel.text = candidate.name;
    cell.nameLabel.textColor = [[C sharedInstance] lblInnerContainerForeground];
    cell.nameLabel.numberOfLines = 0;
    [cell.nameLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    cell.partyLabel.text = candidate.party;
    cell.partyLabel.textColor = [[C sharedInstance] lblInnerContainerForeground];
    cell.partyLabel.numberOfLines = 0;
    [cell.partyLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    cell.numberLabel.text = [NSString stringWithFormat:@"#%@", [candidate.number
                                                                componentsSeparatedByString:@"."][1]];
    cell.numberLabel.backgroundColor = [[C sharedInstance] lblBackground];
    cell.numberLabel.textColor = [[C sharedInstance] lblForeground];
    cell.contentView.layer.borderWidth = 1.5;
    cell.contentView.layer.borderColor = [[C sharedInstance] lblOuterInnerContainerDivider].CGColor;
    if (!(cell.tag == 1000)) {
        [[ScaledFonts sharedInstance] applyScaledFontToUILabel:cell.nameLabel];
        [[ScaledFonts sharedInstance] applyScaledFontToUILabel:cell.partyLabel];
        [[ScaledFonts sharedInstance] applyScaledFontToUILabel:cell.numberLabel];
        cell.tag = 1000; // Tag is used to avoid rescaling the fonts after orientation change
    }
    return cell;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [contentTableView reloadData];
}

- (void) tableView:(UITableView*)tableView willDisplayCell:(UITableViewCell*)cell forRowAtIndexPath
    :(NSIndexPath*)indexPath
{
    if (indexPath.section == 0) {
        return;
    }

    NSString* key = [groups allKeys][indexPath.section - 1];
    NSArray* candidates = groups[key];

    if (indexPath.row == [candidates count] - 1) {
        VerificationResultCandidateCell* customCell = (VerificationResultCandidateCell*) cell;
        CGRect frame = [customCell bounds];
        UIBezierPath* maskPath = [UIBezierPath bezierPathWithRoundedRect:frame byRoundingCorners:
                                               (UIRectCornerBottomLeft | UIRectCornerBottomRight) cornerRadii:CGSizeMake(7.0, 7.0)];
        CAShapeLayer* maskLayer = [CAShapeLayer layer];
        maskLayer.frame = cell.layer.bounds;
        maskLayer.path = maskPath.CGPath;
        customCell.contentBackgroundView.layer.mask = maskLayer;
    }
}

- (CGFloat) tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath
{
    if (indexPath.section >= 1) {
        return UITableViewAutomaticDimension;
    }

    return timerCellLabel.frame.size.height;
}

- (CGFloat) tableView:(UITableView*)tableView heightForHeaderInSection:(NSInteger)section
{
    return (section == 0) ? 10.f : [self getTitleLabelMaxHeight];
}

- (CGFloat) tableView:(UITableView*)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == 0) {
        return 20.f;
    }

    return 0.f;
}

- (UIView*) tableView:(UITableView*)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == 0) {
        UIView* emptyFooter = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width,
                                              20)];
        emptyFooter.backgroundColor = [UIColor clearColor];
        return emptyFooter;
    }

    return nil;
}

- (UIView*) tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section
{
    CGFloat w = tableView.bounds.size.width;

    if (section == 0) {
        UIView* emptyHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 10)];
        emptyHeader.backgroundColor = [UIColor clearColor];
        return emptyHeader;
    }

    UIView* headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 5, w, [self getTitleLabelMaxHeight])];
    headerView.backgroundColor = tableView.backgroundColor;
    UIView* bgView = [[UIView alloc] initWithFrame:CGRectMake(10, 0, w - 20, headerView.frame.size.height)];
    bgView.backgroundColor = [[C sharedInstance] lblOuterContainerBackground];
    UIBezierPath* maskPath = [UIBezierPath bezierPathWithRoundedRect:bgView.bounds byRoundingCorners:
                                           (UIRectCornerTopLeft | UIRectCornerTopRight) cornerRadii:CGSizeMake(5.0, 5.0)];
    CAShapeLayer* maskLayer = [CAShapeLayer layer];
    maskLayer.frame = bgView.layer.bounds;
    maskLayer.path = maskPath.CGPath;
    bgView.layer.mask = maskLayer;
    UILabel* titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, bgView.frame.size.width - 30, bgView.frame.size.height)];
    titleLabel.center = bgView.center;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:14.0];
    titleLabel.text = [groups allKeys][section - 1];
    titleLabel.textColor = [[C sharedInstance] lblOuterContainerForeground];
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    titleLabel.numberOfLines = 0;
    titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [[ScaledFonts sharedInstance] applyScaledFontToUILabel:titleLabel];
    [bgView addSubview:titleLabel];
    [headerView addSubview:bgView];
    return headerView;
}


#pragma mark - Public methods

- (void) handleResults:(in NSDictionary*)results
{
    NSMutableDictionary* _groups = [NSMutableDictionary dictionary];

    for (NSString * key in results) {
        NSMutableArray* matchesForElection = _groups[key];

        if (!matchesForElection) {
            matchesForElection = [NSMutableArray array];
            [_groups setObject:matchesForElection forKey:key];
        }

        [matchesForElection addObject:[results objectForKey:key]];
    }

    groups = _groups;
    _groups = nil;
}


#pragma mark - Private methods

- (void) setupCloseTimer
{
    timerLaunchTimestamp = [[NSDate date] timeIntervalSince1970];
    double closeInterval = ([[[Config sharedInstance] getParameter:@"close_interval"] intValue] /
                            1000.0);
    closeTickTimer = [NSTimer scheduledTimerWithTimeInterval:closeInterval target:self selector:
                              @selector(updateTimerLabel) userInfo:nil repeats:YES];
    [self updateTimerLabel];
}

- (void) updateTimerLabel
{
    double closeTime = ([[[Config sharedInstance] getParameter:@"close_timeout"] intValue] / 1000.0);
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval timeLeft = (closeTime - (now - timerLaunchTimestamp));

    if (timeLeft <= 0.0) {
        [closeTickTimer invalidate];
        closeTickTimer = nil;
        [self dismissViewControllerAnimated:YES completion:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:shouldRestartApplicationState object:
                                              nil];
        return;
    } else if ((int)timeLeft == 5) {
        [[AccessibilityUtil sharedInstance] informAboutTimeLimit:@"5"];
    }

    NSMutableString* labelText = [[[Config sharedInstance] textForKey:@"lbl_close_timeout"]
                                                           mutableCopy];
    [labelText replaceOccurrencesOfString:@"XX" withString:[NSString stringWithFormat:@"%.0f",
                      timeLeft] options:NSCaseInsensitiveSearch range:NSMakeRange(0, labelText.length)];
    timerCellLabel.text = labelText;
}

- (CGFloat) getTitleLabelMaxHeight
{
    CGFloat maxTextHeight = 0;
    UIFont *scaledFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[UIFont systemFontOfSize:14.0]];
    NSArray* allTitles = [groups allKeys];
    for (NSString *title in allTitles) {
        NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:title
                                                                                     attributes:@{NSFontAttributeName: scaledFont}];
        CGRect rect = [attributedText boundingRectWithSize:(CGSize) {
                           contentTableView.bounds.size.width, MAXFLOAT
                       }
                       options: NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                       context: nil];
        maxTextHeight = MAX(maxTextHeight, ceil(rect.size.height));
    }

    CGFloat rectHeight = maxTextHeight;
    CGFloat lineHeight = scaledFont.lineHeight;
    int lines = (int)ceil(rectHeight / lineHeight);
    CGFloat finalHeight = lines * lineHeight;

    return MAX(35, finalHeight + 8);
}

- (void) setTimerCellHeight
{
    timerCellBackgroundView.frame = CGRectMake(timerCellBackgroundView.frame.origin.x, timerCellBackgroundView.frame.origin.y, timerCellBackgroundView.bounds.size.width, [self getTimerCellRowHeight]);
    timerCellLabel.frame = CGRectMake(timerCellLabel.frame.origin.x, timerCellLabel.frame.origin.y, timerCellLabel.bounds.size.width, [self getTimerCellRowHeight]);
}

- (CGFloat) getTimerCellRowHeight
{
    NSAttributedString* attributedText =
        [[NSAttributedString alloc] initWithString:timerCellLabel.text
                                    attributes:@ {NSFontAttributeName:timerCellLabel.font}];
    CGRect rect = [attributedText boundingRectWithSize:(CGSize) {
                       timerCellLabel.bounds.size.width, MAXFLOAT
                   }
                   options: NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                   context: nil];

    CGFloat rectHeight = rect.size.height;
    CGFloat lineHeight = timerCellLabel.font.lineHeight;
    int lines = (int)ceil(rectHeight / lineHeight);
    CGFloat finalHeight = lines * lineHeight;

    return MAX(44.f, finalHeight + 16);
}

// Hide elements from VoiceOver for couple of seconds so it can inform the user (without interruptions) about the time limit
- (void) setAccessibleElementsHidden:(BOOL)boolean
{
    self.navigationItem.titleView.accessibilityElementsHidden = boolean;
    self.navigationItem.leftBarButtonItem.accessibilityElementsHidden = boolean;
    timerCellLabel.accessibilityElementsHidden = boolean;
    contentTableView.accessibilityElementsHidden = boolean;
}

- (IBAction) dismiss:(id)sender
{
    [closeTickTimer invalidate];
    closeTickTimer = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:shouldRestartApplicationState object:
                                          nil];
}

@end
