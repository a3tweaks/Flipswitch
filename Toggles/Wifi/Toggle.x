#import <A3Toggle.h>
#import <A3ToggleManager.h>

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>

@interface SBWiFiManager
+ (id)sharedInstance;
- (BOOL)wiFiEnabled;
- (void)setWiFiEnabled:(BOOL)enabled;
@end

@interface WifiToggle : NSObject <A3Toggle>
@end

static BOOL enabled;

@implementation WifiToggle

- (A3ToggleState)stateForToggleIdentifier:(NSString *)toggleIdentifier
{
	return [[%c(SBWiFiManager) sharedInstance] wiFiEnabled];
}

- (void)applyState:(A3ToggleState)newState forToggleIdentifier:(NSString *)toggleIdentifier
{
	if (newState == A3ToggleStateIndeterminate)
		return;
	enabled = newState;
	[[%c(SBWiFiManager) sharedInstance] setWiFiEnabled:enabled];
}

- (void)applyAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	[self attemptToOpenURL:@"prefs:root=WIFI"];
}

@end
