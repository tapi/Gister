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
	
	[_window setRestorable:NO];

	//Try and login if we have saved credentials
	NSError *accountsError;
	
	//If we have no stored credentials log the error and display the login window
	if (![SSKeychain accountsForService:kServiceKey error:&accountsError] || ![self performLoginWithSavedCredentials]) {
		NSLog(@"Error retrieving accounts, %@", [accountsError localizedDescription]);
		[self displayLoginWindow];
	}
	else {
		NSLog(@"Successfully retrieved credentials");
		[self dismissLoginWindow];
		[[NSApplication sharedApplication] hide:[NSApplication sharedApplication]];
	}
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
	
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	[_gistContentView setString:@""];
	[_gistContentView readSelectionFromPasteboard:pb type:@"public.utf8-plain-text"];
	
	[_gistWindow orderFrontRegardless];
	[_gistWindow makeKeyWindow];
	[_fileNameField becomeFirstResponder];
}

#pragma mark - Login Window Methods
- (void)dismissLoginWindow
{
	[_window close];
	
	//If we're not showing the gist window then hide the app
	if (!_gistWindow.isVisible) [[NSApplication sharedApplication] hide:[NSApplication sharedApplication]];
}

- (void)displayLoginWindow
{
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];

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
	
	//Bail early if the user did not enter credentials
	if (user.length == 0 || pass.length == 0) return;
	
	_GHEngine = [[UAGithubEngine alloc] initWithUsername:user password:pass withReachability:NO];
	if (_GHEngine) {
		//Close the login window and get out of the users way if we created our github object
		[self dismissLoginWindow];
		
		//Save the successful login creds
		NSError *keyChainError;
		if (![SSKeychain setPassword:pass forService:kServiceKey account:user error:&keyChainError]) NSLog(@"Error saving password %@", [keyChainError localizedDescription]);
	}
}

//Misnomer, theres no actuall login taking place were just retrieving the credentials from the keychain
- (BOOL)performLoginWithSavedCredentials
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
	
	if (!user || !pass) return NO;
	
	_GHEngine = [[UAGithubEngine alloc] initWithUsername:user password:pass withReachability:NO];
	if (_GHEngine) return YES;
	
	return NO;
}

#pragma mark - Gist Window Methods
- (void)dismissGistWindow
{
	[_gistWindow close];
	[[NSRunningApplication currentApplication] hide];
}

- (IBAction)submitGistDidGetPressed:(id)sender
{
	if (!_GHEngine) {
		[self displayLoginWindow];
		return;
	}
	
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
		[self dismissGistWindow];
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
