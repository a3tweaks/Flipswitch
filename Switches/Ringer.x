#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <SpringBoard/SpringBoard.h>

@interface RingerSwitch : NSObject <FSSwitchDataSource>
@end

static void RingerSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:@"com.a3tweaks.switch.ringer"];
}

%ctor
{
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, NULL, RingerSettingsChanged, CFSTR("com.apple.springboard.ringerstate"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}

@implementation RingerSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return ![[%c(SBMediaController) sharedInstance] isRingerMuted];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	[[%c(SBMediaController) sharedInstance] setRingerMuted:!newState];
}

@end
