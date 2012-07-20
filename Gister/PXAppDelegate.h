//
//  PXAppDelegate.h
//  Gister
//
//  Created by Paddy O'Brien on 12-07-20.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <UAGithubEngine/UAGithubEngine.h>

@interface PXAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *loginField;
@property (weak) IBOutlet NSSecureTextField *passwordField;

@property (strong) IBOutlet NSWindow *gistWindow;
@property (weak) IBOutlet NSTextField *fileNameField;
@property (unsafe_unretained) IBOutlet NSTextView *summaryTextView;
@property (unsafe_unretained) IBOutlet NSTextView *gistContentView;
@property (weak) IBOutlet NSButton *publicGistBox;

@property (strong, nonatomic) UAGithubEngine *GHEngine;
- (IBAction)submitGistDidGetPressed:(id)sender;


@property (unsafe_unretained) IBOutlet NSWindow *preferences;
@property (weak) IBOutlet NSButton *publicDefault;
- (IBAction)openPreferences:(id)sender;
- (IBAction)logout:(id)sender;
- (IBAction)publicGistsDidChange:(id)sender;
@end
