#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <Preferences/Preferences.h>
#import <dlfcn.h>
#import <CaptainHook/CaptainHook.h>

static VPNBundleController *controller;

@interface VPNSwitch : NSObject <FSSwitchDataSource>
@end

static void VPNSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	FSSwitchPanel *panel = [FSSwitchPanel sharedPanel];
	[panel stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.vpn"];
	[panel performSelector:@selector(stateDidChangeForSwitchIdentifier:) withObject:@"com.a3tweaks.switch.vpn" afterDelay:0.1];
}

%hook VPNBundleController

- (void)_vpnStatusChanged:(NSNotification *)notification
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.vpn"];
}

- (void)vpnStatusChanged:(NSNotification *)notification
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.vpn"];
}

%end

@implementation VPNSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	PSSpecifier **specifier = CHIvarRef(controller, _vpnSpecifier, PSSpecifier *);
	return specifier ? [[controller vpnActiveForSpecifier:*specifier] boolValue] : FSSwitchStateOff;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	if ([controller respondsToSelector:@selector(_setVPNActive:)]) {
		[controller _setVPNActive:newState];
	} else {
		[controller setVPNActive:newState];
	}
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
	if ([controller respondsToSelector:@selector(specifiersWithSpecifier:)])
		[controller specifiersWithSpecifier:nil];
	if ([controller respondsToSelector:@selector(initSC)])
		[controller initSC];
	CFNotificationCenterRef center = CFNotificationCenterGetLocalCenter();
	CFNotificationCenterAddObserver(center, NULL, VPNSettingsChanged, CFSTR("SBVPNConnectionChangedNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}
