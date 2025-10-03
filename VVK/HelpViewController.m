	//
//  HelpViewController.m
//  VVK

#import "HelpViewController.h"

@interface HelpViewController ()

- (void) close;

@end

@implementation HelpViewController

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return (UIInterfaceOrientationMaskPortrait |
            UIInterfaceOrientationMaskLandscapeLeft |
            UIInterfaceOrientationMaskLandscapeRight);
}

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
    [self setupTopBarsStyle];
    NSString* productURL = [[Config sharedInstance] getParameter:@"help_url"];
    NSURL* url = [NSURL URLWithString:productURL];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    webView = [[WKWebView alloc] initWithFrame:self.view.frame];
    [webView loadRequest:request];
    [self.view addSubview:webView];
    [self excludeWebKitDataFromBackup];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation]) && self.view.frame.size.height > self.view.frame.size.width) {
            webView.frame = CGRectMake(5, 0, self.view.frame.size.height, self.view.frame.size.width);
    } else {
        webView.frame = CGRectMake(5, 0, self.view.frame.size.width, self.view.frame.size.height);
    }
}

#pragma mark - Private methods

- (void) close
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:shouldRestartApplicationState object:
                                          nil];
}

- (void)viewWillTransitionToSize:(CGSize)size
    withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    webView.frame = CGRectMake(5, 0, size.width, size.height);
}

- (void) setupTopBarsStyle
{
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = self.navigationController.navigationBar.backgroundColor;
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor]}];
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
}

- (void)excludeWebKitDataFromBackup
{
    // Get path to WebsiteData folder inside app/Library
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryPath = [paths firstObject];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *webkitDataPath = [libraryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"WebKit/%@/WebsiteData", bundleID]];
    NSURL *webkitURL = [NSURL fileURLWithPath:webkitDataPath];

    BOOL pathIsDir = NO;
    BOOL pathExists = [[NSFileManager defaultManager] fileExistsAtPath:webkitDataPath isDirectory:&pathIsDir];
    
    if (pathExists && pathIsDir) {
        // Exclude WebKit data from backup
        NSError *error = nil;
        BOOL success = [webkitURL setResourceValue:@(YES)
                                      forKey:NSURLIsExcludedFromBackupKey
                                       error:&error];
        if (success) {
            DLog(@"WebKit data is excluded from backup");
        } else {
            DLog(@"Error excluding %@ from backup: %@", [webkitURL lastPathComponent], error);
        }
    } else {
        DLog(@"Unable to exclude %@ from backup: pathExists=%@, pathIsDir=%@",
             [webkitURL lastPathComponent],
             pathExists ? @"YES" : @"NO",
             pathIsDir ? @"YES" : @"NO");
    }
}

@end
