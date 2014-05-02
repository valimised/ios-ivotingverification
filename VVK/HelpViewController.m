//
//  HelpViewController.m
//  VVK
//
//  Created by Eigen Lenk on 2/13/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import "HelpViewController.h"

@interface HelpViewController ()

- (void)close;

@end

@implementation HelpViewController

#pragma mark - View life cycle

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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationItem.title = [[Config sharedInstance] textForKey:@"btn_more"];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[[Config sharedInstance] textForKey:@"close_button"] style:UIBarButtonItemStyleDone target:self action:@selector(close)];
    
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[[Config sharedInstance] getParameter:@"help_url"]]]];
}


#pragma mark - Private methods

- (void)close {
    [self dismissModalViewControllerAnimated:YES];
}

@end
