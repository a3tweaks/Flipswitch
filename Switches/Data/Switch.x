#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#ifndef CTREGISTRATION_H_
extern CFStringRef const kCTRegistrationDataStatusChangedNotification;
#endif

#ifndef CTTELEPHONYCENTER_H_
CFNotificationCenterRef CTTelephonyCenterGetDefault();
void CTTelephonyCenterAddObserver(CFNotificationCenterRef center, const void *observer, CFNotificationCallback callBack, CFStringRef name, const void *object, CFNotificationSuspensionBehavior suspensionBehavior);
void CTTelephonyCenterRemoveObserver(CFNotificationCenterRef center, const void *observer, CFStringRef name, const void *object);
#endif

#ifndef CTCELLULARDATAPLAN_H_
Boolean CTCellularDataPlanGetIsEnabled();
void CTCellularDataPlanSetIsEnabled(Boolean enabled);
#endif

static void FSDataSwitchStatusDidChange(void);

@interface DataSwitch : NSObject <FSSwitchDataSource>
@end

@implementation DataSwitch

- (id)init
{
    self = [super init];

    if ((self = [super init])) {
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
