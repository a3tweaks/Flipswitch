#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"

#ifndef GSEVENT_H
extern void GSSendAppPreferencesChanged(CFStringRef bundleID, CFStringRef key);
#endif

#define kABSBackboard CFSTR("com.apple.backboardd")
#define kABSAutoBrightnessKey CFSTR("BKEnableALS")

@interface AutoBrightnessSwitch : NSObject <FSSwitchDataSource>
@end

@implementation AutoBrightnessSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
    CFPreferencesAppSynchronize(kABSBackboard);
    Boolean enabled = CFPreferencesGetAppBooleanValue(CFSTR("com.apple.backboardd"), kABSAutoBrightnessKey, NULL);
    return enabled ? FSSwitchStateOn : FSSwitchStateOff;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
    if (newState == FSSwitchStateIndeterminate)
        return;

    CFPreferencesSetAppValue(kABSAutoBrightnessKey, newState ? kCFBooleanTrue : kCFBooleanFalse, kABSBackboard);
    CFPreferencesAppSynchronize(kABSBackboard);
    GSSendAppPreferencesChanged(kABSBackboard, kABSAutoBrightnessKey);
}

@end