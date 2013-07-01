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
	[WifiSwitch performSelectorOnMainThread:@selector(_powerStateDidChange) withObject:nil waitUntilDone:NO];
}

%end

static BOOL wiFiEnabled;

@implementation WifiSwitch

+ (void)_powerStateDidChange
{
	wiFiEnabled = [[%c(SBWiFiManager) sharedInstance] wiFiEnabled];
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:self].bundleIdentifier];
}

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
