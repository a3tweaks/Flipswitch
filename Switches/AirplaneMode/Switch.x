#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>

@interface SBTelephonyManager
+ (id)sharedTelephonyManager;
- (void)setIsInAirplaneMode:(BOOL)airplaneMode;
- (BOOL)isInAirplaneMode;
@end

@interface SBStatusBarController
+ (SBStatusBarController *)sharedStatusBarController;
- (BOOL)airplaneModeIsEnabled;
@end

@interface AirplaneModeSwitch : NSObject <FSSwitchDataSource>
@end

%hook SBTelephonyManager

// Modern iOS versions

- (void)airplaneModeChanged
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[AirplaneModeSwitch class]].bundleIdentifier];
}

// iOS 3.x

- (void)updateAirplaneMode
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[AirplaneModeSwitch class]].bundleIdentifier];
}

%end

@implementation AirplaneModeSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	if ([%c(SBTelephonyManager) instancesRespondToSelector:@selector(isInAirplaneMode)])
		return [[%c(SBTelephonyManager) sharedTelephonyManager] isInAirplaneMode];
	return (FSSwitchState)[[%c(SBStatusBarController) sharedStatusBarController] airplaneModeIsEnabled];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	if ([%c(SBTelephonyManager) instancesRespondToSelector:@selector(setIsInAirplaneMode:)]) {
		[[%c(SBTelephonyManager) sharedTelephonyManager] setIsInAirplaneMode:newState];
	} else {
		void (*enable)(int enabled) = dlsym(RTLD_DEFAULT, "CTPowerSetAirplaneMode");
		if (enable) {
			enable(newState);
		}
	}
}

@end
