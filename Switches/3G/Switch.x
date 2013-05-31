#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

extern BOOL GSSystemHasCapability(CFStringRef capability);
extern CFPropertyListRef GSSystemCopyCapability(CFStringRef capability);

extern CFArrayRef CTRegistrationCopySupportedDataRates(void);
extern CFStringRef CTRegistrationGetCurrentMaxAllowedDataRate(void);
extern void CTRegistrationSetMaxAllowedDataRate(CFStringRef dataRate);

extern CFStringRef const kCTRegistrationDataRateUnknown;
extern CFStringRef const kCTRegistrationDataRate2G;
extern CFStringRef const kCTRegistrationDataRate3G;
extern CFStringRef const kCTRegistrationDataRate4G;

@interface Data3GSwitch : NSObject <FSSwitchDataSource>
@end

%hook SBTelephonyManager

- (void)_postDataConnectionTypeChanged
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[Data3GSwitch class]].bundleIdentifier];
}

%end

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
	}
	return self;
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
	NSURL *url = [NSURL URLWithString:(kCFCoreFoundationVersionNumber > 700 ? @"prefs:root=General&path=MOBILE_DATA_SETTINGS_ID" : @"prefs:root=General&path=Network")];
	[[FSSwitchPanel sharedPanel] openURLAsAlternateAction:url];
}

@end
