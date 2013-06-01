#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <Preferences/Preferences.h>
#import <dlfcn.h>
#import <CaptainHook/CaptainHook.h>

@interface VPNBundleController : PSListController {
@private
	PSSpecifier *_vpnSpecifier;
}
- (id)vpnActiveForSpecifier:(PSSpecifier *)specifier;
- (void)_setVPNActive:(BOOL)active;
@end

static VPNBundleController *controller;

@interface VPNSwitch : NSObject <FSSwitchDataSource>
@end

%hook VPNBundleController

- (void)_vpnStatusChanged:(NSNotification *)notification
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[VPNSwitch class]].bundleIdentifier];
}

%end

@implementation VPNSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	PSSpecifier **specifier = CHIvarRef(controller, _vpnSpecifier, PSSpecifier *);
	return specifier ? [[controller vpnActiveForSpecifier:*specifier] boolValue] : NO;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	[controller _setVPNActive:newState];
}

@end

%ctor {
	// Load VPNPreferences
	dlopen("/System/Library/PreferenceBundles/VPNPreferences.bundle/VPNPreferences", RTLD_LAZY);
	%init();
	// Create root controller
	PSRootController *rootController = [[PSRootController alloc] initWithTitle:@"Preferences" identifier:@"com.apple.Preferences"];
	// Create controller
	controller = [[%c(VPNBundleController) alloc] initWithParentListController:nil];
	if ([controller respondsToSelector:@selector(setRootController:)])
		[controller setRootController:rootController];
	if ([controller respondsToSelector:@selector(setParentController:)])
		[controller setParentController:rootController];
}
