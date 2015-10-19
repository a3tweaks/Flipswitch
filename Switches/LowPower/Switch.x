#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <CoreDuet/CoreDuet.h>

@interface LowPowerSwitch : NSObject <FSSwitchDataSource>
@end

@implementation LowPowerSwitch

static void BatterySaverSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSLog(@"Flipswitch: Low Power switch state changed value = %d", [[_CDBatterySaver batterySaver] getPowerMode]);
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[LowPowerSwitch class]].bundleIdentifier];
}

+ (void)load
{
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, NULL, BatterySaverSettingsChanged, CFSTR("com.apple.system.batterysavermode"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	if ([[_CDBatterySaver batterySaver] getPowerMode] != 0) {
		return FSSwitchStateOn;
	} else {
		return FSSwitchStateOff;
	}
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	int newMode;
	switch (newState) {
		case FSSwitchStateIndeterminate:
		default:
			return;
		case FSSwitchStateOn:
			newMode = 1;
			[[_CDBatterySaver batterySaver] setMode:1];
			break;
		case FSSwitchStateOff:
			newMode = 0;
			[[_CDBatterySaver batterySaver] setMode:0];
			break;
	}
	NSError *error = nil;
	if ([[_CDBatterySaver batterySaver] setPowerMode:newMode error:&error]) {
	    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[LowPowerSwitch class]].bundleIdentifier];
	} else {
		NSLog(@"Flipswitch: Failed to set power mode: %@", error);
	}
}

@end
