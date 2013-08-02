#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#ifndef GSCAPABILITY_H
extern BOOL GSSystemHasCapability(CFStringRef capability);
extern CFPropertyListRef GSSystemCopyCapability(CFStringRef capability);
#endif

#ifndef CTREGISTRATION_H_
extern CFStringRef const kCTRegistrationDataStatusChangedNotification;
extern CFStringRef const kCTRegistrationDataRateUnknown;
extern CFStringRef const kCTRegistrationDataRate2G;
extern CFStringRef const kCTRegistrationDataRate3G;
extern CFStringRef const kCTRegistrationDataRate4G;
CFArrayRef CTRegistrationCopySupportedDataRates();
CFStringRef CTRegistrationGetCurrentMaxAllowedDataRate();
void CTRegistrationSetMaxAllowedDataRate(CFStringRef dataRate);
#endif

#ifndef CTTELEPHONYCENTER_H_
CFNotificationCenterRef CTTelephonyCenterGetDefault();
void CTTelephonyCenterAddObserver(CFNotificationCenterRef center, const void *observer, CFNotificationCallback callBack, CFStringRef name, const void *object, CFNotificationSuspensionBehavior suspensionBehavior);
void CTTelephonyCenterRemoveObserver(CFNotificationCenterRef center, const void *observer, CFStringRef name, const void *object);
#endif

@interface DataLTESwitch : NSObject <FSSwitchDataSource>
@end

static void FSDataLTESwitchStatusDidChange(void);

@implementation DataLTESwitch

- (id)init
{
    if ((self = [super init])) {
        CFPropertyListRef telephonyGeneration = GSSystemCopyCapability(CFSTR("telephony-maximum-generation"));
        if (!telephonyGeneration) {
            [self release];
            return nil;
        }
        float value = [(id)telephonyGeneration floatValue];
        CFRelease(telephonyGeneration);
        if (value < 3.5f) {
            [self release];
            return nil;
        }
#if 0
        CFArrayRef supportedDataRates = CTRegistrationCopySupportedDataRates();
        BOOL supportsLTE = [(NSArray *)supportedDataRates containsObject:(id)kCTRegistrationDataRate4G];
        CFRelease(supportedDataRates);
        if (!supportsLTE) {
            [self release];
            return nil;
        }
#endif

        CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), NULL, (CFNotificationCallback)FSDataLTESwitchStatusDidChange, kCTRegistrationDataStatusChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    }

    return self;
}

- (void)dealloc
{
    CTTelephonyCenterRemoveObserver(CTTelephonyCenterGetDefault(), (CFNotificationCallback)FSDataLTESwitchStatusDidChange, NULL, NULL);

    [super dealloc];
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
    return CFEqual(CTRegistrationGetCurrentMaxAllowedDataRate(), kCTRegistrationDataRate4G);
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate) {
		return;
	} else if (newState == FSSwitchStateOn) {
        CTRegistrationSetMaxAllowedDataRate(kCTRegistrationDataRate4G);
    } else {
        // CTRegistrationCopySupportedDataRates() returns an ascending array (in regards to data speeds) of data rates.
        CFArrayRef supportedDataRates = CTRegistrationCopySupportedDataRates();

        NSUInteger lteOffDataRateIndex = [(NSArray *)supportedDataRates indexOfObject:(id)kCTRegistrationDataRate4G];
        switch (lteOffDataRateIndex) {
            case NSNotFound:
            case 0:
                lteOffDataRateIndex = 0;
                break;
            default:
                lteOffDataRateIndex--;
                break;
        }

        CTRegistrationSetMaxAllowedDataRate((CFStringRef)[(NSArray *)supportedDataRates objectAtIndex:lteOffDataRateIndex]);
    }
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSURL *url = [NSURL URLWithString:(kCFCoreFoundationVersionNumber > 700 ? @"prefs:root=General&path=MOBILE_DATA_SETTINGS_ID" : @"prefs:root=General&path=Network")];
	[[FSSwitchPanel sharedPanel] openURLAsAlternateAction:url];
}

@end

static void FSDataLTESwitchStatusDidChange(void)
{
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[DataLTESwitch class]].bundleIdentifier];
}