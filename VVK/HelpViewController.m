	//
//  HelpViewController.m
//  VVK

#import "HelpViewController.h"

@interface HelpViewController ()

- (void) close;

@end

@implementation HelpViewController

#pragma mark - View life cycle

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
    self.navigationItem.title = [[Config sharedInstance] textForKey:@"btn_more"];
    NSString* closeTxt = [[Config sharedInstance] textForKey:@"btn_close"];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:closeTxt style:
                                                                    UIBarButtonItemStyleDone target:self action:@selector(close)];
    NSString* productURL = [[Config sharedInstance] getParameter:@"help_url"];
    NSURL* url = [NSURL URLWithString:productURL];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    webView = [[WKWebView alloc] initWithFrame:self.view.frame];
    [webView loadRequest:request];
    webView.frame = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y,
                               self.view.frame.size.width, self.view.frame.size.height);
    [self.view addSubview:webView];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}


#pragma mark - Private methods

- (void) close
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:shouldRestartApplicationState object:
                                          nil];
}

@end
