//
//  ViewController.m
//  MyApp
//
//  Created by Ashish Singh on 11/04/15.
//  Copyright (c) 2015 Ashish Singh. All rights reserved.
//


#import "InohoConnectionManager.h"
#import "ViewController.h"

//@interface ViewController ()
//
//@end

@implementation ViewController

- (id)initWithCoder:(NSCoder *)aDecoder {
    
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        // Custom initialization
        NSLog(@"Was called...");
    }
    
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Custom initialization
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.activityIndicator.frame = CGRectMake(0, 20, self.view.frame.size.width, self.view.frame.size.height);
    [self.view addSubview:self.activityIndicator];

}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.activityIndicator startAnimating];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kInohoConnectionChangeNotification object:nil];
    
    self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
    self.webView.autoresizesSubviews = YES;
    
    self.connctnMgr = [[InohoConnectionManager alloc] init];
    
    if([self.connctnMgr initializeConnectionManager]) {
        //if init passes then lets get the URL
        [self loadWebView];
    } else {
        //if it fails then show OFFLINE Message
        [self.webView loadHTMLString:@"<h1> <font color=\"Red\"> You are offline!!!</font> </h1>" baseURL: NULL];
    }
}

-(void) loadWebView {
    self.fullURL = [self.connctnMgr getUrlToLoad];
    NSURL *url = [NSURL URLWithString:self.fullURL];
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:requestObj];
}

- (void) reachabilityChanged:(NSNotification *)note {
    InohoConnectionManager* curReach = [note object];
    NSParameterAssert([curReach isKindOfClass:[InohoConnectionManager class]]);
    if([curReach currentConnectionState]) {
        [self loadWebView];
    } else {
        [self.webView loadHTMLString:@"<h1> You are offline!!!</h1>" baseURL: NULL];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"Error");
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    //[self.activityIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    //Check here if still webview is loding the content
    if (webView.isLoading)
        return;
    else {//finished
        NSLog(@"Webview loding finished");
        [self.activityIndicator stopAnimating];
    }
}

- (void)webView:(UIWebView *)webView :(NSError *)error {
    NSLog(@"Error");
}


- (void)viewDidLayoutSubviews {
    self.webView.frame = CGRectMake(0, 20, self.view.frame.size.width, self.view.frame.size.height);
}

@end
