#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"

#ifndef GSEVENT_H
extern void GSSendAppPreferencesChanged(CFStringRef bundleID, CFStringRef key);
#endif

#define kABSBackboardPlist @"/var/mobile/Library/Preferences/com.apple.backboardd.plist"
#define kABSAutoBrightnessKey @"BKEnableALS"

@interface AutoBrightnessSwitch : NSObject <FSSwitchDataSource>
@end

@implementation AutoBrightnessSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:kABSBackboardPlist];
    BOOL enabled = ([dict objectForKey:kABSAutoBrightnessKey] && [[dict valueForKey:kABSAutoBrightnessKey] boolValue]);

    return enabled;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
    if (newState == FSSwitchStateIndeterminate)
        return;

    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:kABSBackboardPlist] ?: [[NSMutableDictionary alloc] init];
    NSNumber *value = [NSNumber numberWithBool:newState];
    [dict setValue:value forKey:kABSAutoBrightnessKey];
    [dict writeToFile:kABSBackboardPlist atomically:YES];
    [dict release];

    GSSendAppPreferencesChanged(CFSTR("com.apple.backboardd"), (CFStringRef)kABSAutoBrightnessKey);

}

@end