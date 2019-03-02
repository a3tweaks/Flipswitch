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

%group iOS10Below
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
%end

%group iOS11
%hook SBAirplaneModeController

- (void)airplaneModeChanged
{
	%orig();
	UpdateAirplaneModeStatus();
}

%end
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

	if (%c(SBAirplaneModeController)) {
		return [[%c(SBAirplaneModeController) sharedInstance] inAirplaneMode];
	} else if ([%c(SBTelephonyManager) instancesRespondToSelector:@selector(isInAirplaneMode)]) {
		return [[%c(SBTelephonyManager) sharedTelephonyManager] isInAirplaneMode];
	}
		
	return (FSSwitchState)[[%c(SBStatusBarController) sharedStatusBarController] airplaneModeIsEnabled];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;

	if (%c(SBAirplaneModeController)) {
		[[%c(SBAirplaneModeController) sharedInstance] setInAirplaneMode:newState];
	} else if ([%c(SBTelephonyManager) instancesRespondToSelector:@selector(setIsInAirplaneMode:)]) {
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

%ctor
{
	if (%c(SBAirplaneModeController)) {
		%init(iOS11);
	} else {
		%init(iOS10Below);
	}
}