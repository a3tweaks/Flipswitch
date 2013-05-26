#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>

@interface SBTelephonyManager
+ (id)sharedTelephonyManager;
- (void)setIsInAirplaneMode:(BOOL)airplaneMode;
- (BOOL)isInAirplaneMode;
@end

@interface AirplaneModeSwitch : NSObject <FSSwitchDataSource>
@end

%hook SBTelephonyManager

- (void)airplaneModeChanged
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[AirplaneModeSwitch class]].bundleIdentifier];
}

%end

@implementation AirplaneModeSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [[%c(SBTelephonyManager) sharedTelephonyManager] isInAirplaneMode];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	[[%c(SBTelephonyManager) sharedTelephonyManager] setIsInAirplaneMode:newState];
}

@end
