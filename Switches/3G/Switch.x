#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#import "CoreTelephony/CoreTelephony.h"

extern BOOL GSSystemHasCapability(CFStringRef capability);
extern CFPropertyListRef GSSystemCopyCapability(CFStringRef capability);

@interface Data3GSwitch : NSObject <FSSwitchDataSource>
@end

static void FSData3GSwitchStatusDidChange(void);

@implementation Data3GSwitch

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
		if (value < 3.0f) {
			[self release];
			return nil;
		}
		CFArrayRef supportedDataRates = CTRegistrationCopySupportedDataRates();
		BOOL supports3G = [(NSArray *)supportedDataRates containsObject:(id)kCTRegistrationDataRate3G];
		BOOL supports4G = [(NSArray *)supportedDataRates containsObject:(id)kCTRegistrationDataRate4G];
		CFRelease(supportedDataRates);
		if (!supports3G || supports4G) {
			[self release];
			return nil;
		}

		CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), NULL, (CFNotificationCallback)FSData3GSwitchStatusDidChange, kCTRegistrationDataStatusChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
	}

	return self;
}

- (void)dealloc
{
	CTTelephonyCenterRemoveObserver(CTTelephonyCenterGetDefault(), (CFNotificationCallback)FSData3GSwitchStatusDidChange, NULL, NULL);

	[super dealloc];
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSArray *supportedDataRates = [(NSArray *)CTRegistrationCopySupportedDataRates() autorelease];
	NSUInteger desiredRateIndex = [supportedDataRates indexOfObject:(id)kCTRegistrationDataRate3G];
	if (desiredRateIndex == NSNotFound)
		return FSSwitchStateOff;
	NSUInteger currentRateIndex = [supportedDataRates indexOfObject:(id)CTRegistrationGetCurrentMaxAllowedDataRate()];
	if (currentRateIndex == NSNotFound)
		return FSSwitchStateOff;
	return currentRateIndex >= desiredRateIndex;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	NSArray *supportedDataRates = [(NSArray *)CTRegistrationCopySupportedDataRates() autorelease];
	NSUInteger desiredRateIndex = [supportedDataRates indexOfObject:(id)kCTRegistrationDataRate3G];
	if (desiredRateIndex == NSNotFound)
		return;
	NSUInteger currentRateIndex = [supportedDataRates indexOfObject:(id)CTRegistrationGetCurrentMaxAllowedDataRate()];
	if (currentRateIndex == NSNotFound)
		return;
	if (newState) {
		if (currentRateIndex < desiredRateIndex)
			CTRegistrationSetMaxAllowedDataRate(kCTRegistrationDataRate3G);
	} else {
		if ((currentRateIndex >= desiredRateIndex) && desiredRateIndex)
			CTRegistrationSetMaxAllowedDataRate((CFStringRef)[supportedDataRates objectAtIndex:desiredRateIndex - 1]);
	}
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSURL *url = [NSURL URLWithString:(kCFCoreFoundationVersionNumber > 700.0f ? @"prefs:root=General&path=MOBILE_DATA_SETTINGS_ID" : @"prefs:root=General&path=Network")];
	[[FSSwitchPanel sharedPanel] openURLAsAlternateAction:url];
}

@end

static void FSData3GSwitchStatusDidChange(void)
{
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[Data3GSwitch class]].bundleIdentifier];
}
