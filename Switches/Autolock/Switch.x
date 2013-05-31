#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#import <Foundation/Foundation.h>

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.flipswitch.autolock.plist"

@interface MCProfileConnection
+ (id)sharedConnection;
- (void)setValue:(id)arg1 forSetting:(id)arg2;
- (id)effectiveParametersForValueSetting:(id)arg1;
@end

@interface AutolockSwitch : NSObject <FSSwitchDataSource>
@end

%hook MCProfileConnection
- (void)_effectiveSettingsDidChange:(id)arg1
{
	%orig();
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[AutolockSwitch class]].bundleIdentifier];
}
%end

@implementation AutolockSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	int currentAutoLockValue = [[[(MCProfileConnection *)[objc_getClass("MCProfileConnection") sharedConnection] effectiveParametersForValueSetting:@"maxInactivity"] objectForKey:@"value"] intValue];
    BOOL enabled = (currentAutoLockValue == 2147483647 ? NO : YES);
    return enabled;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	
	NSMutableDictionary *prefsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:PLIST_PATH];
	NSNumber *toggledValue = nil;
    if (newState == FSSwitchStateOff)
    {
        int currentAutoLockValue = [[[(MCProfileConnection *)[objc_getClass("MCProfileConnection") sharedConnection] effectiveParametersForValueSetting:@"maxInactivity"] objectForKey:@"value"] intValue];
            
        [prefsDict setObject:[NSNumber numberWithInt:currentAutoLockValue] forKey:@"autoLockValue"];
        [prefsDict writeToFile:PLIST_PATH atomically:YES];

        toggledValue = [NSNumber numberWithInt:2147483647];
    }
    else if (newState == FSSwitchStateOn)
    {
        id savedAutoLockValue = [prefsDict objectForKey:@"autoLockValue"];
        toggledValue = [NSNumber numberWithInt:(savedAutoLockValue!=nil) ? [savedAutoLockValue intValue] : 60];
    }
    [(MCProfileConnection *)[objc_getClass("MCProfileConnection") sharedConnection] setValue:toggledValue forSetting:@"maxInactivity"];
}

@end
