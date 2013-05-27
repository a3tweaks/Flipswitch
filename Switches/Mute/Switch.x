#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

@interface SBMediaController
+ (id)sharedInstance;
- (BOOL)isRingerMuted;
- (void)setRingerMuted:(BOOL)muted;
@end

@interface MuteSwitch : NSObject <FSSwitchDataSource>
@end

@implementation MuteSwitch

static void MuteSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[MuteSwitch class]].bundleIdentifier];
}

+ (void)load
{
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, NULL, MuteSettingsChanged, CFSTR("com.apple.springboard.ringerstate"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}

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
