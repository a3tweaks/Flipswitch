#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#import "CoreTelephony/CoreTelephony.h"

#ifndef GSCAPABILITY_H
extern BOOL GSSystemHasCapability(CFStringRef capability);
extern CFPropertyListRef GSSystemCopyCapability(CFStringRef capability);
#endif

static void FSDataSwitchStatusDidChange(void);

@interface DataSwitch : NSObject <FSSwitchDataSource>
@end

@implementation DataSwitch

- (id)init
{
    self = [super init];

    if (self) {
        CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), NULL, (CFNotificationCallback)FSDataSwitchStatusDidChange, kCTRegistrationDataStatusChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    }

    return self;
}

- (void)dealloc
{
    CTTelephonyCenterRemoveObserver(CTTelephonyCenterGetDefault(), (CFNotificationCallback)FSDataSwitchStatusDidChange, NULL, NULL);

    [super dealloc];
}

#pragma mark - FSSwitchDataSource

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

static void FSDataSwitchStatusDidChange(void)
{
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[DataSwitch class]].bundleIdentifier];
}