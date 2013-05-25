#import <FSSwitch.h>
#import <FSSwitchPanel.h>

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>

@interface SBTelephonyManager
+ (id)sharedTelephonyManager;
- (void)setIsInAirplaneMode:(BOOL)airplaneMode;
- (BOOL)isInAirplaneMode;
@end

@interface AirplaneModeSwitch : NSObject <FSSwitch>
@end

static BOOL enabled;

@implementation AirplaneModeSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [[%c(SBTelephonyManager) sharedTelephonyManager] isInAirplaneMode];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	enabled = newState;
	[[%c(SBTelephonyManager) sharedTelephonyManager] setIsInAirplaneMode:enabled];
}

@end
