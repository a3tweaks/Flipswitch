#import <FSSwitch.h>
#import <FSSwitchPanel.h>

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>

@interface SBWiFiManager
+ (id)sharedInstance;
- (BOOL)wiFiEnabled;
- (void)setWiFiEnabled:(BOOL)enabled;
@end

@interface WifiSwitch : NSObject <FSSwitch>
@end

static BOOL enabled;

@implementation WifiSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [[%c(SBWiFiManager) sharedInstance] wiFiEnabled];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	enabled = newState;
	[[%c(SBWiFiManager) sharedInstance] setWiFiEnabled:enabled];
}

@end
