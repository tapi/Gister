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
#import "SSKeychain.h"

#define kPublicGists	@"PublicGists"
#define kServiceKey		@"com.500px.Gister"

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

	if (success) NSLog(@"Successfully registered Gister");
	else NSLog(@"Failed to register Gister");

	
	//Setup UI
	[_gistWindow setReleasedWhenClosed:NO];
	[_gistWindow close];
	[_gistWindow setRestorable:NO];

	[_preferences setReleasedWhenClosed:NO];
	[_preferences close];
	[_preferences setRestorable:NO];

	//Try and login if we have saved credentials
	NSError *accountsError;
	if ([SSKeychain accountsForService:kServiceKey error:&accountsError]) [self performLoginWithSavedCredentials];
	else NSLog(@"Error retrieving accounts, %@", [accountsError localizedDescription]);
	
	//Login was unsuccessful or this is our first run so diplay the login window
	if (!_GHEngine.isReachable) [self displayLoginWindow];
	else [self dismissLoginWindow];
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
	
	if (_GHEngine.isReachable) {
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		
		[_gistContentView setString:@""];
		[_gistContentView readSelectionFromPasteboard:pb type:@"public.utf8-plain-text"];
		
		[_gistWindow orderFrontRegardless];
		[_gistWindow makeKeyWindow];
		[_fileNameField becomeFirstResponder];
	}
}


#pragma mark - Login Window Methods
- (void)dismissLoginWindow
{
	[_window close];
	[[NSRunningApplication currentApplication] hide];
}

- (void)displayLoginWindow
{
	[_window orderFront:nil];
	[_window makeKeyWindow];
	
	[_loginField becomeFirstResponder];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	id sender = [notification object];

	//User hit return from the username field, make the password field the first responder
	if (sender == _loginField && [[sender stringValue] isEqualToString:@""] == NO) [_passwordField becomeFirstResponder];
		
	//User hit return from the password field, attempt to login
	if (sender == _passwordField && [[sender stringValue] isEqualToString:@""] == NO) [self performLoginFromWindow];
}

- (void)performLoginFromWindow
{
	NSString *user = [_loginField stringValue];
	NSString *pass = [_passwordField stringValue];
	
	_GHEngine = [[UAGithubEngine alloc] initWithUsername:user password:pass withReachability:NO];
	if (_GHEngine.isReachable) {
		//Close the login window and get out of the users way
		[self dismissLoginWindow];
		
		//Save the successful login creds
		NSError *keyChainError;
		if (![SSKeychain setPassword:pass forService:kServiceKey account:user error:&keyChainError]) NSLog(@"Error saving password %@", [keyChainError localizedDescription]);
	}
	else {
		//Do error stuff
	}
}

- (void)performLoginWithSavedCredentials
{
	NSError *keyChainError;
	
	//Get our user acct
	NSString *user = [[[SSKeychain accountsForService:kServiceKey error:&keyChainError] lastObject] valueForKey:kSSKeychainAccountKey];
	NSString *pass;

	//If we have a user grab their password
	if (user) pass = [SSKeychain passwordForService:kServiceKey account:user error:&keyChainError];
	else NSLog(@"Error retrieving account, %@", [keyChainError localizedDescription]);

	//Log the password retrieval error if any
	if(!pass) NSLog(@"Error retrieving password, %@", [keyChainError localizedDescription]);
	
	_GHEngine = [[UAGithubEngine alloc] initWithUsername:user password:pass withReachability:NO];
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
	//Get rid of our engine
	self.GHEngine = nil;
	
	//Close the preferences windows
	[_preferences close];

	//remove stored credentials
	NSError *keyChainError;
	
	//Get our user acct
	NSString *user = [[[SSKeychain accountsForService:kServiceKey error:&keyChainError] lastObject] valueForKey:kSSKeychainAccountKey];
	
	//Delete their password if able
	if (!user) NSLog(@"Error retrieving account, %@", [keyChainError localizedDescription]);
	else if (![SSKeychain deletePasswordForService:kServiceKey account:user error:&keyChainError]) NSLog(@"Error deleteing password, %@", [keyChainError localizedDescription]);
	
	[_window orderFront:nil];
	[_window makeKeyWindow];
}

- (IBAction)publicGistsDidChange:(id)sender {
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	id sender = [notification object];
	if (sender == _fileNameField) [_gistWindow setTitle:[sender stringValue]];
}
@end
