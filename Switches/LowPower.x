#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <CoreDuet/CoreDuet.h>
#import <objc/runtime.h>

@interface LowPowerSwitch : NSObject <FSSwitchDataSource>
@end

@implementation LowPowerSwitch

static void BatterySaverSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSLog(@"Flipswitch: Low Power switch state changed value = %d", [[objc_getClass("_CDBatterySaver") batterySaver] getPowerMode]);
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.low-power"];
}

__attribute__((constructor))
static void constructor(void)
{
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, NULL, BatterySaverSettingsChanged, CFSTR("com.apple.system.batterysavermode"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	if ([[objc_getClass("_CDBatterySaver") batterySaver] getPowerMode] != 0) {
		return FSSwitchStateOn;
	} else {
		return FSSwitchStateOff;
	}
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	_CDBatterySaver *batterySaver = [objc_getClass("_CDBatterySaver") batterySaver];
	int newMode;
	switch (newState) {
		case FSSwitchStateIndeterminate:
		default:
			return;
		case FSSwitchStateOn:
			newMode = 1;
			[batterySaver setMode:1];
			break;
		case FSSwitchStateOff:
			newMode = 0;
			[batterySaver setMode:0];
			break;
	}
	NSError *error = nil;
	if ([batterySaver setPowerMode:newMode error:&error]) {
	    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.low-power"];
	} else {
		NSLog(@"Flipswitch: Failed to set power mode: %@", error);
	}
}

@end
