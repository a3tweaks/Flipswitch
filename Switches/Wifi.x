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
	if ([NSThread isMainThread]) {
		[WifiSwitch performSelector:@selector(update) withObject:nil afterDelay:0];
	} else {
		[WifiSwitch performSelectorOnMainThread:@selector(update) withObject:nil waitUntilDone:NO];
	}
}

%end

@implementation WifiSwitch

static void updateState(void)
{
	wiFiEnabled = [[%c(SBWiFiManager) sharedInstance] wiFiEnabled];
}

+ (void)update
{
	updateState();
	// Workaround Protean thread-safety/reentry issues by scheduling the state change to run in the next run loop cycle
	[[FSSwitchPanel sharedPanel] performSelector:@selector(stateDidChangeForSwitchIdentifier:) withObject:@"com.a3tweaks.switch.wifi" afterDelay:0];
}

- (id)init
{
	if ((self = [super init])) {
		updateState();
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
