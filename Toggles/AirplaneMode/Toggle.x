#import <A3Toggle.h>
#import <A3ToggleManager.h>

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>

@interface SBTelephonyManager
+ (id)sharedTelephonyManager;
- (void)setIsInAirplaneMode:(BOOL)airplaneMode;
- (BOOL)isInAirplaneMode;
@end

@interface AirplaneModeToggle : NSObject <A3Toggle>
@end

static BOOL enabled;

@implementation AirplaneModeToggle

- (A3ToggleState)stateForToggleIdentifier:(NSString *)toggleIdentifier
{
	return [[%c(SBTelephonyManager) sharedTelephonyManager] isInAirplaneMode];
}

- (void)applyState:(A3ToggleState)newState forToggleIdentifier:(NSString *)toggleIdentifier
{
	if (newState == A3ToggleStateIndeterminate)
		return;
	enabled = newState;
	[[%c(SBTelephonyManager) sharedTelephonyManager] setIsInAirplaneMode:enabled];
}

@end
