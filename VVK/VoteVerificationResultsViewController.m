//
//  VoteVerificationViewController.m
//  VVK
//
//  Created by Eigen Lenk on 2/3/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import "VoteVerificationResultsViewController.h"
#import "VoteContainer.h"
#import "AppDelegate.h"
#import "UIColor+Hex.h"
#import "VerificationResultCandidateCell.h"

@interface VoteVerificationResultsViewController ()

- (void)setupCloseTimer;
- (void)updateTimerLabel;
- (void)dismiss;

@end

@implementation VoteVerificationResultsViewController

@synthesize presentedModally;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {

    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = [[Config sharedInstance] textForKey:@"lbl_choice"];
    
    self.navigationItem.hidesBackButton = YES;
    
    contentTableView.backgroundColor = [UIColor colorWithHexString:@"#f8f8f8"];
    contentTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    timerCellBackgroundView.backgroundColor = [[Config sharedInstance] colorForKey:@"lbl_close_timeout_background_center"];
    timerCellLabel.textColor = [[Config sharedInstance] colorForKey:@"lbl_close_timeout_foreground"];
    timerCellBackgroundView.layer.cornerRadius = 5.0f;
    
    if ([[[UIDevice currentDevice] systemVersion] doubleValue] >= 7.0)
    {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_close.png"] style:UIBarButtonItemStylePlain target:self action:@selector(dismiss)];
    }
    else
    {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[[Config sharedInstance] textForKey:@"close_button"] style:UIBarButtonItemStyleDone target:self action:@selector(dismiss)];
        
        [contentTableView setSeparatorColor:[UIColor clearColor]];

        contentTableView.backgroundView = nil;
    }
    
    return;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    presentedModally = YES;
    
    [contentTableView reloadData];
    
    [self setupCloseTimer];
}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    groups = nil;
    
    presentedModally = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark - Table view delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1 + [groups count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 1;
    }
    else
    {
        NSString * key = [groups allKeys][section - 1];
        NSArray * candidates = groups[key];
        
        return [candidates count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        return timerCell;
    }
    
    VerificationResultCandidateCell * cell = [tableView dequeueReusableCellWithIdentifier:@"VerificationResultCandidateCell"];
    
    if (cell == nil)
    {
        NSArray * topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"VerificationResultCandidateCell" owner:self options:nil];
        
        cell = [topLevelObjects objectAtIndex:0];
        
        [cell setBackgroundView:nil];
        [cell setBackgroundColor:[UIColor clearColor]];
        [cell.contentBackgroundView.layer setMasksToBounds:YES];

        [cell layoutSubviews];
    }
    
    NSString * key = [groups allKeys][indexPath.section - 1];
    NSArray * candidates = groups[key];
    Candidate * candidate = candidates[indexPath.row];
    
    cell.nameLabel.text = candidate.name;
    cell.partyLabel.text = candidate.party;
    cell.numberLabel.text = [NSString stringWithFormat:@"#%@", [candidate.number componentsSeparatedByString:@"."][1]];
    cell.numberLabel.textColor = [[Config sharedInstance] colorForKey:@"main_window"];

    if (indexPath.row == [candidates count] - 1)
    {
        UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:cell.contentBackgroundView.bounds byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight) cornerRadii:CGSizeMake(7.0, 7.0)];
        
        CAShapeLayer * maskLayer = [CAShapeLayer layer];
        maskLayer.frame = cell.layer.bounds;
        maskLayer.path = maskPath.CGPath;
        cell.contentBackgroundView.layer.mask = maskLayer;
        // cell.contentBackgroundView.backgroundColor = [UIColor redColor];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section >= 1)
    {
        return 78.f;
    }
    
    return 44.f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return (section == 0) ? 10.f : 35.f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == 0) {
        return 20.f;
    }
    
    return 0.f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        UIView * emptyFooter = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 20)];
        
        emptyFooter.backgroundColor = [UIColor clearColor];
        
        return emptyFooter;
    }
    
    return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        UIView * emptyHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 10)];
        emptyHeader.backgroundColor = [UIColor clearColor];
        return emptyHeader;
    }
    
    NSString * key = [groups allKeys][section - 1];
    VoteContainer * voteContainer = [SharedDelegate currentVoteContainer];
    Ballot * electionDetails = voteContainer.ballots[key];

    UIView * headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 30)];
    
    headerView.backgroundColor = tableView.backgroundColor;
    
    UIView * bgView = [[UIView alloc] initWithFrame:CGRectMake(10, 5, 300, 30)];
    
    bgView.backgroundColor = [UIColor colorWithHexString:@"#f1f1f1"];
    
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:bgView.bounds byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight) cornerRadii:CGSizeMake(5.0, 5.0)];
    
    CAShapeLayer * maskLayer = [CAShapeLayer layer];
    maskLayer.frame = bgView.layer.bounds;
    maskLayer.path = maskPath.CGPath;
    bgView.layer.mask = maskLayer;

    
    UILabel * titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 250, 30)];
    
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:14.0];
    titleLabel.text = electionDetails.name;
    titleLabel.textColor = [UIColor colorWithHexString:@"#717171"];
    
    [headerView addSubview:bgView];
    [bgView addSubview:titleLabel];
    
    return headerView;
}


#pragma mark - Public methods

- (void)handleResults:(in NSArray *)results
{
    NSMutableDictionary * _groups = [NSMutableDictionary dictionary];

    for (Candidate * candidate in results)
    {
        NSMutableArray * matchesForElection = _groups[candidate.ballot.name];
        
        if (!matchesForElection)
        {
            matchesForElection = [NSMutableArray array];
            
            [_groups setObject:matchesForElection forKey:candidate.ballot.name];
        }
        
        [matchesForElection addObject:candidate];
    }

    groups = _groups;
    
    _groups = nil;
}


#pragma mark - Private methods

- (void)setupCloseTimer
{
    timerLaunchTimestamp = [[NSDate date] timeIntervalSince1970];
    
    double closeInterval = ([[[Config sharedInstance] getParameter:@"close_interval"] intValue] / 1000.0);
    
    closeTickTimer = [NSTimer scheduledTimerWithTimeInterval:closeInterval target:self selector:@selector(updateTimerLabel) userInfo:nil repeats:YES];
    
    [self updateTimerLabel];
}

- (void)updateTimerLabel
{
    double closeTime = ([[[Config sharedInstance] getParameter:@"close_timeout"] intValue] / 1000.0);
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval timeLeft = (closeTime - (now - timerLaunchTimestamp));
    
    if (timeLeft <= 0.0)
    {
        [closeTickTimer invalidate];
        
        closeTickTimer = nil;
        
        [self dismissModalViewControllerAnimated:YES];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:shouldRestartApplicationState object:nil];
        
        return;
    }
    
    NSMutableString * labelText = [[[Config sharedInstance] textForKey:@"lbl_close_timeout"] mutableCopy];
                                   
   [labelText replaceOccurrencesOfString:@"XX" withString:[NSString stringWithFormat:@"%.0f", timeLeft] options:NSCaseInsensitiveSearch range:NSMakeRange(0, labelText.length)];
    
    timerCellLabel.text = labelText;
}

- (void)dismiss
{
    [closeTickTimer invalidate];
    
    closeTickTimer = nil;
    
    [self dismissModalViewControllerAnimated:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:shouldRestartApplicationState object:nil];
}

@end