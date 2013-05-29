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

@interface LTESwitch : NSObject <FSSwitchDataSource>
@end

%hook SBTelephonyManager

- (void)_postDataConnectionTypeChanged
{
    %orig();
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[LTESwitch class]].bundleIdentifier];
}

%end

@implementation LTESwitch

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
        CFArrayRef supportedDataRates = CTRegistrationCopySupportedDataRates();
        BOOL supportsLTE = [(NSArray *)supportedDataRates containsObject:(id)kCTRegistrationDataRate4G];
        CFRelease(supportedDataRates);
        if (!supportsLTE) {
            [self release];
            return nil;
        }
    }
    return self;
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
    return CFEqual(CTRegistrationGetCurrentMaxAllowedDataRate(), kCTRegistrationDataRate4G);
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	else if (newState == FSSwitchStateOn)
	{
        CTRegistrationSetMaxAllowedDataRate(kCTRegistrationDataRate4G);
        return;
    }
    else
    {
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
