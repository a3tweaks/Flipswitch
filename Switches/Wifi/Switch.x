#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <SpringBoard/SpringBoard.h>
#include <dispatch/dispatch.h>

@interface WifiSwitch : NSObject <FSSwitchDataSource>
@end

static BOOL wiFiEnabled;

%hook SBWiFiManager

- (void)_powerStateDidChange
{
	%orig();
	wiFiEnabled = [self wiFiEnabled];
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[WifiSwitch class]].bundleIdentifier];
}

%end

@implementation WifiSwitch

- (id)init
{
	if ((self = [super init])) {
		wiFiEnabled = [[%c(SBWiFiManager) sharedInstance] wiFiEnabled];
	}
	return self;
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return wiFiEnabled;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	wiFiEnabled = newState;
	[[%c(SBWiFiManager) sharedInstance] setWiFiEnabled:newState];
}

@end
