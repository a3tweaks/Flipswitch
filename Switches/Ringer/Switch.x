#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

@interface SBMediaController
+ (id)sharedInstance;
- (BOOL)isRingerMuted;
- (void)setRingerMuted:(BOOL)muted;
@end

@interface RingerSwitch : NSObject <FSSwitchDataSource>
NSString *_title;
@end

@implementation RingerSwitch

static void RingerSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[RingerSwitch class]].bundleIdentifier];
}

+ (void)load
{
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, NULL, RingerSettingsChanged, CFSTR("com.apple.springboard.ringerstate"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}

- (id)init
{
    if ((self = [super init])) {
        _title = [[[NSBundle bundleWithPath:@"/Applications/Preferences.app"] localizedStringForKey:@"Sounds" value:@"Sounds" table:@"Sounds"] retain];
    }
    return self;
}

- (void)dealloc
{
    [_title release];
    
    [super dealloc];
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

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
    return _title;
}

@end
