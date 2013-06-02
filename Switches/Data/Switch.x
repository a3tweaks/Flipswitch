#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#import "CoreTelephony/CoreTelephony.h"

extern BOOL GSSystemHasCapability(CFStringRef capability);
extern CFPropertyListRef GSSystemCopyCapability(CFStringRef capability);

@interface DataSwitch : NSObject <FSSwitchDataSource>
@end

%hook SBTelephonyManager

- (void)_postDataConnectionTypeChanged
{
    %orig();
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[DataSwitch class]].bundleIdentifier];
}

%end

@implementation DataSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
    return CTCellularDataPlanGetIsEnabled();
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
    CTCellularDataPlanSetIsEnabled(newState);
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSURL *url = [NSURL URLWithString:(kCFCoreFoundationVersionNumber > 700 ? @"prefs:root=General&path=MOBILE_DATA_SETTINGS_ID" : @"prefs:root=General&path=Network")];
	[[FSSwitchPanel sharedPanel] openURLAsAlternateAction:url];
}

@end
