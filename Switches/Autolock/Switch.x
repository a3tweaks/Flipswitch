#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#import <Foundation/Foundation.h>
#import <limits.h>

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.flipswitch.autolock.plist"

@interface MCProfileConnection : NSObject
+ (MCProfileConnection *)sharedConnection;
- (void)setValue:(id)value forSetting:(id)setting;
- (id)effectiveParametersForValueSetting:(id)setting;
@end

@interface AutolockSwitch : NSObject <FSSwitchDataSource>
+ (void)_effectiveSettingsDidChange:(NSNotification *)notification;
@end

%hook MCProfileConnection

- (void)_effectiveSettingsDidChange:(id)notification
{
    [AutolockSwitch performSelectorOnMainThread:@selector(_effectiveSettingsDidChange:) withObject:notification waitUntilDone:NO];
	%orig();
}

%end

@implementation AutolockSwitch

+ (void)_effectiveSettingsDidChange:(NSNotification *)notification
{
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:self].bundleIdentifier];
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	int currentAutoLockValue = [[[[MCProfileConnection sharedConnection] effectiveParametersForValueSetting:@"maxInactivity"] objectForKey:@"value"] intValue];
    return (currentAutoLockValue == INT_MAX) ? FSSwitchStateOff : FSSwitchStateOn;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	
	NSMutableDictionary *prefsDict = [NSMutableDictionary dictionaryWithContentsOfFile:PLIST_PATH] ?: [NSMutableDictionary dictionary];
	NSNumber *toggledValue;
    if (newState) {
        toggledValue = [prefsDict objectForKey:@"autoLockValue"] ?: [NSNumber numberWithInt:60];
    } else {
        int currentAutoLockValue = [[[[MCProfileConnection sharedConnection] effectiveParametersForValueSetting:@"maxInactivity"] objectForKey:@"value"] intValue];
        if (currentAutoLockValue != INT_MAX) {
            [prefsDict setObject:[NSNumber numberWithInt:currentAutoLockValue] forKey:@"autoLockValue"];
            [prefsDict writeToFile:PLIST_PATH atomically:YES];
        }
        toggledValue = [NSNumber numberWithInt:INT_MAX];
    }
    [[MCProfileConnection sharedConnection] setValue:toggledValue forSetting:@"maxInactivity"];
}

@end
