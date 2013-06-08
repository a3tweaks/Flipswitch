#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#ifndef GSCAPABILITY_H
extern BOOL GSSystemHasCapability(CFStringRef capability);
extern CFPropertyListRef GSSystemCopyCapability(CFStringRef capability);
#endif

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
NSString *_title;
@end

@implementation DataSwitch

- (id)init
{
    if ((self = [super init])) {
        CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), NULL, (CFNotificationCallback)FSDataSwitchStatusDidChange, kCTRegistrationDataStatusChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
        
        _title = [[[NSBundle bundleWithPath:@"/Applications/Preferences.app"] localizedStringForKey:@"MOBILE_DATA_SETTINGS" value:@"Cellular Data" table:@"Network"] retain];
    }
    return self;
}

- (void)dealloc
{    
    CTTelephonyCenterRemoveObserver(CTTelephonyCenterGetDefault(), (CFNotificationCallback)FSDataSwitchStatusDidChange, NULL, NULL);
    
    [_title release];
    
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

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
    return _title;
}

@end

static void FSDataSwitchStatusDidChange(void)
{
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[DataSwitch class]].bundleIdentifier];
}
