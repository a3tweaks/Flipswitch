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
	if (kCFCoreFoundationVersionNumber < 600) {
		return;
	}
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, NULL, RingerSettingsChanged, CFSTR("com.apple.springboard.ringerstate"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}

@implementation RingerSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	Class SBMediaControllerClass = %c(SBMediaController);
	if ([SBMediaControllerClass instancesRespondToSelector:@selector(isRingerMuted)]) {
		return ![[SBMediaControllerClass sharedInstance] isRingerMuted];
	} else {
		return ![[[%c(SBMainWorkspace) sharedInstance] ringerControl] isRingerMuted];
	}
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	Class SBMediaControllerClass = %c(SBMediaController);
	if ([SBMediaControllerClass instancesRespondToSelector:@selector(setRingerMuted:)]) {
		[[SBMediaControllerClass sharedInstance] setRingerMuted:!newState];
	} else {
		[[[%c(SBMainWorkspace) sharedInstance] ringerControl] setRingerMuted:!newState];
	}
}

@end
