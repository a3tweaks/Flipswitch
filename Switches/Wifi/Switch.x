#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>

@interface SBWiFiManager
+ (id)sharedInstance;
- (BOOL)wiFiEnabled;
- (void)setWiFiEnabled:(BOOL)enabled;
@end

@interface WifiSwitch : NSObject <FSSwitchDataSource>
+ (void)_powerStateDidChange;
@end

%hook SBWiFiManager

- (void)_powerStateDidChange
{
	%orig();
	if ([NSThread isMainThread])
		[WifiSwitch _powerStateDidChange];
	else
		[WifiSwitch performSelectorOnMainThread:@selector(_powerStateDidChange) withObject:nil waitUntilDone:NO];
}

%end

@implementation WifiSwitch

+ (void)_powerStateDidChange
{
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:self].bundleIdentifier];
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [[%c(SBWiFiManager) sharedInstance] wiFiEnabled];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	[[%c(SBWiFiManager) sharedInstance] setWiFiEnabled:newState];
}

@end
