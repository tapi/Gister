//
//  PXAppDelegate.m
//  Gister
//
//  Created by Paddy O'Brien on 12-07-20.
//  Copyright (c) 2012 500px. All rights reserved.
//

#import "PXAppDelegate.h"
#import <Carbon/Carbon.h>
#import "DDHotKeyCenter.h"

#define kPublicGists @"PublicGists"

@implementation PXAppDelegate
@synthesize preferences = _preferences;
@synthesize publicDefault = _publicDefault;

@synthesize window = _window;
@synthesize loginField = _loginField;
@synthesize passwordField = _passwordField;
@synthesize gistWindow = _gistWindow;
@synthesize fileNameField = _fileNameField;
@synthesize summaryTextView = _summaryTextView;
@synthesize gistContentView = _gistContentView;
@synthesize publicGistBox = _publicGistBox;
@synthesize GHEngine = _GHEngine;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	//Set Initial Preferences
	NSUserDefaultsController *defaultsController = [NSUserDefaultsController sharedUserDefaultsController];
	[defaultsController setInitialValues:@{ kPublicGists : @YES }];
	
	//Register Hot Key handler
	unsigned short keyCode = 0x5;			//G
	NSUInteger modifierFlags = NSCommandKeyMask|NSShiftKeyMask;
	
	DDHotKeyCenter *keyCenter = [[DDHotKeyCenter alloc] init];
	BOOL success = [keyCenter registerHotKeyWithKeyCode:keyCode modifierFlags:modifierFlags target:self action:@selector(hotkeyAction:) object:nil];
	if (success)
		NSLog(@"Successfully registered Gister");
	else
		NSLog(@"Failed to register Gister");

	
	//Setup UI
	[_gistWindow setReleasedWhenClosed:NO];
	[_gistWindow close];
	[_gistWindow setRestorable:NO];

	[_preferences setReleasedWhenClosed:NO];
	[_preferences close];
	[_preferences setRestorable:NO];
	
	[_window orderFront:nil];
	[_window makeKeyWindow];
	
	[_loginField becomeFirstResponder];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	DDHotKeyCenter *keyCenter = [[DDHotKeyCenter alloc] init];
	[keyCenter unregisterHotKeysWithTarget:self action:@selector(hotkeyAction:)];
	NSLog(@"Unregistered Gister");
}

- (void)hotkeyAction:(NSEvent*)hotKeyEvent
{
	NSLog(@"Gister recieved key");
	
	if (_GHEngine)
	{
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		
		[_gistContentView setString:@""];
		[_gistContentView readSelectionFromPasteboard:pb type:@"public.utf8-plain-text"];
		
		[_gistWindow orderFrontRegardless];
		[_gistWindow makeKeyWindow];
		[_fileNameField becomeFirstResponder];
	}
}


#pragma mark - Login Window Methods
- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	id sender = [notification object];
	if (sender == _loginField && [[sender stringValue] isEqualToString:@""] == NO)
	{
		[_passwordField becomeFirstResponder];
	}
	
	if (sender == _passwordField && [[sender stringValue] isEqualToString:@""] == NO)
	{
		[self login];
	}
}

- (void)login
{
	NSString *user = [_loginField stringValue];
	NSString *pass = [_passwordField stringValue];
	
	_GHEngine = [[UAGithubEngine alloc] initWithUsername:user password:pass withReachability:NO];
	if (_GHEngine)
	{
		[_window close];
		[[NSRunningApplication currentApplication] hide];
	}
}


#pragma mark - Gist Window Methods
- (IBAction)submitGistDidGetPressed:(id)sender
{
	NSString *fileName = [_fileNameField stringValue];
	NSString *summary = [_summaryTextView string];
	
	
	NSDictionary *gist = @{
		@"description": summary,
		@"public": @YES,
		@"files": @{
			fileName: @{
				@"content": [_gistContentView string]
			}
		}
	};
	
	[_GHEngine createGist:gist success:^(NSArray *response) {
		NSDictionary *gistResponse = [response objectAtIndex:0];
		NSString *gistURL = [gistResponse valueForKey:@"html_url"];
		
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		[pb clearContents];
		[pb writeObjects:@[ gistURL]];
	} failure:^(NSError *error) {
		//TODO: do something to indicate error
		NSLog(@"We suck: %@", [error localizedDescription]);
	}];
}

- (IBAction)openPreferences:(id)sender
{
	[_preferences orderFrontRegardless];
	[_preferences makeKeyWindow];
}

- (IBAction)logout:(id)sender
{
	self.GHEngine = nil;
	
	[_preferences close];
	
	[_window orderFront:nil];
	[_window makeKeyWindow];
}

- (IBAction)publicGistsDidChange:(id)sender {
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	id sender = [notification object];
	if (sender == _fileNameField)
	{
		[_gistWindow setTitle:[sender stringValue]];
	}
}
@end
