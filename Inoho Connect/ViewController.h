//
//  ViewController.h
//  MyApp
//
//  Created by Ashish Singh on 11/04/15.
//  Copyright (c) 2015 Ashish Singh. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UIWebViewDelegate>

@property (retain, nonatomic) IBOutlet UIWebView *webView;
//@property (nonatomic) Reachability *hostReachability;
@property (nonatomic) InohoConnectionManager * connctnMgr;
@property (nonatomic) NSString * fullURL;
@property (nonatomic) UIActivityIndicatorView *activityIndicator;

@end

