#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

extern BOOL GSSystemHasCapability(NSString *capability);

extern NSArray  *CTRegistrationCopySupportedDataRates();
extern NSString *CTRegistrationGetCurrentMaxAllowedDataRate();
extern void CTRegistrationSetMaxAllowedDataRate(NSString *dataRate);

extern NSString *const kCTRegistrationDataRateUnknown;
extern NSString *const kCTRegistrationDataRate2G;
extern NSString *const kCTRegistrationDataRate3G;
extern NSString *const kCTRegistrationDataRate4G;

@interface LTESwitch : NSObject <FSSwitchDataSource>
@end

@implementation LTESwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
    return [CTRegistrationGetCurrentMaxAllowedDataRate() isEqualToString:kCTRegistrationDataRate4G];
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
    	NSArray *supportedDataRates = CTRegistrationCopySupportedDataRates();
    
    	int lteOffDataRateIndex = [supportedDataRates indexOfObject:kCTRegistrationDataRate4G] - 1;
    	lteOffDataRateIndex = lteOffDataRateIndex<0?0:lteOffDataRateIndex;
    
    	CTRegistrationSetMaxAllowedDataRate([supportedDataRates objectAtIndex:lteOffDataRateIndex]);
    }
}

- (BOOL)shouldShowSwitchIdentifier:(NSString *)switchIdentifier
{
	BOOL supportsLTE = [CTRegistrationCopySupportedDataRates() containsObject:kCTRegistrationDataRate4G];
    BOOL somethingToToggle = [CTRegistrationCopySupportedDataRates() count]>1;
    
    return (GSSystemHasCapability(@"cellular-data") && supportsLTE && somethingToToggle);
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSURL *url = [NSURL URLWithString:(kCFCoreFoundationVersionNumber > 700 ? @"prefs:root=General&path=MOBILE_DATA_SETTINGS_ID" : @"prefs:root=General&path=Network")];
	[[FSSwitchPanel sharedPanel] openURLAsAlternateAction:url];
}

@end
