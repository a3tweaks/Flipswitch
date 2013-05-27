#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <Preferences/Preferences.h>
#import <dlfcn.h>

@interface WirelessModemController : PSListController {
}
- (id)internetTethering:(PSSpecifier *)specifier;
- (void)setInternetTethering:(id)value specifier:(PSSpecifier *)specifier;
@end

static WirelessModemController *controller;
static PSSpecifier *specifier;
static NSInteger insideSwitch;

%hook UIAlertView

- (void)show
{
	if (insideSwitch) {
		// Make sure we're suppressing the right alert view
		if ([[self buttons] count] == 2) {
			id<UIAlertViewDelegate> delegate = [self delegate];
			if ([delegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)]) {
				[delegate alertView:self clickedButtonAtIndex:0];
				return;
			}
		}
	}
	%orig();
}

%end

%hook WirelessModemController

- (void)_btPowerChangedHandler:(NSNotification *)notification
{
	// Just eat it!
}

%end

@interface HotspotSwitch : NSObject <FSSwitchDataSource>
@end

%hook SBTelephonyManager

- (void)noteWirelessModemChanged
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[HotspotSwitch class]].bundleIdentifier];
}

%end

@implementation HotspotSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [[controller internetTethering:specifier] boolValue];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	insideSwitch++;
	[controller setInternetTethering:[NSNumber numberWithBool:newState] specifier:specifier];
	insideSwitch--;
}

@end

%ctor {
	// Load WirelessModemSettings
	dlopen("/System/Library/PreferenceBundles/WirelessModemSettings.bundle/WirelessModemSettings", RTLD_LAZY);
	%init();
	// Create root controller
	PSRootController *rootController = [[PSRootController alloc] initWithTitle:@"Preferences" identifier:@"com.apple.Preferences"];
	// Create controller
	controller = [[%c(WirelessModemController) alloc] initForContentSize:(CGSize){ 0.0f, 0.0f }];
	[controller setRootController:rootController];
	[controller setParentController:rootController];
	// Create Specifier
	specifier = [[PSSpecifier preferenceSpecifierNamed:@"Tethering" target:controller set:@selector(setInternetTethering:specifier:) get:@selector(internetTethering:) detail:Nil cell:PSSwitchCell edit:Nil] retain];
}
