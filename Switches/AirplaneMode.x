#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>

@interface AirplaneModeSwitch : NSObject <FSSwitchDataSource>
@end

static void UpdateAirplaneModeStatus(void)
{
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.airplane-mode"];
}

%hook SBTelephonyManager

// Modern iOS versions

- (void)airplaneModeChanged
{
	%orig();
	UpdateAirplaneModeStatus();
}

// iOS 3.x

- (void)updateAirplaneMode
{
	%orig();
	UpdateAirplaneModeStatus();
}

%end

static BOOL justSwitchedAirplaneModeOff;

@implementation AirplaneModeSwitch

- (void)timeOutAirplaneMode
{
	justSwitchedAirplaneModeOff = NO;
	UpdateAirplaneModeStatus();
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (justSwitchedAirplaneModeOff) {
		return FSSwitchStateOff;
	}
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
	// Workaround for the airplane mode for turning off airplane mode taking effect after a short delay and the wrong status
	// getting returned if queried immediately afterwards. Shows as the wrong status in the popup text in FlipControlCenter, among others
	if (newState == FSSwitchStateOff) {
		justSwitchedAirplaneModeOff = YES;
		[self performSelector:@selector(timeOutAirplaneMode) withObject:nil afterDelay:0.75];
	}
}

@end
